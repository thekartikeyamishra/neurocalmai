import 'dart:convert'; // 🚨 NEW IMPORT: Required for jsonEncode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Services
import '../../tracking/services/review_service.dart';
import '../services/openai_service.dart'; 
import '../../journal/services/local_journal_service.dart';

// Providers & Screens
import '../../settings/providers/language_provider.dart';
import '../../monetization/screens/insight_reward_screen.dart';

// ============================================================================
// STATE MANAGEMENT: Chat History & Analytics
// ============================================================================
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isTyping;
  final Map<String, dynamic>? lastSlmFeatures;

  ChatState({
    required this.messages,
    this.isTyping = false,
    this.lastSlmFeatures,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    Map<String, dynamic>? lastSlmFeatures,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      lastSlmFeatures: lastSlmFeatures ?? this.lastSlmFeatures,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    return ChatState(
      messages: [
        ChatMessage(
          // cSpell:disable-next-line
          text: "Hi there. I'm NeuroCalm. How are you feeling right now?",
          isUser: false,
        )
      ],
    );
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 1. Update UI immediately
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: text, isUser: true)],
      isTyping: true,
      lastSlmFeatures: null, // Clear old analytics
    );

    // 2. Format history for the OpenAI Service (mapping to 'assistant')
    final history = state.messages.skip(1).map((m) => {
      'role': m.isUser ? 'user' : 'assistant', 
      'content': m.text
    }).toList();

    try {
      // 3. Read current global dialect safely
      final activeLanguage = ref.read(languageProvider);

      // 4. Serverless API Call: Direct to OpenAI gpt-4o-mini
      final aiData = await OpenAIService.instance.generateTherapyResponse(
        text, 
        history, 
        activeLanguage.displayName, 
      );

      final responseText = aiData['reply'] ?? "I understand. Tell me more.";
      final slmData = aiData['slm_features'];

      // 5. Update UI with AI response and hidden SLM data
      state = state.copyWith(
        messages: [...state.messages, ChatMessage(text: responseText, isUser: false)],
        isTyping: false,
        lastSlmFeatures: slmData,
      );

    } catch (e) {
      debugPrint('🚨 [Text Therapy System Error]: $e');
      // Graceful offline fallback
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            text: "It seems we're disconnected. Take a deep, slow breath. I am still here locally.",
            isUser: false,
          )
        ],
        isTyping: false,
      );
    }
  }

  String extractSessionSummary() {
    if (state.messages.length <= 1) return "";
    return "Text Session Summary: ${state.messages.last.text}";
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() => ChatNotifier());

// ============================================================================
// UI SCREEN: Text CBT Engine
// ============================================================================
class TextTherapyScreen extends ConsumerStatefulWidget {
  const TextTherapyScreen({super.key});

  @override
  ConsumerState<TextTherapyScreen> createState() => _TextTherapyScreenState();
}

class _TextTherapyScreenState extends ConsumerState<TextTherapyScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _handleSend() {
    final text = _textController.text;
    if (text.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      ref.read(chatProvider.notifier).sendMessage(text);
      _textController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _finishAndShowInsights() {
    HapticFeedback.selectionClick();
    final features = ref.read(chatProvider).lastSlmFeatures;

    if (features != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => InsightRewardScreen(slmFeatures: features)),
      );
    }
  }

  /// 🚨 UPDATED: Silently saves session data to SQLite offline journal before exiting
  Future<void> _handleExitSession() async {
    final summary = ref.read(chatProvider.notifier).extractSessionSummary();
    final features = ref.read(chatProvider).lastSlmFeatures;

    if (summary.isNotEmpty) {
      // 1. Trigger ASO rating loop for highly successful sessions
      // 🚨 FIX: Removed positional arguments to align with updated AsoReviewService signature
      await AsoReviewService.instance.evaluateSessionForReview();

      // 2. Extract and sanitize insight data for the local journal
      final String emotion = features?['detected_emotion']?.toString() ?? 'Neutral';
      final String cleanInsight = summary.replaceAll('Text Session Summary: ', '').trim();
      
      // 🚨 ARCHITECT FIX: Safely encode the Map into a JSON string for SQLite storage
      final String? slmJson = features != null ? jsonEncode(features) : null;

      // 3. 100% Offline Secure Save
      if (cleanInsight.isNotEmpty) {
        await LocalJournalService.instance.saveEntry(JournalEntry(
          date: DateTime.now().toIso8601String(),
          sessionType: 'Text',
          emotion: emotion,
          aiInsight: cleanInsight,
          slmFeaturesJson: slmJson, // Injected successfully into v2 Schema
        ));
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final theme = Theme.of(context);

    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _handleExitSession,
        ),
        title: Text(
          'Text Session',
          style: TextStyle(color: theme.colorScheme.primary, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (chatState.lastSlmFeatures != null && !chatState.isTyping)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 500),
                child: TextButton.icon(
                  onPressed: _finishAndShowInsights,
                  icon: const Icon(Icons.lock_outline_rounded, size: 16),
                  label: const Text('Analyze', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE6A822),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: chatState.messages.length + (chatState.isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == chatState.messages.length && chatState.isTyping) {
                    return _buildTypingIndicator(theme);
                  }

                  final message = chatState.messages[index];
                  return _buildChatBubble(message, theme);
                },
              ),
            ),
            _buildInputArea(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Text('Processing securely...', style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message, ThemeData theme) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: message.isUser ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 20),
          ),
          boxShadow: [
            if (!message.isUser)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: message.isUser ? Colors.white : const Color(0xFF222222),
            fontSize: 16,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Type your thoughts...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}