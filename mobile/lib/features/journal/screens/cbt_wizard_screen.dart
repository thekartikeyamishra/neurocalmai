import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Internal Services & Models
import '../../therapy/services/gemini_service.dart';
import '../../settings/providers/language_provider.dart';
import '../models/structured_journal_entry.dart';
import '../services/journal_storage_service.dart';
import '../../retention/services/reengagement_service.dart';
import '../services/local_journal_service.dart';
import '../../monetization/services/admob_service.dart';
import '../widgets/cognitive_mirror_card.dart';

class CbtWizardScreen extends ConsumerStatefulWidget {
  const CbtWizardScreen({super.key});

  @override
  ConsumerState<CbtWizardScreen> createState() => _CbtWizardScreenState();
}

class _CbtWizardScreenState extends ConsumerState<CbtWizardScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  
  final TextEditingController _factsController = TextEditingController();
  final TextEditingController _thoughtController = TextEditingController();
  final TextEditingController _reframeController = TextEditingController();

  int _currentStep = 0;
  final int _totalSteps = 3;
  double _intensity = 50.0;

  bool _isProcessing = false;
  Map<String, dynamic>? _aiResult;

  @override
  void dispose() {
    _pageController.dispose();
    _factsController.dispose();
    _thoughtController.dispose();
    _reframeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Validation Guards
    if (_currentStep == 0 && _factsController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      _showErrorToast("Please describe what happened.");
      return;
    }
    if (_currentStep == 2 && _thoughtController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      _showErrorToast("Please share what your brain is predicting.");
      return;
    }

    HapticFeedback.lightImpact();
    
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _analyzeCognition();
    }
  }

  void _previousStep() {
    HapticFeedback.selectionClick();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _analyzeCognition() async {
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    try {
      // 1. Construct the payload mapping for the Gemini Engine
      final prompt = """
      Analyze this journal entry for cognitive distortions.
      Fact: ${_factsController.text}
      Anxiety Intensity: ${_intensity.toInt()}/100
      Automatic Thought: ${_thoughtController.text}
      
      Identify the distortion and ask a single Socratic question to help me reframe it. Output MUST be valid JSON.
      """;

      // 2. Execute via Gemini Service
      final activeLanguage = ref.read(languageProvider);
      ReengagementService.instance.markStarted('cbt_wizard');
      final result = await GeminiService.instance.generateTextReply(
        prompt, 
        [], // No chat history needed for workflow triage
        activeLanguage
      );

      if (!mounted) return;

      setState(() {
        _aiResult = result;
        _isProcessing = false;
        _currentStep++; // Move to the Result/Reframing page
      });

      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorToast("The neural engine is calibrating. Please try again.");
    }
  }

  Future<void> _saveAndFinish() async {
    HapticFeedback.mediumImpact();
    
    // Construct the standardized data model for persistent storage
    final entry = StructuredJournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID until Firestore assigns one
      userId: 'current_user', // Replace with FirebaseAuth.instance.currentUser?.uid
      intentId: 'cbt_wizard',
      intensity: _intensity.toInt(),
      rawInputs: {
        'facts': _factsController.text.trim(),
        'automatic_thought': _thoughtController.text.trim(),
      },
      aiDistortionTag: _aiResult?['slm_features']?['cognitive_distortion'],
      aiSocraticQuestion: _aiResult?['reply'],
      userReframe: _reframeController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ReengagementService.instance.markFinished('cbt_wizard');
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
    final isResultScreen = _currentStep == _totalSteps;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: isResultScreen 
            ? const SizedBox.shrink() 
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: _previousStep,
              ),
        title: isResultScreen 
            ? const Text("Cognitive Mirror", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
            : Row(
                children: List.generate(
                  _totalSteps,
                  (index) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Enforce guided workflow
                children: [
                  _buildStep1(theme),
                  _buildStep2(theme),
                  _buildStep3(theme),
                  _buildResultStep(theme),
                ],
              ),
            ),
            
            // Bottom Action Bar
            if (!isResultScreen)
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    )
                  ]
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 24, width: 24, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                          )
                        : Text(
                            _currentStep == 2 ? "Analyze Thought" : "Continue",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 1: The Facts (Decoupling Emotion from Reality)
  // =========================================================================
  Widget _buildStep1(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_rounded, color: theme.colorScheme.primary, size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            "Just the facts.",
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "What happened? Describe the triggering event like a reporter. No emotions or assumptions yet—just who, what, and where.",
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _factsController,
            maxLines: 6,
            minLines: 3,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: "e.g., My manager sent me a message at 4:50 PM saying we need to talk tomorrow.",
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 2: The Emotion (Somatic Scaling)
  // =========================================================================
  Widget _buildStep2(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded, color: Color(0xFFE11D48), size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            "How intense is the feeling?",
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "Anxiety thrives when we can't measure it. Use the slider to rate your current physiological distress.",
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 64),
          
          Center(
            child: Text(
              "${_intensity.toInt()}%",
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Color.lerp(theme.colorScheme.primary, const Color(0xFFE11D48), _intensity / 100),
                letterSpacing: -2,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Color.lerp(theme.colorScheme.primary, const Color(0xFFE11D48), _intensity / 100),
              inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
              thumbColor: Colors.white,
              trackHeight: 12,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16, elevation: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            ),
            child: Slider(
              value: _intensity,
              min: 0,
              max: 100,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _intensity = value);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Calm", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                Text("Panic", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 3: The Automatic Thought (Capturing the distortion)
  // =========================================================================
  Widget _buildStep3(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            "What is your brain predicting?",
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "What is the worst-case scenario your mind is generating based on those facts?",
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _thoughtController,
            maxLines: 6,
            minLines: 3,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: "e.g., I'm definitely going to be fired tomorrow. They realized I'm not good enough.",
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 4: The Result (Cognitive Mirror & Reframe)
  // =========================================================================
  Widget _buildResultStep(ThemeData theme) {
    if (_aiResult == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 💡 ARCHITECT INTEGRATION: Using the decoupled reusable UI component
          CognitiveMirrorCard(
            rawDistortion: _aiResult!['slm_features']?['cognitive_distortion'] ?? "Negative Filtering",
            socraticQuestion: _aiResult!['reply'] ?? "What is one piece of evidence that contradicts this?",
            customThemeColor: theme.colorScheme.primary,
            animationDelay: const Duration(milliseconds: 100),
          ),
          
          const SizedBox(height: 32),

          // The Reframing Input
          Text(
            "Your Reframe",
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reframeController,
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              hintText: "Answer the question above to build a more balanced perspective...",
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 32),

          // Final Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _saveAndFinish,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text("Save & Ground Myself", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}