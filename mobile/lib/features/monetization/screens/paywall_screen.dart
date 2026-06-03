import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _contentController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // 🚨 ARCHITECT FIX: Staggered entrance to build psychological value before price reveal
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );

    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handlePurchase(Package package) async {
    HapticFeedback.heavyImpact();
    final success = await ref.read(subscriptionProvider.notifier).purchasePackage(package);
    if (success && mounted) {
      Navigator.pop(context); // Entry into app unlocked
    }
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionProvider);
    final currentOffering = subState.offerings?.current;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium midnight background
      body: Stack(
        children: [
          // 🚨 VISUAL: Ambient background glow
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                ),
                
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 54, color: Color(0xFF38BDF8)),
                          const SizedBox(height: 24),
                          const Text(
                            'Premium Clarity',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32, 
                              fontWeight: FontWeight.w900, 
                              color: Colors.white, 
                              letterSpacing: -0.5
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Master your mind with our most advanced tools.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                          const SizedBox(height: 48),
                          
                          // 🚨 VALUE PROPS: Differential factors behind paywall
                          _buildFeature(Icons.psychology_rounded, 'Conflict Decoder', 'AI-guided resolution for arguments.'),
                          _buildFeature(Icons.nights_stay_rounded, 'Dream CBT Analyzer', 'Interpret subconscious stress patterns.'),
                          _buildFeature(Icons.ads_click_rounded, 'Ad-Free Deep Insights', 'Zero wait time for cognitive analysis.'),
                          
                          const SizedBox(height: 40),

                          if (subState.isLoading)
                            const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                          else if (currentOffering != null)
                            ...currentOffering.availablePackages.map((package) {
                              final isAnnual = package.packageType == PackageType.annual;
                              return _buildPriceTile(package, isAnnual);
                            }),
                          
                          const SizedBox(height: 24),
                          const Text(
                            'Safe & Secure: Cancel anytime in your device settings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white24, fontSize: 11),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
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
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPriceTile(Package package, bool isBestValue) {
    return GestureDetector(
      onTap: () => _handlePurchase(package),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isBestValue ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: isBestValue ? null : Border.all(color: Colors.white12),
          boxShadow: isBestValue ? [
            BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
          ] : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isBestValue ? 'Annual - 7 Days Free' : 'Monthly Access',
                        style: TextStyle(
                          color: isBestValue ? Colors.black : Colors.white, 
                          fontWeight: FontWeight.w900, 
                          fontSize: 16
                        ),
                      ),
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
                          child: const Text('SAVE 60%', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        )
                      ]
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isBestValue ? 'Total yearly value after trial.' : 'Full access, billed monthly.',
                    style: TextStyle(color: isBestValue ? Colors.black54 : Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            // 🚨 DYNAMIC: Native Store Price String (INR/USD/EUR)
            Text(
              package.storeProduct.priceString,
              style: TextStyle(
                color: isBestValue ? Colors.black : Colors.white, 
                fontSize: 20, 
                fontWeight: FontWeight.w900
              ),
            ),
          ],
        ),
      ),
    );
  }
}