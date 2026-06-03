import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_screen.dart';

// ============================================================================
// DATA MODEL: Onboarding Page Content
// ============================================================================
class OnboardingContent {
  final String title;
  final String description;
  final IconData icon;
  final Color highlightColor;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.highlightColor,
  });
}

// ============================================================================
// UI SCREEN: Smooth, Haptic-Rich Onboarding
// ============================================================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _iconAnimationController;
  late Animation<double> _iconFloatAnimation;

  int _currentPage = 0;

  // Core Value Propositions matching NeuroCalm's Architecture
  final List<OnboardingContent> _pages = [
    OnboardingContent(
      title: "Your Private AI Guide",
      description: "A highly empathetic AI trained in Cognitive Behavioral Therapy. Talk, type, or scan your mood to find your center.",
      icon: Icons.auto_awesome_rounded,
      highlightColor: const Color(0xFF38BDF8), // Calming Blue
    ),
    OnboardingContent(
      title: "Sensory Grounding",
      description: "Interrupt anxious loops with tactile haptic feedback, guided breathing, and localized voice responses.",
      icon: Icons.waves_rounded,
      highlightColor: const Color(0xFFE6A822), // Warm Amber
    ),
    OnboardingContent(
      title: "100% Offline & Secure",
      description: "Your mental health is deeply personal. All journals, voice notes, and face scans are processed locally and never leave your device.",
      icon: Icons.shield_rounded,
      highlightColor: const Color(0xFF2A5C5A), // Primary Teal
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    // Continuous floating animation for the central icons
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _iconFloatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _iconAnimationController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  /// Handles tactile feedback and state updates when the user swipes
  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentPage = index;
    });
  }

  /// Completes onboarding, saves the state, and routes to Auth
  Future<void> _finishOnboarding() async {
    HapticFeedback.heavyImpact();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
    } catch (e) {
      debugPrint('[Onboarding Error]: Failed to save completion state - $e');
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR: Skip Button
            Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                opacity: isLastPage ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: TextButton(
                  onPressed: isLastPage ? null : _finishOnboarding,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // MAIN CONTENT: Swipeable Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Floating Icon
                        AnimatedBuilder(
                          animation: _iconFloatAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _iconFloatAnimation.value),
                              child: Container(
                                height: 160,
                                width: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: page.highlightColor.withValues(alpha: 0.1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: page.highlightColor.withValues(alpha: 0.2),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  page.icon,
                                  size: 80,
                                  color: page.highlightColor,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 64),
                        
                        // Text Content
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 28,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // BOTTOM NAVIGATION: Indicators & Action Button
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  // Dynamic Dot Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index 
                              ? theme.colorScheme.primary 
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Primary Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLastPage) {
                          _finishOnboarding();
                        } else {
                          HapticFeedback.lightImpact();
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          isLastPage ? 'Get Started' : 'Next',
                          key: ValueKey<bool>(isLastPage),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
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