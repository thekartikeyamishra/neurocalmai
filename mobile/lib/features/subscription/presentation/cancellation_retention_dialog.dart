import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';

/// A production-ready localized intercept dialog.
/// Triggered when a user taps "Manage Subscription" or "Cancel" in the settings.
/// Offers a RevenueCat-powered discount or a deep link to pause the subscription.
class CancellationRetentionDialog extends StatefulWidget {
  const CancellationRetentionDialog({super.key});

  /// Helper method to present the dialog globally
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true, // Allow tapping outside to dismiss
      builder: (context) => const CancellationRetentionDialog(),
    );
  }

  @override
  State<CancellationRetentionDialog> createState() => _CancellationRetentionDialogState();
}

class _CancellationRetentionDialogState extends State<CancellationRetentionDialog> {
  bool _isProcessing = false;

  static const Color _primaryGreen = Color(0xFF1E3A2F);
  static const Color _accentGreen = Color(0xFF2E6F56);
  static const Color _surfaceColor = Color(0xFFF9FAF9);

  /// Deep links the user to their native OS subscription management page.
  /// Google Play natively supports 1, 2, or 3-month pauses from this screen.
  Future<void> _launchSubscriptionManagement() async {
    final Uri playStoreUrl = Uri.parse('https://play.google.com/store/account/subscriptions');
    final Uri appStoreUrl = Uri.parse('https://apps.apple.com/account/subscriptions');

    final Uri targetUrl = Platform.isIOS ? appStoreUrl : playStoreUrl;

    try {
      if (await canLaunchUrl(targetUrl)) {
        await launchUrl(targetUrl, mode: LaunchMode.externalApplication);
      } else {
        _showError('Unable to open subscription settings. Please check your app store.');
      }
    } catch (e) {
      _showError('An error occurred while opening settings.');
    }
    
    // Close the dialog after routing the user away
    if (mounted) Navigator.of(context).pop();
  }

  /// Intercepts the cancellation by offering a highly discounted RevenueCat package.
  /// You must create a package with the identifier 'retention_discount' in your Offerings.
  Future<void> _claimDiscount() async {
    setState(() => _isProcessing = true);

    try {
      final offerings = await RevenueCatService.instance.fetchDynamicOfferings();
      
      // Locate the specific retention package
      final promoPackage = offerings?.current?.availablePackages.firstWhere(
        (pkg) => pkg.identifier == 'retention_discount',
        orElse: () => throw Exception('Promotional package not configured in RevenueCat.'),
      );

      if (promoPackage != null) {
        final success = await RevenueCatService.instance.purchasePackage(promoPackage);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Discount applied successfully. Thank you for staying with NeuroCalm!'),
              backgroundColor: _accentGreen,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      _showError('This discount is currently unavailable. Please try again later.');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon Header
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause_circle_outline_rounded,
                  size: 40,
                  color: Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Text Content
            const Text(
              'Need a break?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primaryGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Mental resilience takes time. Instead of losing your encrypted cognitive journal and streaks, you can pause your subscription for up to 3 months or claim a 50% discount on your next cycle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 28),

            // Primary Action: Discount
            ElevatedButton(
              onPressed: _isProcessing ? null : _claimDiscount,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                      'Claim 50% Off Next Cycle',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 10),

            // Secondary Action: Pause
            OutlinedButton(
              onPressed: _isProcessing ? null : _launchSubscriptionManagement,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryGreen,
                side: const BorderSide(color: _accentGreen, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Pause Subscription (1-3 Months)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tertiary Action: Cancel
            TextButton(
              onPressed: _isProcessing ? null : _launchSubscriptionManagement,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: const Text(
                'Continue to Cancellation',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}