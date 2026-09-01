import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../therapy/services/gemini_service.dart';
import '../../settings/providers/language_provider.dart';
import '../models/structured_journal_entry.dart';
import '../widgets/cognitive_mirror_card.dart';

class StandardJournalScreen extends ConsumerStatefulWidget {
  const StandardJournalScreen({super.key});

  @override
  ConsumerState<StandardJournalScreen> createState() => _StandardJournalScreenState();
}

class _StandardJournalScreenState extends ConsumerState<StandardJournalScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _entryController = TextEditingController();

  int _currentStep = 0;
  bool _isProcessing = false;
  Map<String, dynamic>? _aiResult;

  // Emerald theme optimized for growth and positive reflection
  final Color _growthColor = const Color(0xFF059669);

  @override
  void dispose() {
    _pageController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _analyzeReflection() async {
    if (_entryController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please write a few words first."),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    try {
      final prompt = """
      The user is reflecting on their day or expressing gratitude:
      Entry: ${_entryController.text}
      
      Identify the core emotion. Provide a brief, supportive, and validating response that encourages this type of healthy reflection. Do not ask heavy clinical questions.
      Output ONLY valid JSON.
      """;

      final activeLanguage = ref.read(languageProvider);
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
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveEntry() async {
    HapticFeedback.mediumImpact();
    
    final entry = StructuredJournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'current_user',
      intentId: 'standard_journal',
      intensity: 0,
      rawInputs: {'reflection': _entryController.text.trim()},
      aiDistortionTag: _aiResult?['slm_features']?['detected_emotion'] ?? 'reflection',
      aiSocraticQuestion: _aiResult?['reply'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // TODO: await JournalStorageService.instance.saveEntry(entry);
    debugPrint('🌱 [Reflection Saved]: ${entry.toMap()}');
    
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isResultScreen = _currentStep == 1;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: isResultScreen ? const SizedBox.shrink() : const BackButton(),
        title: Text(
          isResultScreen ? "Insight" : "Daily Reflection", 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.colorScheme.onSurface)
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
              color: _growthColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_stories_rounded, color: _growthColor, size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            "Clear your mind.",
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "What went well today? What did you learn? Or simply write whatever comes to mind.",
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _entryController,
            maxLines: 12,
            minLines: 6,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: "Today was...",
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _analyzeReflection,
              style: ElevatedButton.styleFrom(
                backgroundColor: _growthColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessing
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text("Save & Reflect", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStep(ThemeData theme) {
    if (_aiResult == null) return const SizedBox.shrink();

    final String insight = _aiResult!['reply'] ?? "Thank you for taking the time to reflect today.";
    final String emotion = _aiResult!['slm_features']?['detected_emotion'] ?? "Reflection";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          CognitiveMirrorCard(
            rawDistortion: emotion,
            socraticQuestion: insight, 
            customThemeColor: _growthColor,
          ),
          const SizedBox(height: 64),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _saveEntry,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text("Done", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _growthColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}