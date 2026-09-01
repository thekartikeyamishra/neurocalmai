import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../therapy/services/gemini_service.dart';
import '../../settings/providers/language_provider.dart';

class GuidedTaskScreen extends ConsumerStatefulWidget {
  const GuidedTaskScreen({super.key});

  @override
  ConsumerState<GuidedTaskScreen> createState() => _GuidedTaskScreenState();
}

class _GuidedTaskScreenState extends ConsumerState<GuidedTaskScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _microStepController = TextEditingController();

  int _currentStep = 0;
  final int _totalSteps = 3;
  
  String _selectedBlocker = "";
  final List<String> _blockerOptions = [
    "It feels too overwhelming (Too big)",
    "I don't know where to start (Unclear)",
    "It's chronically under-stimulating (Boring)",
    "I'm afraid of doing it wrong (Perfectionism)",
  ];

  bool _isProcessing = false;
  Map<String, dynamic>? _aiResult;

  // ADHD Theme Color (Amber/Action) from Intent Screen
  final Color _actionColor = const Color(0xFFD97706);

  @override
  void dispose() {
    _pageController.dispose();
    _taskController.dispose();
    _microStepController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Validation Guards
    if (_currentStep == 0 && _taskController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      _showErrorToast("Please name the task you are avoiding.");
      return;
    }
    if (_currentStep == 1 && _selectedBlocker.isEmpty) {
      HapticFeedback.heavyImpact();
      _showErrorToast("Please select what is blocking you.");
      return;
    }
    if (_currentStep == 2 && _microStepController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      _showErrorToast("Please define one tiny micro-step.");
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
      _analyzeTaskParalysis();
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

  Future<void> _analyzeTaskParalysis() async {
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    try {
      // 1. Construct the payload mapping Executive Dysfunction to Cognitive Distortions
      final prompt = """
      Analyze this user's task paralysis and executive dysfunction:
      Avoided Task: ${_taskController.text}
      Primary Blocker: $_selectedBlocker
      Proposed 2-Minute Micro-Step: ${_microStepController.text}
      
      Identify the core cognitive distortion (e.g., all-or-nothing thinking, magnification).
      In your reply, validate their specific blocker, and provide an encouraging, urgent psychological push to execute ONLY that 2-minute micro-step right now. Do not mention the larger task.
      """;

      // 2. Fetch language preference and execute via the newly updated robust Gemini service
      final activeLanguage = ref.read(languageProvider);
      
      final result = await GeminiService.instance.generateTextReply(
        prompt, 
        [], // No chat history needed for workflow triage
        activeLanguage
      );

      if (!mounted) return;

      setState(() {
        _aiResult = result;
        _isProcessing = false;
        _currentStep++; // Move to the "Action Plan" result page
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

  Future<void> _commitAndStart() async {
    HapticFeedback.heavyImpact();
    // TODO: Integrate with JournalStorageService to save the workflow.
    // In a future update, this button could launch a native 2-minute countdown timer overlay.
    Navigator.pop(context);
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
            ? const Text("Action Plan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
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
                            ? _actionColor
                            : _actionColor.withValues(alpha: 0.15),
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
                physics: const NeverScrollableScrollPhysics(), // Enforces the structured workflow moat
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
                      backgroundColor: _actionColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 24, width: 24, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                          )
                        : Text(
                            _currentStep == 2 ? "Generate Action Plan" : "Next",
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
  // STEP 1: Naming the Avoided Task
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
              color: _actionColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.psychology_rounded, color: _actionColor, size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            "Name the wall.",
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "The task I am avoiding right now is...",
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _taskController,
            maxLines: 4,
            minLines: 2,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: "e.g., Replying to that email from my accountant.",
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 2: Identifying the Executive Blocker
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
              color: _actionColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_rounded, color: _actionColor, size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            "Why does it feel hard?",
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "Executive dysfunction is a neurological blocker, not a moral failure. What is your brain telling you?",
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 32),
          
          ..._blockerOptions.map((blocker) {
            final isSelected = _selectedBlocker == blocker;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedBlocker = blocker);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isSelected ? _actionColor.withValues(alpha: 0.1) : theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? _actionColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    blocker,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? _actionColor : theme.colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 3: The Micro-Step (Activation Energy Reduction)
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
              color: _actionColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.flash_on_rounded, color: _actionColor, size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            "Lower the bar.",
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "If you only had to work on this for 2 minutes, the absolute smallest first step would be...",
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _microStepController,
            maxLines: 4,
            minLines: 2,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: "e.g., Just opening my laptop and finding the email thread.",
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 4: The Result (AI Reframing & Action Commitment)
  // =========================================================================
  Widget _buildResultStep(ThemeData theme) {
    if (_aiResult == null) return const SizedBox.shrink();

    final String distortion = _aiResult!['slm_features']['cognitive_distortion'] ?? "Magnification";
    final String aiPush = _aiResult!['reply'] ?? "You've correctly identified the smallest step. You can do anything for 2 minutes. Start now.";

    // Make the distortion tag human-readable
    final displayDistortion = distortion.replaceAll('_', ' ').split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The AI Analysis Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _actionColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _actionColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights_rounded, color: _actionColor),
                    const SizedBox(width: 8),
                    Text(
                      "Executive Barrier Detected",
                      style: TextStyle(fontWeight: FontWeight.bold, color: _actionColor),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _actionColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayDistortion,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  aiPush,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // The Action Commitment
          Center(
            child: Text(
              "Ready to break the loop?",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),

          // Final Execution Button
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _commitAndStart,
              icon: const Icon(Icons.timer_rounded, size: 24),
              label: const Text("Commit to 2 Minutes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _actionColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
                shadowColor: _actionColor.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Save and close for now",
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
          )
        ],
      ),
    );
  }
}