// cSpell:disable
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../constants/monetization_constants.dart';

/// A production-ready singleton service managing all In-App Purchases and Subscriptions
/// via RevenueCat. Handles cross-platform edge cases (Android, iOS, Web) and
/// seamlessly bridges Indian micro-transactions with International subscriptions.
class IAPService {
  // Singleton instance
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  // Integrated specific RevenueCat Android Public API Key
  static const String _apiKeyAndroid = 'goog_tHrWrlWkDXdSDbtIqmwAFBjCEQC';

  static const String _apiKeyIOS = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
    defaultValue: '',
  );

  // Stream controller to broadcast premium status changes to the UI globally
  final _premiumStatusController = StreamController<bool>.broadcast();
  Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  // Completes once Purchases.configure() has finished (or failed), so a
  // login racing with init can't run against an unconfigured SDK — which
  // left purchases on an anonymous RevenueCat id the webhook can't map.
  final Completer<void> _configured = Completer<void>();

  /// Initializes the RevenueCat SDK based on the current platform.
  /// Call this immediately after Firebase initialization in `main.dart`.
  Future<void> init(String? appUserId) async {
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);

      late PurchasesConfiguration configuration;

      if (defaultTargetPlatform == TargetPlatform.android) {
        configuration = PurchasesConfiguration(_apiKeyAndroid);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        if (_apiKeyIOS.isEmpty) {
          debugPrint("⚠️ WARNING: iOS RevenueCat key is empty.");
        }
        configuration = PurchasesConfiguration(_apiKeyIOS);
      } else {
        debugPrint("⚠️ Unsupported platform for In-App Purchases");
        return;
      }

      // Tie the RevenueCat user directly to the Firebase Auth UID
      if (appUserId != null && appUserId.isNotEmpty) {
        configuration.appUserID = appUserId;
      }

      await Purchases.configure(configuration);
      if (!_configured.isCompleted) _configured.complete();

      // Listen for changes in customer info (e.g., subscription expires, or purchase made on another device)
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updatePremiumStatus(customerInfo);
      });

      // Initial status check
      final initialInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus(initialInfo);
    } catch (e) {
      debugPrint("🚨 [RevenueCat Initialization Error]: $e");
    } finally {
      if (!_configured.isCompleted) _configured.complete();
    }
  }

  /// Logs the user into RevenueCat.
  /// Call this when a user signs in via Firebase Auth.
  Future<void> loginUser(String uid) async {
    try {
      await _configured.future.timeout(const Duration(seconds: 20));
      final logInResult = await Purchases.logIn(uid);
      _updatePremiumStatus(logInResult.customerInfo);
    } catch (e) {
      debugPrint("🚨 [RevenueCat Login Error]: $e");
    }
  }

  /// Logs the user out of RevenueCat.
  /// Call this when a user signs out of Firebase Auth.
  Future<void> logoutUser() async {
    try {
      final customerInfo = await Purchases.logOut();
      _updatePremiumStatus(customerInfo);
    } catch (e) {
      debugPrint("🚨 [RevenueCat Logout Error]: $e");
    }
  }

  /// Fetches the current offerings configured in the RevenueCat dashboard.
  /// This automatically returns localized pricing (₹ for India, $ for US) based on the Store.
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (e) {
      debugPrint("🚨 [Fetch Offerings Error]: ${e.message}");
      return null;
    }
  }

  /// Executes a direct native purchase for a specific package.
  /// NOTE: When using the new MonetizationCircuitBreaker in the UI, you will 
  /// bypass this specific method and pass the Package directly to the breaker. 
  /// This method remains intact as a structural fallback.
  Future<bool> purchasePackage(Package package) async {
    try {
      // Safely bypass the missing PurchaseParams constructor and extract the customerInfo natively
      // ignore: deprecated_member_use
      final purchaseResult = await Purchases.purchasePackage(package);
      final customerInfo = purchaseResult.customerInfo;

      // Update local state based on the new entitlement
      _updatePremiumStatus(customerInfo);

      // Verify if the purchase successfully unlocked the premium entitlement
      return _isPremiumStatusActive(customerInfo);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("⚠️ User cancelled the purchase flow.");
      } else {
        debugPrint("🚨 [IAP Purchase Error]: ${e.message}");
      }
      return false;
    } catch (e) {
      debugPrint("🚨 [Unexpected Purchase Error]: $e");
      return false;
    }
  }

  /// Restores previous purchases.
  /// Mandatory for App Store compliance and crucial for users switching phones.
  Future<bool> restorePurchases() async {
    if (kIsWeb) return false;

    try {
      final customerInfo = await Purchases.restorePurchases();
      _updatePremiumStatus(customerInfo);
      return _isPremiumStatusActive(customerInfo);
    } on PlatformException catch (e) {
      debugPrint("🚨 [Restore Purchases Error]: ${e.message}");
      return false;
    }
  }

  // =========================================================================
  // PRIVATE HELPER METHODS
  // =========================================================================

  /// Evaluates if the premium entitlement is currently active.
  bool _isPremiumStatusActive(CustomerInfo customerInfo) {
    final ents = customerInfo.entitlements;
    // Primary: the configured entitlement. Fallback: any active entitlement,
    // so a renamed entitlement in the RevenueCat dashboard can never lock
    // out a paying user (the single worst churn + refund trigger).
    return ents.all[MonetizationConstants.entitlementPremium]?.isActive == true ||
        ents.active.isNotEmpty;
  }

  /// Updates the global premium status and broadcasts it to the UI layer.
  void _updatePremiumStatus(CustomerInfo customerInfo) {
    final isActive = _isPremiumStatusActive(customerInfo);
    if (_isPremium != isActive) {
      _isPremium = isActive;
      _premiumStatusController.add(_isPremium);
      debugPrint("👑 [Premium Status Updated]: $_isPremium");
    }
  }

  /// Dispose stream
  void dispose() {
    _premiumStatusController.close();
  }
}
// cSpell:enable