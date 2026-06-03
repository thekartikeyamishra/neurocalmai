import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdMobService {
  // Singleton Pattern
  static final AdMobService instance = AdMobService._internal();
  AdMobService._internal();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  
  // Cooldown tracker to prevent ad-spam and reduce user churn
  DateTime? _lastInterstitialTime;
  final int _interstitialCooldownMinutes = 30;

  int _numRewardedLoadAttempts = 0;
  int _numInterstitialLoadAttempts = 0;
  final int maxFailedLoadAttempts = 3;

  /// --------------------------------------------------------
  /// 1. INITIALIZATION
  /// --------------------------------------------------------
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      // Pre-cache ads so they are ready instantly when requested
      _loadRewardedAd();
      _loadInterstitialAd();
      debugPrint('✅ [AdMob Service]: Initialized and pre-caching started.');
    } catch (e) {
      debugPrint('⚠️ [AdMob Error]: Initialization failed. User likely offline. $e');
    }
  }

  /// --------------------------------------------------------
  /// 2. UNIT ID MANAGEMENT (Platform Specific + Safe Fallbacks)
  /// --------------------------------------------------------
  String get _rewardedAdUnitId {
    if (kDebugMode) {
      // Official Google Test IDs
      return Platform.isAndroid 
          ? 'ca-app-pub-3940256099942544/5224354917' 
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    return Platform.isAndroid 
        ? dotenv.env['ADMOB_REWARDED_ANDROID'] ?? '' 
        : dotenv.env['ADMOB_REWARDED_IOS'] ?? '';
  }

  String get _interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid 
          ? 'ca-app-pub-3940256099942544/1033173712' 
          : 'ca-app-pub-3940256099942544/4411468910';
    }
    return Platform.isAndroid 
        ? dotenv.env['ADMOB_INTERSTITIAL_ANDROID'] ?? '' 
        : dotenv.env['ADMOB_INTERSTITIAL_IOS'] ?? '';
  }

  /// Native Ad Unit ID getter for UI consumption
  String get nativeAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid 
          ? 'ca-app-pub-3940256099942544/2247696110' 
          : 'ca-app-pub-3940256099942544/3986624511';
    }
    return Platform.isAndroid 
        ? dotenv.env['ADMOB_NATIVE_ANDROID'] ?? '' 
        : dotenv.env['ADMOB_NATIVE_IOS'] ?? '';
  }

  /// --------------------------------------------------------
  /// 3. REWARDED AD PIPELINE (For unlocking Deep Insights)
  /// --------------------------------------------------------
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ [AdMob]: Rewarded Ad loaded.');
          _rewardedAd = ad;
          _numRewardedLoadAttempts = 0;
        },
        onAdFailedToLoad: (error) {
          debugPrint('⚠️ [AdMob]: Rewarded Ad failed to load: $error');
          _rewardedAd = null;
          _numRewardedLoadAttempts += 1;
          if (_numRewardedLoadAttempts < maxFailedLoadAttempts) {
            _loadRewardedAd();
          }
        },
      ),
    );
  }

  void showRewardedAd({required VoidCallback onEarnedReward, required VoidCallback onAdClosed}) {
    if (_rewardedAd == null) {
      debugPrint('⚠️ [AdMob]: Tried to show rewarded ad before it loaded.');
      // Execute closure to unblock UI if offline
      onAdClosed();
      _loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('✅ [AdMob]: Ad showed.'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('✅ [AdMob]: Ad dismissed.');
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd(); // Preload next ad
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('⚠️ [AdMob]: Ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        onAdClosed();
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      debugPrint('✅ [AdMob]: User earned reward: ${reward.amount} ${reward.type}');
      onEarnedReward();
    });
  }

  /// --------------------------------------------------------
  /// 4. INTERSTITIAL AD PIPELINE (For Screen Exits)
  /// --------------------------------------------------------
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ [AdMob]: Interstitial Ad loaded.');
          _interstitialAd = ad;
          _numInterstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (error) {
          debugPrint('⚠️ [AdMob]: Interstitial Ad failed to load: $error');
          _interstitialAd = null;
          _numInterstitialLoadAttempts += 1;
          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            _loadInterstitialAd();
          }
        },
      ),
    );
  }

  /// Shows an interstitial ONLY if the cooldown period has elapsed.
  void showInterstitialAdIfAppropriate() {
    if (_interstitialAd == null) {
      _loadInterstitialAd();
      return;
    }

    // 🚨 PSYCHOLOGICAL UX: Prevent ad-spamming
    if (_lastInterstitialTime != null) {
      final difference = DateTime.now().difference(_lastInterstitialTime!);
      if (difference.inMinutes < _interstitialCooldownMinutes) {
        debugPrint('⏳ [AdMob]: Interstitial blocked by cooldown (${difference.inMinutes}m passed)');
        return;
      }
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('✅ [AdMob]: Interstitial showed.'),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _lastInterstitialTime = DateTime.now(); // Reset cooldown timer
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
    );

    _interstitialAd!.show();
  }
}