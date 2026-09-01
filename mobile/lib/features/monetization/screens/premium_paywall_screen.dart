import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Internal Services
import '../services/admob_service.dart';
import '../../dashboard/screens/dashboard_screen.dart';

class PremiumPaywallScreen extends ConsumerStatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  ConsumerState<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends ConsumerState<PremiumPaywallScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _continueWithFreeTier() {
    HapticFeedback.lightImpact();
    
    // Serve interstitial ad on checkout escape path to secure revenue loop
    try {
      AdMobService.instance.showInterstitialAdIfAppropriate();
    } catch (e) {
      debugPrint('⚠️ [AdMob Engine]: Exit ad display bypassed - $e');
    }

    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => const DashboardScreen())
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Midnight Blue
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              height: 350,
              width: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
              ),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white38),
                      onPressed: _continueWithFreeTier,
                    ),
                  ),
                ),
                
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildAnimatedComponent(
                        index: 0,
                        child: Column(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 64, color: Color(0xFF38BDF8)),
                            const SizedBox(height: 24),
                            const Text(
                              "Results",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 34, 
                                fontWeight: FontWeight.w900, 
                                letterSpacing: -1.0,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Unlock deep capabilities to transform your mental patterns. Experience full outcome tracking risk-free.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      _buildAnimatedComponent(
                        index: 1,
                        child: Column(
                          children: [
                            _buildBenefitRow(Icons.psychology_rounded, 'Conflict Decoder', 'Save time and cognitive stress with guided argument resolution.'),
                            _buildBenefitRow(Icons.nights_stay_rounded, 'Dream CBT Analyzer', 'Interpret hidden subconscious stress indicators automatically.'),
                            _buildBenefitRow(Icons.flash_on_rounded, 'Unlimited Compute & AI', 'Full access to state-of-the-art parameters for fast processing.'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Adaptive, non-breaking aesthetic message replaces broken store container
                      _buildAnimatedComponent(
                        index: 2,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.bolt_rounded, color: Colors.amber, size: 32),
                              const SizedBox(height: 12),
                              const Text(
                                "Supported by Mindfulness Sponsors",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Enjoy full features absolutely free. Premium resources are seamlessly subsidized via non-intrusive mindfulness sponsorships.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      _buildAnimatedComponent(
                        index: 3,
                        child: SizedBox(
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _continueWithFreeTier,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A5C5A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Unlock All Features Instantly",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3),
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
        ],
      ),
    );
  }

  Widget _buildAnimatedComponent({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 150)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, widget) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: widget,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildBenefitRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
              shape: BoxShape.circle
            ),
            child: Icon(icon, color: const Color(0xFF38BDF8), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}