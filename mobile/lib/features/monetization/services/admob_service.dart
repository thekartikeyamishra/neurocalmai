// cSpell:disable
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Production-ready monetization service managing AdMob Rewarded and Interstitial ad lifecycles[cite: 12].
/// Implements value-exchange rewarded ads to prevent user churn while protecting ad revenue.
class AdMobService {
  // Singleton Pattern
  static final AdMobService instance = AdMobService._internal();
  AdMobService._internal();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  /// Reactive notifier allowing UI widgets to observe whether a rewarded ad is cached
  final ValueNotifier<bool> isRewardedAdReady = ValueNotifier<bool>(false);

  // Cooldown tracker to prevent ad-spam and eliminate user churn[cite: 12]
  DateTime? _lastInterstitialTime;
  final int _interstitialCooldownMinutes = 30;

  int _numRewardedLoadAttempts = 0;
  int _numInterstitialLoadAttempts = 0;
  final int maxFailedLoadAttempts = 3;

  /// --------------------------------------------------------
  /// 1. INITIALIZATION[cite: 12]
  /// --------------------------------------------------------
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      // Pre-cache ads immediately so they are available without latency on demand[cite: 12]
      _loadRewardedAd();
      _loadInterstitialAd();
      debugPrint(
        '✅ [AdMob Service]: Initialized and background caching active.',
      );
    } catch (e) {
      debugPrint(
        '⚠️ [AdMob Error]: Initialization failed. Device is likely offline: $e',
      );
    }
  }

  /// --------------------------------------------------------
  /// 2. AD UNIT ID RESOLUTION WITH PRODUCTION FAILSAFES[cite: 12]
  /// --------------------------------------------------------
  String get _rewardedAdUnitId {
    if (!kDebugMode) {
      final key = Platform.isAndroid
          ? dotenv.env['ADMOB_REWARDED_ANDROID']
          : dotenv.env['ADMOB_REWARDED_IOS'];
      if (key != null && key.isNotEmpty) return key.trim();
    }
    // Official Google AdMob Test Rewarded Ad Unit IDs[cite: 12]
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/5224354917'
        : 'ca-app-pub-3940256099942544/1712485313';
  }

  String get _interstitialAdUnitId {
    if (!kDebugMode) {
      final key = Platform.isAndroid
          ? dotenv.env['ADMOB_INTERSTITIAL_ANDROID']
          : dotenv.env['ADMOB_INTERSTITIAL_IOS'];
      if (key != null && key.isNotEmpty) return key.trim();
    }
    // Official Google AdMob Test Interstitial Ad Unit IDs[cite: 12]
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712'
        : 'ca-app-pub-3940256099942544/4411468910';
  }

  /// Native Advanced Ad Unit ID getter for widget consumption[cite: 12]
  String get nativeAdUnitId {
    if (!kDebugMode) {
      final key = Platform.isAndroid
          ? dotenv.env['ADMOB_NATIVE_ANDROID']
          : dotenv.env['ADMOB_NATIVE_IOS'];
      if (key != null && key.isNotEmpty) return key.trim();
    }
    // Official Google AdMob Test Native Ad Unit IDs[cite: 12]
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/2247696110'
        : 'ca-app-pub-3940256099942544/3986624511';
  }

  /// --------------------------------------------------------
  /// 3. REWARDED AD PIPELINE (VALUE-EXCHANGE REWARDS)[cite: 12]
  /// --------------------------------------------------------
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ [AdMob]: Rewarded Ad cached and ready.');
          _rewardedAd = ad;
          _numRewardedLoadAttempts = 0;
          isRewardedAdReady.value = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('⚠️ [AdMob]: Rewarded Ad failed to load: $error');
          _rewardedAd = null;
          isRewardedAdReady.value = false;
          _numRewardedLoadAttempts += 1;

          // Exponential backoff to avoid request hammering
          if (_numRewardedLoadAttempts < maxFailedLoadAttempts) {
            final delay = Duration(seconds: _numRewardedLoadAttempts * 3);
            Future.delayed(delay, _loadRewardedAd);
          }
        },
      ),
    );
  }

  /// Displays the rewarded ad to grant wallet credits or session access[cite: 12]
  void showRewardedAd({
    required VoidCallback onEarnedReward,
    required VoidCallback onAdClosed,
    VoidCallback? onAdFailed,
  }) {
    if (_rewardedAd == null) {
      debugPrint('⚠️ [AdMob]: Rewarded ad requested but not currently loaded.');
      onAdFailed?.call();
      onAdClosed();
      _loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('✅ [AdMob]: Rewarded ad presented full screen.');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('✅ [AdMob]: Rewarded ad dismissed by user.');
        ad.dispose();
        _rewardedAd = null;
        isRewardedAdReady.value = false;
        _loadRewardedAd(); // Immediately pre-cache subsequent ad[cite: 12]
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('⚠️ [AdMob]: Rewarded ad failed to display: $error');
        ad.dispose();
        _rewardedAd = null;
        isRewardedAdReady.value = false;
        _loadRewardedAd();
        onAdFailed?.call();
        onAdClosed();
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint(
          '🎉 [AdMob]: Reward granted: ${reward.amount} ${reward.type}',
        );
        onEarnedReward();
      },
    );
  }

  /// --------------------------------------------------------
  /// 4. INTERSTITIAL AD PIPELINE (CHURN-PROTECTED COOLDOWN)[cite: 12]
  /// --------------------------------------------------------
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ [AdMob]: Interstitial Ad cached.');
          _interstitialAd = ad;
          _numInterstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (error) {
          debugPrint('⚠️ [AdMob]: Interstitial Ad failed to load: $error');
          _interstitialAd = null;
          _numInterstitialLoadAttempts += 1;

          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            final delay = Duration(seconds: _numInterstitialLoadAttempts * 3);
            Future.delayed(delay, _loadInterstitialAd);
          }
        },
      ),
    );
  }

  /// Displays an interstitial only when the 30-minute cooldown window has elapsed[cite: 12]
  void showInterstitialAdIfAppropriate() {
    if (_interstitialAd == null) {
      _loadInterstitialAd();
      return;
    }

    if (_lastInterstitialTime != null) {
      final difference = DateTime.now().difference(_lastInterstitialTime!);
      if (difference.inMinutes < _interstitialCooldownMinutes) {
        debugPrint(
          '⏳ [AdMob]: Interstitial throttled by retention cooldown (${difference.inMinutes}m elapsed)[cite: 12].',
        );
        return;
      }
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) =>
          debugPrint('✅ [AdMob]: Interstitial displayed[cite: 12].'),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _lastInterstitialTime =
            DateTime.now(); // Reset cooldown timer[cite: 12]
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('⚠️ [AdMob]: Interstitial failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
    );

    _interstitialAd!.show();
  }
}
// cSpell:enable