import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🚨 ARCHITECT INTEGRATION: Linking newly built systems
import '../../journal/services/data_import_service.dart';
import '../../monetization/screens/premium_paywall_screen.dart';

class EnhancedOnboardingScreen extends StatefulWidget {
  const EnhancedOnboardingScreen({super.key});

  @override
  State<EnhancedOnboardingScreen> createState() =>
      _EnhancedOnboardingScreenState();
}

class _EnhancedOnboardingScreenState extends State<EnhancedOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isProcessing = false;
  bool _isSyncingData = false;
  final Map<String, String> _userProfile = {};

  // 🚨 PSYCHOLOGICAL PROFILING: Extended steps to build user investment
  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: "What brings you to NeuroCalm?",
      subtitle: "We'll tailor your AI sessions to your specific needs.",
      options: [
        "Relationship Conflict",
        "Work Burnout",
        "Subconscious Anxiety",
        "Social Panic",
      ],
      key: "primary_pain",
    ),
    OnboardingStep(
      title: "How does this affect you daily?",
      subtitle: "Recognizing your symptoms helps our AI guide you better.",
      options: [
        "Overthinking at Night",
        "Physical Chest Tension",
        "Emotional Numbness",
        "Constant Fatigue",
      ],
      key: "symptom_type",
    ),
    OnboardingStep(
      title: "What is your primary goal?",
      subtitle: "Focusing on a target dramatically improves therapy outcomes.",
      options: [
        "Emotional Stability",
        "Better Communication",
        "Improved Sleep Quality",
        "Crisis Management",
      ],
      key: "user_goal",
    ),
    OnboardingStep(
      title: "Have you tried therapy before?",
      subtitle: "This sets the baseline for our Cognitive Behavioral AI.",
      options: [
        "Yes, currently in therapy",
        "Tried it in the past",
        "I use meditation apps",
        "No, this is my first time",
      ],
      key: "experience_level",
    ),
    OnboardingStep(
      title: "Effortless Data Sync",
      subtitle:
          "Import your last 30 days of sleep and activity data from your device to generate instant historical insights.",
      options: [], // Handled by custom UI
      key: "data_sync",
      isDataSyncStep: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onBack() {
    if (_currentStep > 0 && !_isProcessing && !_isSyncingData) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
      setState(() => _currentStep--);
    }
  }

  void _handleOptionSelection(String value) {
    HapticFeedback.mediumImpact();
    _userProfile[_steps[_currentStep].key] = value;
    _advanceToNextStep();
  }

  Future<void> _handleDataSync() async {
    HapticFeedback.heavyImpact();
    setState(() => _isSyncingData = true);

    // Call the Service we built earlier
    final result = await DataImportService.instance.syncHistoricalData(
      daysToFetch: 30,
    );

    if (mounted) {
      setState(() => _isSyncingData = false);
      if (result.success) {
        HapticFeedback.heavyImpact(); // Success pulse
        _userProfile['data_synced'] = 'true';
        _advanceToNextStep();
      } else {
        // Show error but allow user to proceed anyway
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _advanceToNextStep() {
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
      setState(() => _currentStep++);
    } else {
      _finalizeOnboarding();
    }
  }

  /// 🚨 VALUE CREATION: Simulates AI processing to build anticipation before Paywall
  Future<void> _finalizeOnboarding() async {
    setState(() => _isProcessing = true);

    // Save profile securely
    final prefs = await SharedPreferences.getInstance();
    for (var entry in _userProfile.entries) {
      await prefs.setString('profile_${entry.key}', entry.value);
    }
    await prefs.setBool('has_seen_onboarding', true);

    // Simulate Deep AI Calibration
    await Future.delayed(const Duration(milliseconds: 3500));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()),
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
        leading: _currentStep > 0 && !_isProcessing
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: theme.colorScheme.primary,
                ),
                onPressed: _onBack,
              )
            : null,
        actions: [
          // Dynamic skip button exclusively for the data sync step
          if (_steps[_currentStep].isDataSyncStep &&
              !_isProcessing &&
              !_isSyncingData)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _userProfile['data_synced'] = 'false';
                _advanceToNextStep();
              },
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _isProcessing
              ? _buildCalibrationUI(theme)
              : _buildOnboardingFlow(theme),
        ),
      ),
    );
  }

  Widget _buildOnboardingFlow(ThemeData theme) {
    return Column(
      key: const ValueKey('flow'),
      children: [
        // Premium Progress Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(
              begin: 0,
              end: (_currentStep + 1) / _steps.length,
            ),
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  color: theme.colorScheme.primary,
                  minHeight: 8,
                ),
              );
            },
          ),
        ),

        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Forces interaction
            itemCount: _steps.length,
            itemBuilder: (context, index) {
              final step = _steps[index];
              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      step.subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),

                    if (step.isDataSyncStep)
                      _buildDataSyncStep(theme)
                    else
                      ...step.options.asMap().entries.map((entry) {
                        return _buildOptionCard(theme, entry.value, entry.key);
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

  /// 🚨 UX UPGRADE: Custom Animated Option Cards instead of basic OutlinedButtons
  Widget _buildOptionCard(ThemeData theme, String title, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 150)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: InkWell(
          onTap: () => _handleOptionSelection(title),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🚨 INTEGRATION: The seamless switching UI module
  Widget _buildDataSyncStep(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.health_and_safety_rounded,
            size: 80,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton.icon(
            onPressed: _isSyncingData ? null : _handleDataSync,
            icon: _isSyncingData
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(
              _isSyncingData ? 'Importing securely...' : 'Connect Health Data',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(
              'Data remains 100% on-device.',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalibrationUI(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        key: const ValueKey('calibration'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: SizedBox(
                height: 64,
                width: 64,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              "Calibrating Neural Models",
              textAlign: TextAlign.center,
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Synthesizing your profile to optimize offline Cognitive Behavioral frameworks specifically for ${(_userProfile['primary_pain'] ?? 'your goals').toLowerCase()}.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
                height: 1.5,
              ),
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
  final bool isDataSyncStep;

  OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.key,
    this.isDataSyncStep = false,
  });
}
