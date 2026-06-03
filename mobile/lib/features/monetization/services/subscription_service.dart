import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// NeuroCalm AI - Production Subscription State
class SubscriptionState {
  final bool isPremium;
  final Offerings? offerings;
  final bool isLoading;
  final String? error;

  SubscriptionState({
    this.isPremium = false,
    this.offerings,
    this.isLoading = true,
    this.error,
  });

  SubscriptionState copyWith({
    bool? isPremium,
    Offerings? offerings,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionState(
      isPremium: isPremium ?? this.isPremium,
      offerings: offerings ?? this.offerings,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() {
    _initializeRevenueCat();
    return SubscriptionState();
  }

  /// --------------------------------------------------------
  /// 1. INITIALIZATION & DYNAMIC PRICING SETUP
  /// --------------------------------------------------------
  Future<void> _initializeRevenueCat() async {
    try {
      final apiKey = Platform.isAndroid 
          ? dotenv.env['RC_ANDROID_KEY'] ?? '' 
          : dotenv.env['RC_IOS_KEY'] ?? '';

      if (apiKey.isEmpty) {
        debugPrint('⚠️ [CRITICAL]: RevenueCat API Key is missing from .env');
        state = state.copyWith(isLoading: false, error: 'Configuration Error');
        return;
      }

      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
      
      // 🚨 ARCHITECT UPGRADE: Use the modern builder pattern for configuration
      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);

      // Fetch customer info locally (very fast)
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      final isActive = customerInfo.entitlements.all["premium"]?.isActive == true;

      // 🚨 TECH LEAD FIX: Hard timeout on fetching offerings to prevent infinite UI hangs
      Offerings? offerings;
      try {
        offerings = await Purchases.getOfferings().timeout(const Duration(seconds: 5));
      } on TimeoutException {
        debugPrint('⚠️ [Sub Service]: Network timeout fetching offerings. Defaulting to free tier logic.');
      }

      state = state.copyWith(
        isPremium: isActive,
        offerings: offerings,
        isLoading: false,
      );

      // Background entitlement listener (e.g., subscription renewal triggers while app is open)
      Purchases.addCustomerInfoUpdateListener((info) {
        final active = info.entitlements.all["premium"]?.isActive == true;
        if (state.isPremium != active) {
          state = state.copyWith(isPremium: active);
          debugPrint('✅ [Sub Service]: Entitlement state dynamically updated to: $active');
        }
      });
    } catch (e) {
      debugPrint('🚨 [Sub Service Init Error]: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// --------------------------------------------------------
  /// 2. AUTHENTICATION BRIDGE (Cross-Device Sync)
  /// --------------------------------------------------------
  
  /// Call this IMMEDIATELY after a user signs in or signs up via Firebase
  Future<void> linkAuthenticatedUser(String firebaseUid) async {
    try {
      final logInResult = await Purchases.logIn(firebaseUid);
      final isActive = logInResult.customerInfo.entitlements.all["premium"]?.isActive == true;
      
      state = state.copyWith(isPremium: isActive);
      debugPrint('✅ [Sub Service]: Synced RevenueCat AppUserID with Firebase UID.');
    } catch (e) {
      debugPrint('🚨 [Sub Service Login Error]: $e');
    }
  }

  /// Call this when a user logs out to prevent the next user from stealing their premium access
  Future<void> logoutUser() async {
    try {
      final customerInfo = await Purchases.logOut();
      final isActive = customerInfo.entitlements.all["premium"]?.isActive == true;
      
      state = state.copyWith(isPremium: isActive);
      debugPrint('✅ [Sub Service]: User logged out of RevenueCat securely.');
    } catch (e) {
      debugPrint('🚨 [Sub Service Logout Error]: $e');
    }
  }

  /// --------------------------------------------------------
  /// 3. LOCALIZED PURCHASE LOGIC
  /// --------------------------------------------------------
  Future<bool> purchasePackage(Package package) async {
    state = state.copyWith(isLoading: true);
    try {
      // ignore: deprecated_member_use
      final purchaseResult = await Purchases.purchasePackage(package);
      final customerInfo = purchaseResult.customerInfo;
      
      final isPremium = customerInfo.entitlements.all["premium"]?.isActive == true;
      
      state = state.copyWith(
        isPremium: isPremium,
        isLoading: false,
      );
      
      return isPremium;
      
    } on PlatformException catch (e) { 
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('🚨 [Purchase Error]: ${e.message}');
        state = state.copyWith(error: e.message, isLoading: false);
      } else {
        // User voluntarily closed the FaceID / Payment sheet
        state = state.copyWith(isLoading: false);
      }
      return false;
    }
  }

  /// --------------------------------------------------------
  /// 4. RESTORATION & SYNC
  /// --------------------------------------------------------
  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true);
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      final isPremium = customerInfo.entitlements.all["premium"]?.isActive == true;
      state = state.copyWith(isPremium: isPremium, isLoading: false);
    } catch (e) {
      debugPrint('🚨 [Restore Error]: $e');
      state = state.copyWith(isLoading: false, error: 'Restore Failed');
    }
  }

  Future<void> refreshStatus() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final active = info.entitlements.all["premium"]?.isActive == true;
      state = state.copyWith(isPremium: active);
    } catch (e) {
      debugPrint('🚨 [Status Refresh Error]: $e');
    }
  }
}

/// Global Provider for UI consumption
final subscriptionProvider = NotifierProvider<SubscriptionNotifier, SubscriptionState>(() {
  return SubscriptionNotifier();
});