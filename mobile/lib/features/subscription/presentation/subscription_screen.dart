import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/services/iap_service.dart';

/// The premium subscription paywall primarily designed for International (Tier 1) markets.
/// Fetches dynamic pricing from RevenueCat, highlights a 3-day free trial, 
/// and includes mandatory compliance buttons (Restore Purchases, ToS).
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final IAPService _iapService = IAPService();
  
  bool _isLoading = true;
  bool _isProcessingPurchase = false;
  
  Offerings? _offerings;
  Package? _selectedPackage;

  // Brand Colors
  final Color primarySage = const Color(0xFF2F5244);
  final Color creamBg = const Color(0xFFFBFAF6);
  final Color goldAccent = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  /// Fetches the localized subscription tiers from RevenueCat
  Future<void> _fetchOfferings() async {
    final offerings = await _iapService.getOfferings();
    
    if (!mounted) return;
    
    setState(() {
      _offerings = offerings;
      _isLoading = false;
      
      // Default to the Annual package if available to nudge higher LTV, 
      // otherwise fallback to whatever is first.
      if (offerings != null && offerings.current != null) {
        final available = offerings.current!.availablePackages;
        if (available.isNotEmpty) {
          _selectedPackage = available.firstWhere(
            (p) => p.packageType == PackageType.annual,
            orElse: () => available.first,
          );
        }
      }
    });
  }

  /// Executes the purchase via RevenueCat
  Future<void> _processPurchase() async {
    if (_selectedPackage == null) return;

    setState(() => _isProcessingPurchase = true);

    final success = await _iapService.purchasePackage(_selectedPackage!);

    if (!mounted) return;
    setState(() => _isProcessingPurchase = false);

    if (success) {
      Navigator.pop(context); // Unlock and return to app
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Welcome to NeuroCalm Premium!"),
          backgroundColor: primarySage,
        ),
      );
    } else {
      // Typically user cancellation or payment decline
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Purchase was not completed. Please try again."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Restores previous purchases (Crucial for App Store compliance)
  Future<void> _restorePurchases() async {
    setState(() => _isProcessingPurchase = true);
    
    final success = await _iapService.restorePurchases();
    
    if (!mounted) return;
    setState(() => _isProcessingPurchase = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Purchases successfully restored!"),
          backgroundColor: primarySage,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No active subscriptions found to restore."),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: primarySage,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primarySage))
          : _buildPaywallContent(),
    );
  }

  Widget _buildPaywallContent() {
    if (_offerings == null || _offerings!.current == null || _offerings!.current!.availablePackages.isEmpty) {
      return Center(
        child: Text(
          "Subscriptions are currently unavailable.\nPlease check back later.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
        ),
      );
    }

    final packages = _offerings!.current!.availablePackages;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Hero Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primarySage.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.psychology_alt_rounded, size: 64, color: primarySage),
                  ),
                  const SizedBox(height: 24),
                  
                  // Headline
                  Text(
                    "Master Your Mind.",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primarySage,
                      fontFamily: 'Fraunces',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Unlock private, unlimited CBT reframes and biometric grounding tools.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.4),
                  ),
                  const SizedBox(height: 32),

                  // Feature Benefits Matrix
                  _buildFeatureRow(Icons.mic_none_rounded, "Voice-to-Reframe Engine", "Speak your thoughts. We structure them."),
                  const SizedBox(height: 16),
                  _buildFeatureRow(Icons.camera_front_rounded, "Biometric Grounding", "Face-tracking to map and lower your stress."),
                  const SizedBox(height: 16),
                  _buildFeatureRow(Icons.shield_rounded, "100% Private Offline Vault", "Your data stays on your device, always."),
                  const SizedBox(height: 32),

                  // Subscription Tiers
                  ...packages.map((package) => _buildPackageCard(package)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Sticky Bottom Action Area
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primarySage,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isProcessingPurchase ? null : _processPurchase,
                    child: _isProcessingPurchase
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            "Start 3-Day Free Trial",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Compliance Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: _isProcessingPurchase ? null : _restorePurchases,
                      child: const Text("Restore", style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
                    ),
                    const Text("•", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    GestureDetector(
                      onTap: () { /* Navigate to ToS URL */ },
                      child: const Text("Terms", style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
                    ),
                    const Text("•", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    GestureDetector(
                      onTap: () { /* Navigate to Privacy Policy URL */ },
                      child: const Text("Privacy", style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
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

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primarySage, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPackageCard(Package package) {
    final isSelected = _selectedPackage?.identifier == package.identifier;
    final isAnnual = package.packageType == PackageType.annual;

    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = package),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primarySage.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: isSelected ? primarySage : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Radio button UI
            Container(
              width: 24,
              height: 24,
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
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: primarySage,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isAnnual ? "Annual Plan" : "Monthly Plan",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (isAnnual) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: goldAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "SAVE 55%",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.storeProduct.priceString,
                    style: TextStyle(
                      color: isSelected ? primarySage : Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
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