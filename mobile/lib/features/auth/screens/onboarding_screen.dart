import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';

// ============================================================================
// DATA MODELS: Gamified Onboarding
// ============================================================================
class OnboardingStep {
  final String title;
  final String description;
  final String outcomeFocus;
  final List<String> options;
  final IconData heroIcon;
  final Color themeColor;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.outcomeFocus,
    required this.options,
    required this.heroIcon,
    required this.themeColor,
  });
}

// ============================================================================
// UI SCREEN: Progressive, Haptic-Rich Gamified Onboarding
// ============================================================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _iconAnimationController;
  late AnimationController _celebrationController;
  late Animation<double> _iconFloatAnimation;
  late Animation<double> _scaleAnimation;

  int _currentPage = 0;
  final Map<int, Set<String>> _selectedOptions = {};
  bool _isAnalyzing = false;

  // Selling the outcome and gathering progressive data
  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: "What brings you here?",
      description: "Select the areas you want to transform.",
      outcomeFocus: "We've helped users reclaim 100,000+ hours of peace.",
      options: [
        "Reduce Daily Anxiety",
        "Improve Deep Sleep",
        "Stop Procrastinating",
        "Navigate Conflicts",
      ],
      heroIcon: Icons.psychology_rounded,
      themeColor: const Color(0xFF6366F1), // Indigo
    ),
    OnboardingStep(
      title: "When do you need support?",
      description: "We'll optimize your tools for these critical moments.",
      outcomeFocus: "Proactive care prevents cognitive overload.",
      options: [
        "First thing in the morning",
        "During the workday",
        "Before falling asleep",
        "In random social situations",
      ],
      heroIcon: Icons.schedule_rounded,
      themeColor: const Color(0xFFEC4899), // Pink
    ),
    OnboardingStep(
      title: "Calibrating Your Engine",
      description: "Building your offline-ready, personalized neural pathway.",
      outcomeFocus: "Your mental sanctuary is almost ready.",
      options: [],
      heroIcon: Icons.auto_awesome_rounded,
      themeColor: const Color(0xFF10B981), // Emerald
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Floating Hero Animation
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _iconFloatAnimation = Tween<double>(begin: 0.0, end: 12.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Celebration/Achievement Animation
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconAnimationController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true); // Matches main.dart check

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _handleOptionToggle(int pageIndex, String option) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedOptions.putIfAbsent(pageIndex, () => {});
      if (_selectedOptions[pageIndex]!.contains(option)) {
        _selectedOptions[pageIndex]!.remove(option);
      } else {
        _selectedOptions[pageIndex]!.add(option);
      }
    });
  }

  Future<void> _handleNext() async {
    final isLastInteractionPage = _currentPage == _steps.length - 2;
    
    if (isLastInteractionPage) {
      // Transition to the "Calibrating" achievement screen
      HapticFeedback.mediumImpact();
      setState(() => _isAnalyzing = true);
      
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );

      // Simulate AI engine calibration for gamified investment
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() => _isAnalyzing = false);
        _celebrationController.forward();
        HapticFeedback.heavyImpact(); // Celebration haptic
      }
    } else {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showMigrationBottomSheet() {
    HapticFeedback.selectionClick();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.swap_horizontal_circle_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Zero-Loss Secure Migration",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Import your existing journals, metrics, and behavioral history instantly. We parse text files securely on-device without telemetry exposure.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    _finishOnboarding();
                  },
                  icon: const Icon(Icons.file_open_rounded),
                  label: const Text(
                    "Select Export File (.json, .txt)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFinalPage = _currentPage == _steps.length - 1;
    final currentOptions = _selectedOptions[_currentPage] ?? {};
    final canProceed = isFinalPage || currentOptions.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Utility Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedOpacity(
                    opacity: isFinalPage ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: isFinalPage ? null : _finishOnboarding,
                      child: Text(
                        "Skip",
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Onboarding Progression Engine
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Force guided gamified progression
                itemCount: _steps.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  
                  // UX FIX: Implementing LayoutBuilder and SingleChildScrollView prevents bottom 
                  // overflow clipping on small screens (like SM A54) when forms get too tall.
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Floating Hero Icon or Processing Spinner
                                Center(
                                  child: AnimatedBuilder(
                                    animation: _iconFloatAnimation,
                                    builder: (context, child) {
                                      return Transform.translate(
                                        offset: Offset(0, -_iconFloatAnimation.value),
                                        child: child,
                                      );
                                    },
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 400),
                                      child: _isAnalyzing && isFinalPage
                                          ? Container(
                                              height: 120, // Optimized sizing
                                              width: 120,
                                              decoration: BoxDecoration(
                                                color: step.themeColor.withValues(alpha: 0.05),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(32.0),
                                                child: CircularProgressIndicator(
                                                  color: step.themeColor,
                                                  strokeWidth: 3,
                                                ),
                                              ),
                                            )
                                          : ScaleTransition(
                                              scale: isFinalPage ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
                                              child: Container(
                                                height: 120, // Optimized sizing
                                                width: 120,
                                                decoration: BoxDecoration(
                                                  color: step.themeColor.withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  step.heroIcon,
                                                  size: 56,
                                                  color: step.themeColor,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                
                                // Copy emphasizing outcome
                                Text(
                                  _isAnalyzing && isFinalPage ? "Analyzing Profile..." : step.title,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.onSurface,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _isAnalyzing && isFinalPage ? "Compiling local data..." : step.description,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Gamified Selection List
                                if (step.options.isNotEmpty)
                                  ...step.options.map((option) {
                                    final isSelected = currentOptions.contains(option);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeOutCubic,
                                        decoration: BoxDecoration(
                                          color: isSelected 
                                              ? step.themeColor.withValues(alpha: 0.1) 
                                              : theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isSelected 
                                                ? step.themeColor 
                                                : theme.colorScheme.outline.withValues(alpha: 0.3),
                                            width: isSelected ? 2 : 1,
                                          ),
                                          boxShadow: isSelected ? [
                                            BoxShadow(
                                              color: step.themeColor.withValues(alpha: 0.05),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            )
                                          ] : [],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () => _handleOptionToggle(index, option),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      option,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                        color: isSelected ? step.themeColor : theme.colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    Icon(Icons.check_circle_rounded, color: step.themeColor, size: 22),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  
                                if (isFinalPage && !_isAnalyzing)
                                  AnimatedOpacity(
                                    opacity: _scaleAnimation.isCompleted ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 400),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.verified_user_rounded, color: theme.colorScheme.primary, size: 24),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              "Matrix configured successfully. Ready for private initialization.",
                                              style: TextStyle(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Progress Indicators & Action Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(28.0, 16.0, 28.0, 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Social Proof / Outcome Reiteration
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _steps[_currentPage].outcomeFocus,
                      key: ValueKey<int>(_currentPage),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Gamified Progress Ring
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        height: 6,
                        width: _currentPage == index ? 32 : 12,
                        decoration: BoxDecoration(
                          color: _currentPage >= index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Main Primary Action
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: canProceed && !_isAnalyzing 
                          ? (isFinalPage ? _finishOnboarding : _handleNext)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.3),
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          isFinalPage ? 'Create Anonymous Account' : 'Continue',
                          key: ValueKey<bool>(isFinalPage),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 1-Click Migration Hook
                  AnimatedSize(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    child: isFinalPage && !_isAnalyzing
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: TextButton.icon(
                              onPressed: _showMigrationBottomSheet,
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text(
                                "Moving from another app? Migrate data",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}