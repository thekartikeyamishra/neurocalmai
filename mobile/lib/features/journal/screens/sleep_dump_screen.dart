import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../therapy/services/gemini_service.dart';
import '../../settings/providers/language_provider.dart';
import '../models/structured_journal_entry.dart';
import '../services/journal_storage_service.dart';
import '../../retention/services/reengagement_service.dart';
import '../services/local_journal_service.dart';
import '../../monetization/services/admob_service.dart';
import '../widgets/cognitive_mirror_card.dart';

class SleepDumpScreen extends ConsumerStatefulWidget {
  const SleepDumpScreen({super.key});

  @override
  ConsumerState<SleepDumpScreen> createState() => _SleepDumpScreenState();
}

class _SleepDumpScreenState extends ConsumerState<SleepDumpScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _dumpController = TextEditingController();

  int _currentStep = 0;
  bool _isProcessing = false;
  Map<String, dynamic>? _aiResult;

  // Indigo theme optimized for nighttime/calmness
  final Color _nightColor = const Color(0xFF4F46E5);

  @override
  void dispose() {
    _pageController.dispose();
    _dumpController.dispose();
    super.dispose();
  }

  void _processSleepDump() async {
    if (_dumpController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please offload your thoughts first."),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    try {
      // 💡 ARCHITECT PROMPT: Instructs the AI NOT to ask questions (which cause wakefulness), 
      // but to act as a "secure vault" for the user's worries.
      final prompt = """
      The user is trying to sleep but is experiencing racing thoughts and insomnia. 
      Here is their brain dump: ${_dumpController.text}
      
      DO NOT ask them any questions. Identify their core worry or emotion.
      Provide a highly soothing, validating response telling them that you have stored these worries safely in this vault, and they no longer need to carry them tonight. Give them permission to rest.
      Output ONLY valid JSON.
      """;

      final activeLanguage = ref.read(languageProvider);
      ReengagementService.instance.markStarted('sleep_dump');
      final result = await GeminiService.instance.generateTextReply(
        prompt, 
        [], 
        activeLanguage
      );

      if (!mounted) return;

      setState(() {
        _aiResult = result;
        _isProcessing = false;
        _currentStep++;
      });

      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _lockVaultAndSleep() async {
    HapticFeedback.mediumImpact();
    
    final entry = StructuredJournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'current_user',
      intentId: 'sleep_dump',
      intensity: 0, // Not tracked for sleep
      rawInputs: {'brain_dump': _dumpController.text.trim()},
      aiDistortionTag: 'racing_thoughts',
      aiSocraticQuestion: _aiResult?['reply'],
      userReframe: "Locked in the vault for tomorrow.",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ReengagementService.instance.markFinished('sleep_dump');
    final saved = await JournalStorageService.instance.saveEntry(entry);
    if (mounted) ref.invalidate(journalTimelineProvider);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this entry on your device. Please try again.')),
      );
      return;
    }

    if (mounted) {
      Navigator.pop(context);
      // Natural break: the session is complete and saved.
      AdMobService.instance.showInterstitialAdIfAppropriate(placement: 'journal_saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isResultScreen = _currentStep == 1;

    return Scaffold(
      // Darker surface for nighttime viewing
      backgroundColor: isResultScreen ? const Color(0xFF0F172A) : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: isResultScreen 
            ? const SizedBox.shrink() 
            : const BackButton(),
        title: Text(
          isResultScreen ? "Thoughts Secured" : "The Night Vault", 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 18,
            color: isResultScreen ? Colors.white : theme.colorScheme.onSurface,
          )
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildInputStep(theme),
                  _buildResultStep(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _nightColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_sync_rounded, color: _nightColor, size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            "Empty your mind.",
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "Write down everything keeping you awake. To-do lists, anxieties, replays of the day. We will hold them for you.",
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _dumpController,
            maxLines: 12,
            minLines: 6,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: "My brain won't shut off about...",
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processSleepDump,
              style: ElevatedButton.styleFrom(
                backgroundColor: _nightColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessing
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text("Offload Thoughts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStep(ThemeData theme) {
    if (_aiResult == null) return const SizedBox.shrink();

    final String soothingMessage = _aiResult!['reply'] ?? "I have stored these thoughts for you. You can rest now.";
    final String emotion = _aiResult!['slm_features']?['detected_emotion'] ?? "Mental Overload";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Icon(Icons.lock_rounded, color: _nightColor.withValues(alpha: 0.8), size: 64),
          ),
          const SizedBox(height: 40),
          CognitiveMirrorCard(
            rawDistortion: emotion,
            socraticQuestion: soothingMessage, // Re-using the field for the soothing statement
            customThemeColor: _nightColor,
          ),
          const SizedBox(height: 64),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _lockVaultAndSleep,
              icon: const Icon(Icons.nights_stay_rounded),
              label: const Text("Close App & Sleep", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _nightColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}