import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';
import '../../monetization/screens/premium_paywall_screen.dart'; // 🚨 NEW: Hard Paywall transition

class GuidedOnboardingScreen extends StatefulWidget {
  const GuidedOnboardingScreen({super.key});

  @override
  State<GuidedOnboardingScreen> createState() => _GuidedOnboardingScreenState();
}

class _GuidedOnboardingScreenState extends State<GuidedOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isCalibrating = false;
  final Map<String, String> _userProfile = {};

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: "What brings you to NeuroCalm?",
      subtitle: "We'll tailor your AI sessions to your specific needs.",
      options: ["Relationship Conflict", "Work Burnout", "Subconscious Anxiety", "Social Panic"],
      key: "primary_pain",
    ),
    OnboardingStep(
      title: "How does it manifest?",
      subtitle: "Recognizing your symptoms helps our AI guide you better.",
      options: ["Overthinking", "Physical Tension", "Sleep Disruption", "Emotional Numbness"],
      key: "symptom_type",
    ),
    OnboardingStep(
      title: "What is your main goal?",
      subtitle: "Focusing on a target improves therapy outcomes.",
      options: ["Emotional Stability", "Better Communication", "Improved Sleep", "Crisis Management"],
      key: "user_goal",
    ),
  ];

  void _onBack() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
      setState(() => _currentStep--);
    }
  }

  void _handleSelection(String value) async {
    HapticFeedback.mediumImpact();
    _userProfile[_steps[_currentStep].key] = value;
    
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600), 
        curve: Curves.easeOutCubic
      );
      setState(() => _currentStep++);
    } else {
      _startCalibration();
    }
  }

  /// 🚨 PSYCHOLOGICAL TRIGGER: Simulates AI processing to build value
  Future<void> _startCalibration() async {
    setState(() => _isCalibrating = true);
    
    // Save profile for personalized CBT prompts
    final prefs = await SharedPreferences.getInstance();
    for (var entry in _userProfile.entries) {
      await prefs.setString('profile_${entry.key}', entry.value);
    }
    await prefs.setBool('has_seen_onboarding', true);

    await Future.delayed(const Duration(seconds: 3)); // Artificial processing time
    
    if (mounted) {
      // 🚨 HARD PAYWALL: Routes directly to the paywall after value proof
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => const PremiumPaywallScreen())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0 && !_isCalibrating 
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: _onBack,
            )
          : null,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          child: _isCalibrating ? _buildCalibrationUI(theme) : _buildOnboardingFlow(theme),
        ),
      ),
    );
  }

  Widget _buildOnboardingFlow(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(10),
            minHeight: 6,
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _steps.length,
            itemBuilder: (context, index) {
              final step = _steps[index];
              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      step.title, 
                      textAlign: TextAlign.center, 
                      style: theme.textTheme.displayLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w900)
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.subtitle, 
                      textAlign: TextAlign.center, 
                      style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])
                    ),
                    const SizedBox(height: 48),
                    // Staggered Option List
                    ...step.options.asMap().entries.map((entry) {
                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 400 + (entry.key * 150)),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: OutlinedButton(
                            onPressed: () => _handleSelection(entry.value),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 72),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1.5),
                              backgroundColor: Colors.white,
                            ),
                            child: Text(
                              entry.value, 
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.primary)
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationUI(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 80, width: 80,
            child: CircularProgressIndicator(strokeWidth: 6, strokeCap: StrokeCap.round),
          ),
          const SizedBox(height: 40),
          Text(
            "Calibrating NeuroCalm SLM", 
            textAlign: TextAlign.center,
            style: theme.textTheme.displayLarge?.copyWith(fontSize: 24)
          ),
          const SizedBox(height: 16),
          Text(
            "Synthesizing your profile to optimize offline CBT models for ${(_userProfile['primary_pain'] ?? 'your needs').toLowerCase()}.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
      ),
    );
  }
}

class OnboardingStep {
  final String title, subtitle, key;
  final List<String> options;
  OnboardingStep({required this.title, required this.subtitle, required this.options, required this.key});
}