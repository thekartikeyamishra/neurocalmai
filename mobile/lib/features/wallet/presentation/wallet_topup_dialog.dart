import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/services/wallet_service.dart';
import '../../../core/constants/monetization_constants.dart';

/// A modal dialog specifically designed for the Indian market to facilitate
/// frictionless, UPI-driven micro-transactions (Sachets).
/// Fetches consumable credit packs from RevenueCat and updates the local wallet.
class WalletTopUpDialog extends StatefulWidget {
  const WalletTopUpDialog({super.key});

  @override
  State<WalletTopUpDialog> createState() => _WalletTopUpDialogState();
}

class _WalletTopUpDialogState extends State<WalletTopUpDialog> {
  final IAPService _iapService = IAPService();
  final WalletService _walletService = WalletService();

  bool _isLoading = true;
  bool _isProcessing = false;

  List<Package> _availablePacks = [];
  Package? _selectedPack;

  // Brand Colors
  final Color primarySage = const Color(0xFF2F5244);
  final Color creamBg = const Color(0xFFFBFAF6);

  @override
  void initState() {
    super.initState();
    _fetchCreditPacks();
  }

  /// Fetches the current offerings from RevenueCat and filters for consumable sachet packs.
  Future<void> _fetchCreditPacks() async {
    final offerings = await _iapService.getOfferings();
    
    if (!mounted) return;

    if (offerings != null && offerings.current != null) {
      // Filter the offerings to only show the consumable packages defined in our constants
      final allPackages = offerings.current!.availablePackages;
      
      final sachetPackages = allPackages.where((p) {
        final id = p.storeProduct.identifier;
        return id == MonetizationConstants.sachetCbt10 || 
               id == MonetizationConstants.sachetCbt25;
      }).toList();

      // Sort by price (lowest first)
      sachetPackages.sort((a, b) => a.storeProduct.price.compareTo(b.storeProduct.price));

      setState(() {
        _availablePacks = sachetPackages;
        if (sachetPackages.isNotEmpty) {
          _selectedPack = sachetPackages.first;
        }
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// Maps the purchased RevenueCat package identifier to the actual credit amount
  int _getCreditsForPackage(String productIdentifier) {
    if (productIdentifier == MonetizationConstants.sachetCbt10) return 10;
    if (productIdentifier == MonetizationConstants.sachetCbt25) return 25;
    return 0; // Fallback
  }

  /// Executes the micro-transaction via Google Play Billing / UPI
  Future<void> _processTopUp() async {
    if (_selectedPack == null) return;

    setState(() => _isProcessing = true);

    try {
      // Execute the purchase via RevenueCat natively.
      // RevenueCat automatically throws an exception if the purchase is cancelled or fails.
      // ignore: deprecated_member_use
      await Purchases.purchasePackage(_selectedPack!);
      
      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Since we just purchased it, we proceed to add credits. 
      // (In a heavily secure app, you might rely on webhooks, but this is sufficient for client-side unlocking)
      final creditsToAdd = _getCreditsForPackage(_selectedPack!.storeProduct.identifier);
      
      if (creditsToAdd > 0) {
        await _walletService.addCredits(creditsToAdd);
        
        if (mounted) {
          Navigator.pop(context); // Close the dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Successfully added $creditsToAdd credits to your wallet!"),
              backgroundColor: primarySage,
            ),
          );
        }
      } else {
         throw Exception("Invalid package configuration.");
      }

    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      
      // The user likely cancelled the UPI/Google Play modal
      debugPrint("Purchase Failed or Cancelled: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Transaction cancelled or failed. Your account was not charged."),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: creamBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primarySage.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_balance_wallet_rounded, size: 40, color: primarySage),
            ),
            const SizedBox(height: 16),
            
            // Title
            Text(
              "Top Up Wallet",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primarySage,
                fontFamily: 'Fraunces',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Select a credit pack to unlock premium offline sessions.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Package List State Handling
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: CircularProgressIndicator(),
              )
            else if (_availablePacks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "No credit packs available at this time.\nPlease try again later.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ..._availablePacks.map((pack) => _buildPackOption(pack)),

            const SizedBox(height: 24),

            // Checkout Action
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primarySage,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                onPressed: (_isProcessing || _selectedPack == null) ? null : _processTopUp,
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.security_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _selectedPack != null 
                                ? "Pay ${_selectedPack!.storeProduct.priceString} via UPI"
                                : "Select a Pack",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Secured by Google Play Billing",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an individual selection row for a credit pack
  Widget _buildPackOption(Package package) {
    final isSelected = _selectedPack?.identifier == package.identifier;
    final credits = _getCreditsForPackage(package.storeProduct.identifier);

    return GestureDetector(
      onTap: () {
        if (!_isProcessing) {
          setState(() => _selectedPack = package);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primarySage.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? primarySage : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Radio Circle
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primarySage : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: primarySage,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$credits AI Sessions",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? primarySage : Colors.black87,
                    ),
                  ),
                  if (credits == 25)
                    Text(
                      "Most Popular",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            
            // Price Tag
            Text(
              package.storeProduct.priceString,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected ? primarySage : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}