import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Cloud-controlled levers (ads, economy copy, force-update) with offline-safe
/// defaults. IMPORTANT FIX: the old version awaited a network fetch with a
/// 1-minute timeout during app start, so offline/slow users stared at a
/// frozen splash for up to 60s (a major Day-1 churn cause). Defaults now
/// apply instantly and the fetch runs in the background.
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  FirebaseRemoteConfig? _rc;

  static const Map<String, dynamic> _defaults = {
    // Ads (all tunable live from the Firebase console).
    'ad_grace_period_sessions': 1, // first app session is 100% ad-free
    'banner_ads_enabled': true,
    'native_ads_enabled': true,
    'interstitial_enabled': true,
    'interstitial_min_session': 3,
    'interstitial_cooldown_seconds': 180,
    'interstitial_daily_cap': 4,
    'app_open_enabled': true,
    'app_open_min_session': 4,
    'app_open_cooldown_minutes': 240,
    // Economy (display only — the server is authoritative).
    'rewarded_ad_credit_payout': 2,
    'free_daily_ai_calls': 5,
    // Release safety.
    'min_supported_build': 0,
    'latest_build': 0,
    // Public contact + legal pages (Firebase Hosting); change live any time.
    'support_email': 'kartikeyamishra099@gmail.com',
    'privacy_policy_url': 'https://neurocalmnow.web.app/privacy',
    'terms_url': 'https://neurocalmnow.web.app/terms',
    'play_store_url':
        'https://play.google.com/store/apps/details?id=com.kartikeyamishra.mobile',
  };

  /// Applies defaults immediately; fetches fresh values in the background.
  Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      _rc = rc;
      await rc.setDefaults(_defaults);
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval:
            kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 6),
      ));
      // Activate whatever was fetched last session (instant, no network).
      await rc.activate();
      unawaited(_refresh(rc));
    } catch (e) {
      debugPrint('🚨 [RemoteConfig]: init failed, using built-in defaults: $e');
    }
  }

  Future<void> _refresh(FirebaseRemoteConfig rc) async {
    try {
      await rc.fetchAndActivate();
      rc.onConfigUpdated.listen(
        (_) async {
          try {
            await rc.activate();
          } catch (_) {}
        },
        onError: (Object e) => debugPrint('⚠️ [RemoteConfig]: realtime: $e'),
      );
    } catch (e) {
      debugPrint('⚠️ [RemoteConfig]: background fetch failed: $e');
    }
  }

  int _int(String key) {
    try {
      final rc = _rc;
      if (rc != null) return rc.getInt(key);
    } catch (_) {}
    final v = _defaults[key];
    return v is int ? v : 0;
  }

  bool _bool(String key) {
    try {
      final rc = _rc;
      if (rc != null) return rc.getBool(key);
    } catch (_) {}
    final v = _defaults[key];
    return v is bool ? v : false;
  }

  String _string(String key) {
    try {
      final rc = _rc;
      if (rc != null) {
        final s = rc.getString(key);
        if (s.isNotEmpty) return s;
      }
    } catch (_) {}
    final v = _defaults[key];
    return v is String ? v : '';
  }

  int get adGracePeriodSessions => _int('ad_grace_period_sessions');
  bool get bannerAdsEnabled => _bool('banner_ads_enabled');
  bool get nativeAdsEnabled => _bool('native_ads_enabled');
  bool get interstitialEnabled => _bool('interstitial_enabled');
  int get interstitialMinSession => _int('interstitial_min_session');
  int get interstitialCooldownSeconds => _int('interstitial_cooldown_seconds');
  int get interstitialDailyCap => _int('interstitial_daily_cap');
  bool get appOpenEnabled => _bool('app_open_enabled');
  int get appOpenMinSession => _int('app_open_min_session');
  int get appOpenCooldownMinutes => _int('app_open_cooldown_minutes');

  /// Credits granted per rewarded ad (display only; server decides).
  int get rewardedAdCreditPayout {
    final v = _int('rewarded_ad_credit_payout');
    return v > 0 ? v : 2;
  }

  int get freeDailyAiCalls => _int('free_daily_ai_calls');
  int get minSupportedBuild => _int('min_supported_build');
  int get latestBuild => _int('latest_build');
  String get supportEmail => _string('support_email');
  String get privacyPolicyUrl => _string('privacy_policy_url');
  String get termsUrl => _string('terms_url');
  String get playStoreUrl => _string('play_store_url');

  // Kept for backwards compatibility with existing callers.
  String get primaryAiModel => _string('primary_ai_model');
  String get fallbackAiModel => _string('fallback_ai_model');
}
