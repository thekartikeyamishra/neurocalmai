import 'package:flutter/material.dart';
import '../../../core/utils/region_detector.dart';
import '../../../core/services/wallet_service.dart';
import '../../../core/services/admob_reward_service.dart';
import 'subscription_screen.dart'; // Assumes this will be created next
import '../../wallet/presentation/wallet_topup_dialog.dart'; // Assumes this will be created next

/// A contextual, sliding bottom sheet that intercepts users when they try to access
/// a premium feature. It dynamically renders the correct monetization UI (Micro-transactions 
/// for India vs. Subscriptions for International) and handles ad fallbacks.
class PaywallBottomSheet extends StatefulWidget {
  final String featureName;
  final String featureDescription;
  final int creditCost;
  final VoidCallback onSuccess; // Triggered when payment/ad is successful

  const PaywallBottomSheet({
    super.key,
    required this.featureName,
    required this.featureDescription,
    required this.creditCost,
    required this.onSuccess,
  });

  /// Helper method to easily show this bottom sheet from anywhere in the app
  static void show({
    required BuildContext context,
    required String featureName,
    required String featureDescription,
    required int creditCost,
    required VoidCallback onSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaywallBottomSheet(
        featureName: featureName,
        featureDescription: featureDescription,
        creditCost: creditCost,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<PaywallBottomSheet> createState() => _PaywallBottomSheetState();
}

class _PaywallBottomSheetState extends State<PaywallBottomSheet> {
  bool _isProcessing = false;
  final WalletService _walletService = WalletService();
  final AdMobRewardService _adMobService = AdMobRewardService();

  // Brand Colors
  final Color primarySage = const Color(0xFF2F5244);
  final Color creamBg = const Color(0xFFFBFAF6);

  /// Executes the credit deduction transaction
  Future<void> _processWalletPayment() async {
    setState(() => _isProcessing = true);
    
    final success = await _walletService.deductCredits(widget.creditCost);
    
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      Navigator.pop(context); // Close bottom sheet
      widget.onSuccess(); // Trigger the premium feature
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Transaction failed. Please try again."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Executes the AdMob Rewarded Video fallback
  void _showRewardedAd() {
    setState(() => _isProcessing = true);

    _adMobService.showAd(
      onRewardEarned: () {
        if (mounted) {
          setState(() => _isProcessing = false);
          Navigator.pop(context);
          widget.onSuccess(); // Grant access to the feature for free
        }
      },
      onAdFailed: () {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ad not available right now. Please try again later."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: creamBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Header
          Icon(Icons.lock_outline_rounded, size: 48, color: primarySage),
          const SizedBox(height: 16),
          Text(
            widget.featureName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primarySage,
              fontFamily: 'Fraunces', // Assuming brand font setup
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.featureDescription,
            style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Dynamic Routing based on Region
          RegionDetector.isUserInIndia
              ? _buildIndianSachetView()
              : _buildInternationalView(),
        ],
      ),
    );
  }

  /// Builds the Wallet & Ad fallback UI for the Indian market
  Widget _buildIndianSachetView() {
    return StreamBuilder<int>(
      stream: _walletService.balanceStream,
      initialData: _walletService.currentBalance,
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0;
        final hasEnoughCredits = balance >= widget.creditCost;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Available Balance:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  "$balance Credits",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primarySage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Primary Call to Action
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasEnoughCredits ? primarySage : Colors.amber.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _isProcessing
                    ? null
                    : (hasEnoughCredits
                        ? _processWalletPayment
                        : () {
                            // User needs more credits; pop this sheet and show the Top-up Dialog
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (_) => const WalletTopUpDialog(),
                            );
                          }),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        hasEnoughCredits
                            ? "Unlock for ${widget.creditCost} Credit"
                            : "Top Up Wallet via UPI",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Freemium Ad Fallback (Always show if ad is available or as a fallback)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primarySage,
                  side: BorderSide(color: primarySage.withValues(alpha: 0.3), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isProcessing ? null : _showRewardedAd,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text(
                  "Watch Ad to Unlock",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the standard Subscription Hard Paywall for Tier 1 international markets
  Widget _buildInternationalView() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primarySage,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            onPressed: () {
              // Close the bottom sheet and route to the full-page subscription screen
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: const Text(
              "View Premium Plans",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Get unlimited access with a 3-day free trial.",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}