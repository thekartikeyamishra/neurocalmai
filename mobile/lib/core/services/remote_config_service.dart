import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// 🚨 ARCHITECTURE UPGRADE: Resilient Cloud Configuration
/// Acts as the central nervous system for cloud-controlled variables. 
/// Allows for real-time swapping of AI endpoints and monetization thresholds 
/// without needing Play Store/App Store updates.
class RemoteConfigService {
  // Singleton Pattern
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  /// Initializes the service. 
  /// Must be called in `main.dart` after `Firebase.initializeApp()`.
  Future<void> init() async {
    try {
      // 1. Establish hardcoded baseline defaults.
      // If the device is entirely offline during its first ever launch, 
      // these values guarantee the app still boots and functions gracefully.
      await _remoteConfig.setDefaults(const {
        'primary_ai_model': 'gemini-1.5-flash',
        'fallback_ai_model': 'gemini-1.5-pro',
        'ad_grace_period_sessions': 3,
        'rewarded_ad_credit_payout': 50,
      });

      // 2. Configure fetching thresholds.
      // In debug mode, we fetch frequently (5 mins) to test variables.
      // In production, we fetch every 6 hours to conserve user battery and API quotas.
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode 
            ? const Duration(minutes: 5) 
            : const Duration(hours: 6),
      ));

      // 3. Request the latest values from Firebase and apply them instantly
      await _remoteConfig.fetchAndActivate();
      
      // 4. Listen for real-time background pushes from the Firebase Console.
      // If you deprecate an AI model mid-session, the app will hot-swap it securely.
      _remoteConfig.onConfigUpdated.listen((event) async {
        await _remoteConfig.activate();
        debugPrint('☁️ [RemoteConfig]: Live updates intercepted and applied.');
      });

      debugPrint('✅ [RemoteConfig]: Initialized and synced.');
    } catch (e) {
      debugPrint('🚨 [RemoteConfig Error]: Sync failed. Running on local defaults. Error: $e');
    }
  }

  // =========================================================================
  // SECURE GETTERS
  // =========================================================================

  /// Retrieves the current primary generative AI model (e.g., 'gemini-1.5-flash').
  String get primaryAiModel => _remoteConfig.getString('primary_ai_model');

  /// Retrieves the heavier fallback model if the primary is offline/rate-limited.
  String get fallbackAiModel => _remoteConfig.getString('fallback_ai_model');

  /// The number of completed sessions required before ads are introduced.
  int get adGracePeriodSessions => _remoteConfig.getInt('ad_grace_period_sessions');

  /// The amount of wallet credits granted to the user when they watch a sponsor ad.
  int get rewardedAdCreditPayout => _remoteConfig.getInt('rewarded_ad_credit_payout');
}