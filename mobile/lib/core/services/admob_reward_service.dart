import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/monetization_constants.dart';

/// A production-ready singleton service managing Google AdMob Rewarded Ads.
/// Handles pre-loading, displaying, error fallbacks, and memory management.
/// Used primarily as a "Freemium Fallback" for users who cannot afford micro-transactions.
class AdMobRewardService {
  // Singleton instance
  static final AdMobRewardService _instance = AdMobRewardService._internal();
  factory AdMobRewardService() => _instance;
  AdMobRewardService._internal();

  RewardedAd? _rewardedAd;
  int _numAdLoadAttempts = 0;
  final int _maxFailedLoadAttempts = 3;

  /// Returns true if a rewarded ad is currently cached and ready to show.
  bool get isAdAvailable => _rewardedAd != null;

  /// Retrieves the correct Ad Unit ID based on the operating system.
  String get _adUnitId {
    if (kIsWeb) {
      return ''; // AdMob plugin does not natively support Flutter Web in this context
    }
    if (Platform.isAndroid) {
      return MonetizationConstants.rewardedAdUnitIdAndroid;
    } else if (Platform.isIOS) {
      return MonetizationConstants.rewardedAdUnitIdIOS;
    } else {
      throw UnsupportedError('Unsupported platform for AdMob');
    }
  }

  /// Initializes the Google Mobile Ads SDK.
  /// Call this during app startup in `main.dart` after Firebase initialization.
  Future<void> init() async {
    if (kIsWeb) {
      debugPrint("AdMob is not supported on Web. Bypassing initialization.");
      return;
    }
    
    try {
      await MobileAds.instance.initialize();
      // Pre-load the first ad so it is instantly ready when the user needs it
      _loadAd();
    } catch (e) {
      debugPrint("🚨 AdMob Initialization Error: $e");
    }
  }

  /// Pre-loads a rewarded ad into memory.
  void _loadAd() {
    if (kIsWeb || _adUnitId.isEmpty) return;

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('✅ Rewarded ad loaded successfully.');
          _rewardedAd = ad;
          _numAdLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('🚨 Rewarded ad failed to load: $error');
          _rewardedAd = null;
          _numAdLoadAttempts += 1;
          
          // Exponential backoff or retry limit for failed ad loads
          if (_numAdLoadAttempts < _maxFailedLoadAttempts) {
            _loadAd();
          }
        },
      ),
    );
  }

  /// Displays the pre-loaded rewarded ad.
  /// [onRewardEarned] triggers when the user finishes watching the ad.
  /// [onAdFailed] triggers if the ad fails to show or is unavailable (graceful fallback).
  void showAd({
    required VoidCallback onRewardEarned,
    required VoidCallback onAdFailed,
  }) {
    if (kIsWeb) {
      debugPrint("AdMob not supported on Web. Bypassing and granting reward gracefully.");
      onRewardEarned();
      return;
    }

    if (_rewardedAd == null) {
      debugPrint('🚨 Warning: Tried to show reward ad before it was loaded.');
      // Attempt to load one for next time, but fail gracefully now
      _loadAd();
      onAdFailed();
      return;
    }

    // Set full screen content callbacks to handle ad lifecycle events
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        debugPrint('Ad showed fullscreen content.');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        debugPrint('Ad dismissed fullscreen content.');
        ad.dispose();
        _rewardedAd = null;
        // Immediately load the next ad so it's ready for future use
        _loadAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        debugPrint('🚨 Ad failed to show fullscreen content: $error');
        ad.dispose();
        _rewardedAd = null;
        _loadAd();
        onAdFailed();
      },
      onAdImpression: (RewardedAd ad) => debugPrint('Ad impression recorded.'),
    );

    // Show the ad
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint('🎁 User earned reward: ${reward.amount} ${reward.type}');
        onRewardEarned();
      },
    );
  }

  /// Cleans up resources when the service is destroyed.
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}