// cSpell:disable
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../constants/monetization_constants.dart';
import '../services/wallet_service.dart';
import '../theme/app_tokens.dart';
import '../../features/monetization/services/admob_service.dart';

/// A fault-tolerant monetization gateway.
/// Intercepts native purchase failures and routes users to an ad-supported 
/// value exchange to preserve net profit and prevent session abandonment.
class MonetizationCircuitBreaker {
  
  /// Attempts to process a premium subscription or in-app purchase. 
  /// If it fails (network drop, declined card, user cancellation), 
  /// it seamlessly pivots the user to the Sponsor Reward economy.
  static Future<void> attemptPurchaseOrFallback({
    required BuildContext context,
    required Package package,
    required VoidCallback onSuccess,
  }) async {
    try {
      // 1. Attempt the Native Subscription via RevenueCat
      // ignore: deprecated_member_use
      final purchaseResult = await Purchases.purchasePackage(package);
      final customerInfo = purchaseResult.customerInfo;
      
      // FIX: entitlement id must match RevenueCat ('NeuroCalm AI Pro'); the
      // old hard-coded "premium" meant paid users never got unlocked here.
      final ents = customerInfo.entitlements;
      final active = ents.all[MonetizationConstants.entitlementPremium]?.isActive == true ||
          ents.active.isNotEmpty;
      if (active) {
        debugPrint('💰 [Purchase Success]: Subscription activated.');
        onSuccess();
      }
    } on PlatformException catch (e) {
      // 2. The Circuit Breaker catches the failure safely
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        // Respect the user's choice: no guilt sheet after a deliberate cancel.
        debugPrint('⚠️ [Purchase Canceled]: User backed out of the payment sheet.');
        return;
      }
      debugPrint('🚨 [Purchase Failed]: Network drop, declined card, or store error. Code: $errorCode');

      // 3. Pivot to the Ad Economy to save the monetization
      if (context.mounted) {
        _triggerAdFallback(context, onSuccess);
      }
    } catch (e) {
      // Catch-all for any non-Platform exceptions during checkout
      debugPrint('🚨 [Purchase Error]: Unexpected error during checkout: $e');
      if (context.mounted) {
        _triggerAdFallback(context, onSuccess);
      }
    }
  }

  /// Displays the fallback UI if a sponsor message is cached and ready.
  static void _triggerAdFallback(BuildContext context, VoidCallback onGranted) {
    // Only offer the fallback if an ad is actually cached and ready to play
    if (!AdMobService.instance.isRewardedAdReady.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payment failed. Please check your connection and try again.'),
          backgroundColor: AppTokens.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTokens.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 24.0, 
            right: 24.0, 
            top: 24.0, 
            bottom: 32.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24.0),
                decoration: BoxDecoration(
                  color: AppTokens.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              const Icon(
                Icons.error_outline_rounded, 
                color: AppTokens.warning, 
                size: 56,
              ),
              const SizedBox(height: 20),
              Text(
                "Transaction Interrupted",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTokens.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "We couldn't process your payment right now. Don't let that stop your momentum.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTokens.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
                  label: const Text(
                    "Watch Sponsor Message to Continue",
                    style: TextStyle(
                      fontSize: 15, 
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Dismiss bottom sheet
                    
                    // Trigger the AdMob Service to grant wallet credits
                    AdMobService.instance.showRewardedAd(
                      onEarnedReward: onGranted,
                      onEarnedRewardWithNonce: (nonce) {
                        // Server-verified credit grant (capped, idempotent).
                        WalletService().claimAdReward(nonce);
                      },
                      onAdClosed: () {
                        // Handled internally by AdMobService, UI resets automatically
                      },
                      onAdFailed: () {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Failed to load the sponsor message.'),
                              backgroundColor: AppTokens.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.onSurfaceVariant,
                ),
                child: const Text(
                  "Cancel",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// cSpell:enable