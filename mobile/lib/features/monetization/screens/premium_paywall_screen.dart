import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/subscription_service.dart';
import '../../dashboard/screens/dashboard_screen.dart'; // 🚨 ARCHITECT FIX: Explicit routing fallback

class PremiumPaywallScreen extends ConsumerStatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  ConsumerState<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends ConsumerState<PremiumPaywallScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // 1. Entrance Cascade Animation (Builds perceived value)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 2. Continuous Pulsing Animation for the "Best Value" CTA
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerHaptic(bool isHeavy) {
    isHeavy ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
  }

  Future<void> _handlePurchase(Package package) async {
    _triggerHaptic(true);
    final success = await ref.read(subscriptionProvider.notifier).purchasePackage(package);
    
    if (success && mounted) {
      _triggerHaptic(true);
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => const DashboardScreen())
      );
    }
  }

  void _continueWithFreeTier() {
    _triggerHaptic(false);
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => const DashboardScreen())
    );
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionProvider);
    final currentOffering = subState.offerings?.current;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Midnight Blue
      body: Stack(
        children: [
          // Ambient Glow Background (Calming visual anchor)
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
                // Top Navigation Bar
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
                      // Header Section
                      _buildAnimatedComponent(
                        index: 0,
                        child: Column(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 64, color: Color(0xFF38BDF8)),
                            const SizedBox(height: 24),
                            const Text(
                              "Start Your 7-Day Trial",
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
                              "Experience complete emotional clarity. Cancel anytime, risk-free.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // 🚨 VALUE PROPS: Differential factors behind paywall
                      _buildAnimatedComponent(
                        index: 1,
                        child: Column(
                          children: [
                            _buildBenefitRow(Icons.psychology_rounded, 'Conflict Decoder', 'AI-guided resolution for complex arguments.'),
                            _buildBenefitRow(Icons.nights_stay_rounded, 'Dream CBT Analyzer', 'Interpret subconscious physical stress patterns.'),
                            _buildBenefitRow(Icons.block_rounded, 'Ad-Free Deep Insights', 'Zero wait time. Instant neurological recalibration.'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Subscription Packages (RevenueCat Dynamic Pricing)
                      _buildAnimatedComponent(
                        index: 2,
                        child: subState.isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                              ),
                            )
                          : Column(
                              children: [
                                if (currentOffering != null && currentOffering.availablePackages.isNotEmpty)
                                  ...currentOffering.availablePackages.map((package) {
                                    final isAnnual = package.packageType == PackageType.annual;
                                    return _buildSubscriptionCard(package, isAnnual);
                                  }),
                              ],
                            ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Free Tier Fallback & Strict Legal Compliance
                      _buildAnimatedComponent(
                        index: 3,
                        child: Column(
                          children: [
                            TextButton(
                              onPressed: _continueWithFreeTier,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              ),
                              child: Text(
                                "Continue with Free Ad-Supported Version",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5), 
                                  fontSize: 14, 
                                  fontWeight: FontWeight.w600
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Auto-renewing subscription. Cancel anytime in your device Store Settings. If you do not cancel before the trial ends, you will be charged.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 11, height: 1.4),
                            ),
                          ],
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

  /// Staggered Entrance Animation Wrapper
  Widget _buildAnimatedComponent({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 200)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, widget) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
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

  Widget _buildSubscriptionCard(Package package, bool isBestValue) {
    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isBestValue ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: isBestValue ? null : Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: isBestValue ? [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.3), 
            blurRadius: 20, 
            offset: const Offset(0, 8)
          )
        ] : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBestValue ? "Yearly Access" : "Monthly Access",
                  style: TextStyle(
                    color: isBestValue ? const Color(0xFF0F172A) : Colors.white, 
                    fontWeight: FontWeight.w900, 
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBestValue ? "Includes 7-day free trial" : "Instant premium access",
                  style: TextStyle(
                    color: isBestValue ? const Color(0xFF0F172A).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.5), 
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // DYNAMIC: Formats ₹, $, or € based on RevenueCat metadata natively
          Text(
            package.storeProduct.priceString,
            style: TextStyle(
              color: isBestValue ? const Color(0xFF0F172A) : Colors.white, 
              fontSize: 22, 
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => _handlePurchase(package),
      // Apply the pulsing animation ONLY to the "Best Value" (Annual) package
      child: isBestValue 
        ? ScaleTransition(scale: _pulseAnimation, child: cardContent) 
        : cardContent,
    );
  }
}