import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';

/// Production-ready single-column hero paywall.
/// Features a dismissible reverse-trial bypass for the user's initial CBT session,
/// dynamic package resolution from RevenueCat, and clear subscription disclosures.
class PaywallScreen extends StatefulWidget {
  final bool isDismissible;
  final VoidCallback? onDismiss;
  final VoidCallback? onPurchaseSuccess;

  const PaywallScreen({
    super.key,
    this.isDismissible = true,
    this.onDismiss,
    this.onPurchaseSuccess,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, Package?> _packages = {};
  String _selectedPackageKey = 'annual'; // Default to best-value tier

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final packages = await RevenueCatService.instance.getSubscriptionPackages();
    if (mounted) {
      setState(() {
        _packages = packages;
        _isLoading = false;
        // Fallback selection if annual isn't available
        if (_packages['annual'] == null && _packages['quarterly'] != null) {
          _selectedPackageKey = 'quarterly';
        }
      });
    }
  }

  Future<void> _handlePurchase() async {
    final selectedPackage = _packages[_selectedPackageKey];
    if (selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected plan is temporarily unavailable. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final success = await RevenueCatService.instance.purchasePackage(selectedPackage);
      if (!mounted) return;

      if (success) {
        if (widget.onPurchaseSuccess != null) {
          widget.onPurchaseSuccess!();
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isProcessing = true);
    try {
      final restored = await RevenueCatService.instance.restorePurchases();
      if (!mounted) return;

      if (restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored successfully.'),
            backgroundColor: Color(0xFF2E6F56),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active subscriptions found to restore.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _handleDismiss() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    } else {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF1E3A2F);
    const accentGreen = Color(0xFF2E6F56);
    const surfaceColor = Color(0xFFF9FAF9);

    return Scaffold(
      backgroundColor: surfaceColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(accentGreen),
                ),
              )
            : Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 36),

                        // Header Hero Section
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: accentGreen.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.spa_rounded,
                              size: 40,
                              color: accentGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Rewire Your Response to Stress',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unlimited voice-guided CBT reframing, adaptive somatic grounding, and an encrypted offline mental resilience vault.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Key Value Propositions
                        _buildFeatureRow(
                          icon: Icons.mic_rounded,
                          title: 'Voice Cognitive Reframing',
                          subtitle: 'Speak your anxious spirals; receive instant clinical reframes.',
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureRow(
                          icon: Icons.waves_rounded,
                          title: 'Dynamic Somatic Pacing',
                          subtitle: 'Adaptive bio-calibrated breathing & bilateral vagus grounding.',
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureRow(
                          icon: Icons.lock_outline_rounded,
                          title: 'Zero-Knowledge Privacy',
                          subtitle: 'All journal logs remain encrypted on your device. Never mined.',
                        ),
                        const SizedBox(height: 28),

                        // Single-Column Hero Pricing Options
                        _buildPricingCard(
                          planKey: 'annual',
                          package: _packages['annual'],
                          title: 'Annual Plan',
                          subtitle: 'Full 12-Month Resilience Protocol',
                          priceDetail: '\$49.99 / year (\$4.16/mo)',
                          badgeText: 'BEST VALUE • SAVE 45%',
                          isBestValue: true,
                        ),
                        const SizedBox(height: 12),
                        _buildPricingCard(
                          planKey: 'quarterly',
                          package: _packages['quarterly'],
                          title: 'Quarterly Plan',
                          subtitle: '12-Week CBT Reset Cycle',
                          priceDetail: '\$29.99 / 3 months (\$9.99/mo)',
                          badgeText: 'CLINICAL CYCLE',
                          isBestValue: false,
                        ),
                        const SizedBox(height: 24),

                        // Primary Action Button
                        ElevatedButton(
                          onPressed: _isProcessing ? null : _handlePurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Continue with Selected Plan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),

                        // Reverse-Trial Bypass (Dismissible First CBT Session)
                        if (widget.isDismissible)
                          TextButton(
                            onPressed: _isProcessing ? null : _handleDismiss,
                            style: TextButton.styleFrom(
                              foregroundColor: primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text(
                              'Try your first CBT session free →',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),

                        // Legal & Store Disclaimers
                        Text(
                          'Payment charged to your Google Play account upon confirmation. Subscription auto-renews unless canceled at least 24 hours prior to the cycle end. Cancel anytime in Google Play settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Restore Purchases Link
                        Center(
                          child: TextButton(
                            onPressed: _isProcessing ? null : _handleRestore,
                            child: Text(
                              'Restore Purchases',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Top Dismiss Action (Close Icon)
                  if (widget.isDismissible)
                    Positioned(
                      top: 8,
                      right: 12,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 26, color: primaryGreen),
                        tooltip: 'Bypass for now',
                        onPressed: _isProcessing ? null : _handleDismiss,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2E6F56).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF2E6F56)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A2F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingCard({
    required String planKey,
    required Package? package,
    required String title,
    required String subtitle,
    required String priceDetail,
    required String badgeText,
    required bool isBestValue,
  }) {
    final isSelected = _selectedPackageKey == planKey;
    final price = package?.storeProduct.priceString ?? priceDetail;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPackageKey = planKey;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E6F56).withAlpha(12) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF2E6F56) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2E6F56).withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFF2E6F56) : Colors.grey.shade400,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A2F),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isBestValue ? const Color(0xFF2E6F56) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: isBestValue ? Colors.white : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E3A2F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}