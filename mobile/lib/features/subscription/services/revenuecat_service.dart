/* cSpell:disable */
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// A production-ready service for managing RevenueCat subscriptions.
/// Handles dynamic A/B test offerings (Quarterly $29.99 / Annual $49.99),
/// retention package overrides, partner affiliate attribution (yoga studios),
/// and seamless identity synchronization with Firebase Authentication.
class RevenueCatService {
  static final RevenueCatService instance = RevenueCatService._internal();
  RevenueCatService._internal();

  // Replace with your RevenueCat project API Keys
  static const String _appleApiKey = 'appl_YOUR_REVENUECAT_APPLE_KEY';
  static const String _googleApiKey = 'goog_YOUR_REVENUECAT_GOOGLE_KEY';

  /// Primary entitlement identifier configured in the RevenueCat dashboard.
  static const String _premiumEntitlementKey = 'premium';

  /// Package identifier for retention down-sell offers.
  static const String _retentionPackageIdentifier = 'retention_discount';

  /// Initializes the RevenueCat SDK, setting debug levels and configuring the
  /// session with the Firebase Auth UID (anonymous or authenticated).
  Future<void> initialize() async {
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);

      final String apiKey = Platform.isIOS ? _appleApiKey : _googleApiKey;
      final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

      final configuration = PurchasesConfiguration(apiKey)
        ..appUserID = currentUid;

      await Purchases.configure(configuration);
      debugPrint(
        '✅ [RevenueCat]: Initialized successfully for user: $currentUid',
      );
    } catch (e) {
      debugPrint('🚨 [RevenueCat Error]: SDK initialization failed: $e');
    }
  }

  /// Fetches dynamic A/B test offerings directly from the RevenueCat dashboard.
  /// Automatically resolves the assigned experiment offering variant for the user.
  Future<Offerings?> fetchDynamicOfferings() async {
    try {
      final Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        debugPrint(
          '✅ [RevenueCat]: Active offering resolved: ${offerings.current!.identifier}',
        );
        return offerings;
      }
      debugPrint('⚠️ [RevenueCat]: No active offering set on dashboard.');
      return null;
    } on PlatformException catch (e) {
      debugPrint(
        '🚨 [RevenueCat Error]: Failed to fetch offerings: ${e.message}',
      );
      return null;
    }
  }

  /// Extracts the active Quarterly and Annual packages from the current offering.
  /// Matches standard PackageType enums first, falling back to identifier matching.
  Future<Map<String, Package?>> getSubscriptionPackages() async {
    final offerings = await fetchDynamicOfferings();
    final currentOffering = offerings?.current;

    if (currentOffering == null || currentOffering.availablePackages.isEmpty) {
      return {'quarterly': null, 'annual': null};
    }

    // 1. Resolve Quarterly (3-Month) Package
    Package? quarterlyPackage;
    try {
      quarterlyPackage = currentOffering.availablePackages.firstWhere(
        (pkg) =>
            pkg.packageType == PackageType.threeMonth ||
            pkg.identifier == '\$rc_three_month' ||
            pkg.identifier.toLowerCase().contains('quarterly'),
      );
    } catch (_) {
      quarterlyPackage = null;
    }

    // 2. Resolve Annual (12-Month) Package
    Package? annualPackage;
    try {
      annualPackage = currentOffering.availablePackages.firstWhere(
        (pkg) =>
            pkg.packageType == PackageType.annual ||
            pkg.identifier == '\$rc_annual' ||
            pkg.identifier.toLowerCase().contains('annual'),
      );
    } catch (_) {
      annualPackage = null;
    }

    // Fallbacks if customized tier keys were assigned in an experiment
    if (quarterlyPackage == null &&
        currentOffering.availablePackages.isNotEmpty) {
      quarterlyPackage = currentOffering.availablePackages.first;
    }
    if (annualPackage == null && currentOffering.availablePackages.length > 1) {
      annualPackage = currentOffering.availablePackages[1];
    }

    return {'quarterly': quarterlyPackage, 'annual': annualPackage};
  }

  /// Fetches the specialized retention package used by CancellationRetentionDialog.
  Future<Package?> fetchRetentionPackage() async {
    try {
      final offerings = await fetchDynamicOfferings();
      final currentOffering = offerings?.current;
      if (currentOffering == null) return null;

      for (final package in currentOffering.availablePackages) {
        if (package.identifier == _retentionPackageIdentifier) {
          return package;
        }
      }
      return null;
    } catch (e) {
      debugPrint(
        '🚨 [RevenueCat Error]: Failed to fetch retention package: $e',
      );
      return null;
    }
  }

  /// Executes an in-app purchase for the chosen package.
  Future<bool> purchasePackage(Package package) async {
    try {
      // ignore: deprecated_member_use
      final PurchaseResult result = await Purchases.purchasePackage(package);
      final bool isPremium =
          result
              .customerInfo
              .entitlements
              .all[_premiumEntitlementKey]
              ?.isActive ??
          false;

      if (isPremium) {
        debugPrint(
          '✅ [RevenueCat]: Purchase confirmed. Premium entitlement active.',
        );
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('ℹ️ [RevenueCat]: User cancelled checkout.');
      } else {
        debugPrint(
          '🚨 [RevenueCat Error]: Purchase failed: ${e.code} - ${e.message}',
        );
      }
      return false;
    } catch (e) {
      debugPrint('🚨 [RevenueCat Error]: Unexpected purchase exception: $e');
      return false;
    }
  }

  /// Verifies if the active user currently holds the required premium entitlement.
  Future<bool> checkPremiumStatus() async {
    try {
      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      final bool isPremium =
          customerInfo.entitlements.all[_premiumEntitlementKey]?.isActive ??
          false;
      return isPremium;
    } catch (e) {
      debugPrint('🚨 [RevenueCat Error]: Failed to check premium status: $e');
      return false;
    }
  }

  /// Restores previous purchases across devices or after app reinstalls.
  Future<bool> restorePurchases() async {
    try {
      final CustomerInfo customerInfo = await Purchases.restorePurchases();
      final bool isPremium =
          customerInfo.entitlements.all[_premiumEntitlementKey]?.isActive ??
          false;

      if (isPremium) {
        debugPrint('✅ [RevenueCat]: Purchases restored. Premium active.');
      } else {
        debugPrint(
          'ℹ️ [RevenueCat]: Restore completed, no active entitlements found.',
        );
      }
      return isPremium;
    } on PlatformException catch (e) {
      debugPrint('🚨 [RevenueCat Error]: Restore failed: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('🚨 [RevenueCat Error]: Unexpected restore error: $e');
      return false;
    }
  }

  /// Attaches marketing and referral attribution tags to the subscriber record.
  /// Enables automated B2B2C revenue-share calculations for yoga studio partners
  /// and tracks high-intent campaign sources parsed from the Play Install Referrer.
  Future<void> attachPartnerAffiliate({
    required String studioAffiliateId,
    String? campaignSource,
    Map<String, String>? additionalMetadata,
  }) async {
    try {
      final Map<String, String> attributes = {
        'affiliate_partner_id': studioAffiliateId,
        'partnership_type': 'yoga_studio_b2b2c',
        ...?additionalMetadata,
      };

      // Set dynamically outside of the map literal to cleanly bypass the
      // Dart 3.8+ use_null_aware_elements linter rule.
      if (campaignSource != null) {
        attributes['campaign_source'] = campaignSource;
      }

      await Purchases.setAttributes(attributes);
      debugPrint(
        '✅ [RevenueCat]: Partner affiliate attributes synced: $attributes',
      );
    } catch (e) {
      debugPrint('🚨 [RevenueCat Error]: Failed to set partner attributes: $e');
    }
  }

  /// Synchronizes an existing anonymous session with an upgraded Firebase Auth UID
  /// (e.g., when the user secures their vault using Email or Google credentials).
  Future<void> syncAuthenticatedUser(String newUid) async {
    try {
      final LogInResult result = await Purchases.logIn(newUid);
      debugPrint(
        '✅ [RevenueCat]: Synced to new UID ($newUid). Created new subscriber: ${result.created}',
      );
    } on PlatformException catch (e) {
      debugPrint('🚨 [RevenueCat Error]: UID sync failed: ${e.message}');
    } catch (e) {
      debugPrint('🚨 [RevenueCat Error]: Unexpected UID sync error: $e');
    }
  }

  /// Signs out of the RevenueCat instance and generates a fresh anonymous App User ID.
  Future<void> resetSession() async {
    try {
      await Purchases.logOut();
      debugPrint(
        '✅ [RevenueCat]: Logged out and reset to anonymous subscriber.',
      );
    } catch (e) {
      debugPrint('🚨 [RevenueCat Error]: Session reset failed: $e');
    }
  }
}
