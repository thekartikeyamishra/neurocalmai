import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Service Integrations
import '../services/admob_service.dart';
import '../services/subscription_service.dart';
import '../../habit_loop/services/habit_loop_service.dart';

// Routing
import 'premium_paywall_screen.dart';

class InsightRewardScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> slmFeatures;

  const InsightRewardScreen({super.key, required this.slmFeatures});

  @override
  ConsumerState<InsightRewardScreen> createState() => _InsightRewardScreenState();
}

class _InsightRewardScreenState extends ConsumerState<InsightRewardScreen> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _cardFlipController;
  late Animation<double> _flipAnimation;

  bool _isAdLoading = false;
  bool _rewardUnlocked = false;
  bool _isInvestmentCommitted = false;
  bool _showBackOfCard = false;
  bool _adHandled = false;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _cardFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardFlipController, curve: Curves.easeInOutCubic),
    )..addListener(() {
        if (_flipAnimation.value >= 0.5 && !_showBackOfCard) {
          setState(() => _showBackOfCard = true);
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final isPremium = ref.read(subscriptionProvider).isPremium;
      if (isPremium) {
        setState(() => _rewardUnlocked = true);
        HapticFeedback.mediumImpact();
      }
      _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _cardFlipController.dispose();
    super.dispose();
  }

  void _triggerHaptic(bool isHeavy) {
    isHeavy ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
  }

  // ============================================================================
  // AD-BLOCKER & NETWORK FAILSAFE LOGIC
  // ============================================================================
  void _handleUnlockRequest() {
    if (_isAdLoading) return;

    _triggerHaptic(true);
    setState(() {
      _isAdLoading = true;
      _adHandled = false;
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _isAdLoading && !_adHandled) {
        _adHandled = true;
        setState(() => _isAdLoading = false);
        _showAdBlockerFailsafe();
      }
    });

    AdMobService.instance.showRewardedAd(
      onEarnedReward: () {
        if (mounted && !_adHandled) {
          _adHandled = true;
          setState(() {
            _rewardUnlocked = true;
            _isAdLoading = false;
          });
          InsightHaptics.successOverridden();
        }
      },
      onAdClosed: () {
        if (mounted && !_rewardUnlocked && !_adHandled) {
          _adHandled = true;
          setState(() => _isAdLoading = false);
        }
      },
    );
  }

  void _showAdBlockerFailsafe() {
    if (!mounted) return;

    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              'Connection Blocked',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        content: Text(
          'We couldn\'t load the sponsor message. This usually happens if you are offline or using an Ad-Blocker.\n\nTo view your insights offline without interruptions, upgrade to NeuroCalm Premium.',
          style: TextStyle(height: 1.5, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8), fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('View Premium', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HOOKED MODEL: VARIABLE REWARD (Card Flip)
  // ============================================================================
  void _triggerFlippingMechanic() {
    HapticFeedback.mediumImpact();
    if (_cardFlipController.isCompleted) {
      _cardFlipController.reverse().then((_) {
        if (mounted) setState(() => _showBackOfCard = false);
      });
    } else {
      _cardFlipController.forward();
    }
  }

  // ============================================================================
  // HOOKED MODEL: SYNAPTIC INVESTMENT
  // ============================================================================
  Future<void> _submitInvestmentAction(bool isPositive) async {
    if (_isInvestmentCommitted) return;
    setState(() => _isInvestmentCommitted = true);

    await ref.read(habitLoopServiceProvider).commitCognitiveInvestment(
      cognitiveDistortion: widget.slmFeatures['cognitive_distortion']?.toString() ?? 'Catastrophizing',
      successfulReframingPattern: widget.slmFeatures['reframing_action']?.toString() ?? 'Cognitive Re-centering',
      userHelpfulnessRating: isPositive,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPositive ? 'Neural pathway reinforced.' : 'Bias registered for recalibration.',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: isPositive ? const Color(0xFF2A5C5A) : const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = ref.watch(subscriptionProvider).isPremium;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _rewardUnlocked ? 'Neural Reframe' : 'Deep Insights',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_rewardUnlocked)
            IconButton(
              icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF38BDF8)),
              onPressed: () {
                _triggerHaptic(false);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()));
              },
            )
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation), child: child),
            );
          },
          child: _rewardUnlocked
              ? _buildUnlockedInsights(theme)
              : _buildLockedView(theme, isPremium),
        ),
      ),
    );
  }

  // ============================================================================
  // UI: LOCKED STATE
  // ============================================================================
  Widget _buildLockedView(ThemeData theme, bool isPremium) {
    return Padding(
      key: const ValueKey('locked_view'),
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.6,
                child: _buildMockFrontCard(theme),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: Container(
                    height: 320,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(Icons.lock_person_rounded, size: 48, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Pattern Analysis Ready',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'Subconscious loops identified. Unlock the secure report to begin your reframe.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _isAdLoading ? null : _handleUnlockRequest,
              icon: _isAdLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_circle_fill_rounded),
              label: Text(
                _isAdLoading ? 'Securing Connection...' : 'Watch Ad to Unlock',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              _triggerHaptic(false);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()));
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF38BDF8)),
            label: Text(
              'Or Upgrade to Premium for Instant Access',
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMockFrontCard(ThemeData theme) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology_rounded, size: 56, color: Color(0xFF38BDF8)),
          const SizedBox(height: 24),
          Container(height: 12, width: 120, color: Colors.white24),
          const SizedBox(height: 16),
          Container(height: 24, width: 200, color: Colors.white),
          const Spacer(),
          Container(height: 12, width: 150, color: Colors.white24),
        ],
      ),
    );
  }

  // ============================================================================
  // UI: UNLOCKED STATE
  // ============================================================================
  Widget _buildUnlockedInsights(ThemeData theme) {
    return Padding(
      key: const ValueKey('unlocked_view'),
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your Cognitive Pattern Matrix',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: _triggerFlippingMechanic,
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, child) {
                final double transformValue = _flipAnimation.value * math.pi;
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(transformValue),
                  alignment: Alignment.center,
                  child: _showBackOfCard ? _buildBackCard(theme) : _buildFrontCard(theme),
                );
              },
            ),
          ),

          const SizedBox(height: 40),

          AnimatedOpacity(
            opacity: _showBackOfCard ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Column(
              children: [
                const Text(
                  'Did this reframe interrupt your cognitive loop?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildInvestmentButton(
                      icon: Icons.close_rounded,
                      label: 'Not Really',
                      color: Colors.redAccent,
                      onPressed: () => _submitInvestmentAction(false),
                    ),
                    const SizedBox(width: 16),
                    _buildInvestmentButton(
                      icon: Icons.check_rounded,
                      label: 'Aligned',
                      color: const Color(0xFF2A5C5A),
                      onPressed: () => _submitInvestmentAction(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrontCard(ThemeData theme) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.15), blurRadius: 25, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology_rounded, size: 56, color: Color(0xFF38BDF8)),
          const SizedBox(height: 24),
          const Text(
            'Detected Core Distortion',
            style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.slmFeatures['cognitive_distortion']?.toString() ?? 'Catastrophizing',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.2),
          ),
          const Spacer(),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_rounded, size: 14, color: Colors.white38),
              SizedBox(width: 8),
              Text('Tap Card to Reveal Reframe', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(ThemeData theme) {
    return Transform(
      transform: Matrix4.identity()..rotateY(math.pi),
      alignment: Alignment.center,
      child: Container(
        height: 320,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(Icons.auto_awesome_rounded, size: 32, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Neurological Realignment Pathway',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              widget.slmFeatures['reframing_action']?.toString() ?? 'Focus strictly on tactical structural patterns to lower cortisol.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 18, fontWeight: FontWeight.w800, height: 1.4, letterSpacing: -0.3),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildInvestmentButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: _isInvestmentCommitted ? null : onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

// ============================================================================
// HAPTICS UTILITY
// ============================================================================
class InsightHaptics {
  static Future<void> successOverridden() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.lightImpact();
  }
}
