/// Centralized configuration for all monetization identifiers.
/// These strings must exactly match the Product IDs configured in
/// Google Play Console, Apple App Store Connect, and RevenueCat.
class MonetizationConstants {
  // =========================================================================
  // REVENUECAT ENTITLEMENTS
  // =========================================================================

  /// The primary entitlement ID configured in the RevenueCat dashboard.
  /// Unlocking this grants the user full premium access regardless of how they paid.
  static const String entitlementPremium = 'NeuroCalm AI Pro';

  // =========================================================================
  // INDIA MARKET (SACHET / MICRO-TRANSACTIONS)
  // =========================================================================

  /// Consumable: Pack of 10 AI feature credits (e.g., ₹49)
  static const String sachetCbt10 = 'sachet_cbt_10';

  /// Consumable: Pack of 25 AI feature credits (e.g., ₹99)
  static const String sachetCbt25 = 'sachet_cbt_25';

  /// Non-Consumable: Lifetime premium unlock optimized for India (e.g., ₹1,499)
  static const String lifetimeAccessIn = 'lifetime_access';

  // =========================================================================
  // INTERNATIONAL MARKET (RECURRING SUBSCRIPTIONS)
  // =========================================================================

  /// Subscription: Standard Monthly Plan (e.g., $9.99/mo)
  static const String subMonthly = 'premium_monthly';

  /// Subscription: Standard Annual Plan (e.g., $79.99/yr)
  static const String subAnnual = 'premium_annual';

  // =========================================================================
  // WALLET & CREDIT ECONOMY
  // =========================================================================

  /// How many credits a specific premium action costs.
  /// Deducted locally and synced to Firestore.
  static const int costVoiceReframe = 1;
  static const int costSomaticGrounding = 1;
  static const int costClinicalExport = 2;

  // =========================================================================
  // ADMOB CONFIGURATION
  // =========================================================================

  /// Test Ad Unit IDs (Replace with production IDs from AdMob dashboard before launch)
  static const String rewardedAdUnitIdAndroid =
      'ca-app-pub-4557897331416844/2435930645';
  static const String rewardedAdUnitIdIOS =
      'ca-app-pub-4557897331416844/8198200276';
}
