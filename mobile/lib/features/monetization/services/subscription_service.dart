import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/services/iap_service.dart';

/// Immutable premium state consumed by several screens.
class SubscriptionState {
  final bool isPremium;
  final List<ProductDetails> products;
  final bool isLoading;
  final String? error;

  SubscriptionState({
    this.isPremium = false,
    this.products = const [],
    this.isLoading = false,
    this.error,
  });

  SubscriptionState copyWith({
    bool? isPremium,
    List<ProductDetails>? products,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionState(
      isPremium: isPremium ?? this.isPremium,
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// FIX: this used to run a SECOND, independent Google Play billing client
/// (in_app_purchase) next to RevenueCat, with different product ids and a
/// receipt check that always returned `true`. Users who paid through
/// RevenueCat were not recognised as premium on screens that read this
/// provider (they still saw ads/locks), and any restored purchase counted as
/// premium. It is now a thin mirror of [IAPService] (RevenueCat = single
/// source of truth for entitlements).
class SubscriptionNotifier extends Notifier<SubscriptionState> {
  StreamSubscription<bool>? _sub;

  @override
  SubscriptionState build() {
    final iap = IAPService();
    _sub?.cancel();
    _sub = iap.premiumStatusStream.listen((isPremium) {
      state = state.copyWith(isPremium: isPremium, isLoading: false);
    });
    ref.onDispose(() => _sub?.cancel());
    return SubscriptionState(isPremium: iap.isPremium);
  }

  /// Legacy native-store path is retired; purchases go through RevenueCat
  /// packages (see PremiumPaywallScreen / WalletTopUpDialog).
  Future<void> purchaseProduct(ProductDetails product) async {
    debugPrint('ℹ️ [Subscription]: native purchase path retired; use RevenueCat packages.');
    state = state.copyWith(error: 'Please use the Premium screen to subscribe.');
  }

  Future<void> restorePastPurchases() async {
    state = state.copyWith(isLoading: true);
    final premium = await IAPService().restorePurchases();
    state = state.copyWith(isPremium: premium, isLoading: false);
  }
}

final subscriptionProvider = NotifierProvider<SubscriptionNotifier, SubscriptionState>(() {
  return SubscriptionNotifier();
});
