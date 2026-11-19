import 'package:flutter/foundation.dart';

import '../../features/monetization/services/admob_service.dart';

/// Backwards-compatible facade. The old class initialised a second copy of
/// the Ads SDK and granted rewards without any server check. It now delegates
/// to [AdMobService] (single SDK owner). Used where the ad itself unlocks one
/// use of a tool (no credits are granted, so there is no double reward).
class AdMobRewardService {
  static final AdMobRewardService _instance = AdMobRewardService._internal();
  factory AdMobRewardService() => _instance;
  AdMobRewardService._internal();

  bool get isAdAvailable => AdMobService.instance.isRewardedAdReady.value;

  Future<void> init() async {}

  /// Shows a rewarded ad; [onRewardEarned] fires once the reward is earned.
  void showAd({
    required VoidCallback onRewardEarned,
    required VoidCallback onAdFailed,
  }) {
    AdMobService.instance.showRewardedAd(
      onEarnedReward: onRewardEarned,
      onAdClosed: () {},
      onAdFailed: () {
        debugPrint('ℹ️ [AdMobRewardService]: rewarded ad unavailable.');
        onAdFailed();
      },
    );
  }

  void dispose() {}
}
