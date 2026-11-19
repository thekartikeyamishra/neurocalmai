// cSpell:disable
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ads/ad_config.dart';
import '../../../core/ads/ad_consent_service.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/services/remote_config_service.dart';

/// The single owner of the Google Mobile Ads SDK.
///
/// Revenue design (retention-safe):
/// * Session 1 is ad-free (first impression = product, not ads).
/// * Native + adaptive banner on browse surfaces (dashboard, library,
///   timeline, calendar) — never inside breathing, panic, voice or crisis UI.
/// * Interstitials only at natural breaks *after* a completed session,
///   capped per day and spaced by a cooldown (Remote Config).
/// * App-open ad for returning users, at most once per cooldown window.
/// * Rewarded ads are opt-in value exchange (credits), verified server-side.
/// * Premium users never see ads.
class AdMobService {
  static final AdMobService instance = AdMobService._internal();
  AdMobService._internal();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadedAt;

  final ValueNotifier<bool> isRewardedAdReady = ValueNotifier<bool>(false);

  /// Flips to true once consent + SDK init finished, so widgets built
  /// earlier (e.g. the dashboard on a fast cold start) can load their ads.
  final ValueNotifier<bool> sdkReadyNotifier = ValueNotifier<bool>(false);

  bool _sdkReady = false;
  bool _isShowingFullScreen = false;
  bool _rewardedLoading = false;
  bool _interstitialLoading = false;
  bool _appOpenLoading = false;
  int _rewardedAttempts = 0;
  int _interstitialAttempts = 0;
  int _sessionCount = 0;
  DateTime? _lastFullScreenAt;
  StreamSubscription<AppState>? _appStateSub;

  static const _kSessionCount = 'ads_session_count';
  static const _kInterstitialDay = 'ads_interstitial_day';
  static const _kInterstitialCount = 'ads_interstitial_count';
  static const _kLastInterstitial = 'ads_last_interstitial_ms';
  static const _kLastAppOpen = 'ads_last_app_open_ms';

  bool get isSdkReady => _sdkReady;
  int get sessionCount => _sessionCount;

  /// True when this user may see *any* ad right now.
  bool get canServeAds {
    if (!_sdkReady) return false;
    if (IAPService().isPremium) return false;
    return _sessionCount > RemoteConfigService().adGracePeriodSessions;
  }

  bool get canServeBanner =>
      canServeAds && RemoteConfigService().bannerAdsEnabled && AdConfig.banner.isNotEmpty;
  bool get canServeNative =>
      canServeAds && RemoteConfigService().nativeAdsEnabled && AdConfig.native.isNotEmpty;

  String get nativeAdUnitId => AdConfig.native;
  String get bannerAdUnitId => AdConfig.banner;

  // --------------------------------------------------------------------------
  // 1. INITIALIZATION (consent first, then SDK) — call without awaiting.
  // --------------------------------------------------------------------------
  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _sessionCount = (prefs.getInt(_kSessionCount) ?? 0) + 1;
      await prefs.setInt(_kSessionCount, _sessionCount);

      final allowed = await AdConsentService.instance.gatherConsent();
      if (!allowed) {
        debugPrint('ℹ️ [AdMob]: consent not obtained yet — ads paused.');
        return;
      }
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
      );
      _sdkReady = true;
      sdkReadyNotifier.value = true;
      AdConfig.logHealth();

      _loadRewardedAd();
      if (canServeAds) {
        _loadInterstitialAd();
        _loadAppOpenAd();
      }
      await _appStateSub?.cancel();
      await AppStateEventNotifier.startListening();
      _appStateSub = AppStateEventNotifier.appStateStream.listen((state) {
        if (state == AppState.foreground) maybeShowAppOpenAd();
      });
      debugPrint('✅ [AdMob]: ready (session $_sessionCount).');
    } catch (e) {
      debugPrint('⚠️ [AdMob]: initialization failed (offline?): $e');
    }
  }

  /// Re-run after the user changes privacy choices in Settings.
  Future<void> reinitializeAfterConsentChange() async {
    if (_sdkReady || !AdConsentService.instance.canRequestAds) return;
    try {
      await MobileAds.instance.initialize();
      _sdkReady = true;
      sdkReadyNotifier.value = true;
      _loadRewardedAd();
    } catch (e) {
      debugPrint('⚠️ [AdMob]: re-init failed: $e');
    }
  }

  bool get _fullScreenSpacingOk {
    final last = _lastFullScreenAt;
    return last == null || DateTime.now().difference(last).inSeconds >= 60;
  }

  // --------------------------------------------------------------------------
  // 2. REWARDED (value exchange, server-verified)
  // --------------------------------------------------------------------------
  void _loadRewardedAd() {
    final unit = AdConfig.rewarded;
    if (!_sdkReady || unit.isEmpty || _rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          _rewardedAd = ad;
          _rewardedAttempts = 0;
          isRewardedAdReady.value = true;
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          _rewardedAd = null;
          isRewardedAdReady.value = false;
          _rewardedAttempts += 1;
          // Exponential backoff: 4s, 8s, 16s … capped at ~2 min. Never gives up
          // permanently (old code stopped after 3 tries until app restart).
          final seconds = min(120, 2 << min(_rewardedAttempts, 6));
          Future.delayed(Duration(seconds: seconds), _loadRewardedAd);
        },
      ),
    );
  }

  /// Generates a nonce that ties the client claim and AdMob's SSV callback
  /// to one ad view (prevents double-crediting and replay).
  String newRewardNonce() {
    final r = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Shows a rewarded ad. [onEarnedReward] receives the nonce to claim with.
  /// [onAdShowed] fires when the ad is actually on screen (use it to cancel
  /// any "ad failed" timeout — the old timeout fired *while the ad was
  /// playing* and users lost the reward they had watched).
  void showRewardedAd({
    required VoidCallback onEarnedReward,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailed,
    VoidCallback? onAdShowed,
    void Function(String nonce)? onEarnedRewardWithNonce,
  }) {
    final ad = _rewardedAd;
    if (ad == null || _isShowingFullScreen) {
      onAdFailed?.call();
      onAdClosed();
      _loadRewardedAd();
      return;
    }
    _rewardedAd = null;
    isRewardedAdReady.value = false;
    final nonce = newRewardNonce();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      ad.setServerSideOptions(ServerSideVerificationOptions(userId: uid, customData: nonce));
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _isShowingFullScreen = true;
        onAdShowed?.call();
      },
      onAdDismissedFullScreenContent: (a) {
        _isShowingFullScreen = false;
        _lastFullScreenAt = DateTime.now();
        a.dispose();
        _loadRewardedAd();
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        _isShowingFullScreen = false;
        a.dispose();
        _loadRewardedAd();
        onAdFailed?.call();
        onAdClosed();
      },
    );
    ad.setImmersiveMode(true);
    ad.show(onUserEarnedReward: (_, _) {
      onEarnedRewardWithNonce?.call(nonce);
      onEarnedReward();
    });
  }

  // --------------------------------------------------------------------------
  // 3. INTERSTITIAL (natural breaks only, capped)
  // --------------------------------------------------------------------------
  void _loadInterstitialAd() {
    final unit = AdConfig.interstitial;
    if (!_sdkReady || unit.isEmpty || _interstitialLoading || _interstitialAd != null) return;
    if (!RemoteConfigService().interstitialEnabled) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          _interstitialAd = ad;
          _interstitialAttempts = 0;
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          _interstitialAd = null;
          _interstitialAttempts += 1;
          final seconds = min(300, 4 << min(_interstitialAttempts, 6));
          Future.delayed(Duration(seconds: seconds), _loadInterstitialAd);
        },
      ),
    );
  }

  /// Call at the END of a completed flow (journal saved, insight viewed,
  /// breathing finished, leaving calendar). Silently no-ops when not allowed.
  Future<void> showInterstitialAdIfAppropriate({String placement = 'break'}) async {
    try {
      final rc = RemoteConfigService();
      if (!canServeAds || !rc.interstitialEnabled || _isShowingFullScreen) return;
      if (_sessionCount < rc.interstitialMinSession || !_fullScreenSpacingOk) return;

      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final count = prefs.getString(_kInterstitialDay) == today ? (prefs.getInt(_kInterstitialCount) ?? 0) : 0;
      final lastMs = prefs.getInt(_kLastInterstitial) ?? 0;
      final sinceLast = DateTime.now().millisecondsSinceEpoch - lastMs;
      if (count >= rc.interstitialDailyCap) return;
      if (sinceLast < rc.interstitialCooldownSeconds * 1000) return;

      final ad = _interstitialAd;
      if (ad == null) {
        _loadInterstitialAd();
        return;
      }
      _interstitialAd = null;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) => _isShowingFullScreen = true,
        onAdDismissedFullScreenContent: (a) {
          _isShowingFullScreen = false;
          _lastFullScreenAt = DateTime.now();
          a.dispose();
          _loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (a, e) {
          _isShowingFullScreen = false;
          a.dispose();
          _loadInterstitialAd();
        },
      );
      await prefs.setString(_kInterstitialDay, today);
      await prefs.setInt(_kInterstitialCount, count + 1);
      await prefs.setInt(_kLastInterstitial, DateTime.now().millisecondsSinceEpoch);
      debugPrint('📺 [AdMob]: interstitial @ $placement (${count + 1} today)');
      await ad.show();
    } catch (e) {
      debugPrint('⚠️ [AdMob]: interstitial skipped: $e');
    }
  }

  // --------------------------------------------------------------------------
  // 4. APP OPEN (returning users only)
  // --------------------------------------------------------------------------
  bool get _appOpenFresh {
    final at = _appOpenLoadedAt;
    return at != null && DateTime.now().difference(at).inHours < 4;
  }

  void _loadAppOpenAd() {
    final unit = AdConfig.appOpen;
    final rc = RemoteConfigService();
    if (!_sdkReady || unit.isEmpty || _appOpenLoading || !rc.appOpenEnabled) return;
    if (_appOpenAd != null && _appOpenFresh) return;
    _appOpenLoading = true;
    AppOpenAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenLoading = false;
          _appOpenAd?.dispose();
          _appOpenAd = ad;
          _appOpenLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          _appOpenLoading = false;
          _appOpenAd = null;
        },
      ),
    );
  }

  /// Shown when a returning user brings the app to the foreground.
  Future<void> maybeShowAppOpenAd() async {
    try {
      final rc = RemoteConfigService();
      if (!canServeAds || !rc.appOpenEnabled || _isShowingFullScreen) return;
      if (_sessionCount < rc.appOpenMinSession || !_fullScreenSpacingOk) return;
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_kLastAppOpen) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - last < rc.appOpenCooldownMinutes * 60000) return;

      final ad = _appOpenAd;
      if (ad == null || !_appOpenFresh) {
        _loadAppOpenAd();
        return;
      }
      _appOpenAd = null;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) => _isShowingFullScreen = true,
        onAdDismissedFullScreenContent: (a) {
          _isShowingFullScreen = false;
          _lastFullScreenAt = DateTime.now();
          a.dispose();
          _loadAppOpenAd();
        },
        onAdFailedToShowFullScreenContent: (a, e) {
          _isShowingFullScreen = false;
          a.dispose();
          _loadAppOpenAd();
        },
      );
      await prefs.setInt(_kLastAppOpen, DateTime.now().millisecondsSinceEpoch);
      await ad.show();
    } catch (e) {
      debugPrint('⚠️ [AdMob]: app-open skipped: $e');
    }
  }

  /// Frees full-screen ads (e.g. right after a purchase makes the user premium).
  void disposeFullScreenAds() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
}
// cSpell:enable
