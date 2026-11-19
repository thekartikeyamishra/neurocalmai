// cSpell:disable
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Single source of truth for AdMob ad unit IDs.
///
/// WHY THIS EXISTS (root cause of near-zero ad revenue):
/// the old code fell back to Google's *test* ad units in release builds
/// whenever a key was missing from `.env`. Test ads never pay. Banner even
/// fell back to an empty string, so it never loaded at all.
///
/// Resolution order (release builds):
///   1. `--dart-define=ADMOB_<FORMAT>_ANDROID=ca-app-pub-...` (recommended)
///   2. `.env` asset key with the same name
///   3. Known production unit compiled in below (rewarded only today)
///   4. Empty => that format is disabled and a warning is logged.
/// Debug builds always use Google's official test units (policy-safe).
class AdConfig {
  AdConfig._();

  static const String publisherAppIdAndroid =
      'ca-app-pub-4557897331416844~7304425581';

  // Production units already created in AdMob for this app.
  static const String _prodRewardedAndroid =
      'ca-app-pub-4557897331416844/2435930645';
  static const String _prodRewardedIos =
      'ca-app-pub-4557897331416844/8198200276';

  // Compile-time overrides (flutter build appbundle --dart-define=...).
  static const String _defBannerAndroid =
      String.fromEnvironment('ADMOB_BANNER_ANDROID');
  static const String _defInterstitialAndroid =
      String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID');
  static const String _defRewardedAndroid =
      String.fromEnvironment('ADMOB_REWARDED_ANDROID');
  static const String _defNativeAndroid =
      String.fromEnvironment('ADMOB_NATIVE_ANDROID');
  static const String _defAppOpenAndroid =
      String.fromEnvironment('ADMOB_APP_OPEN_ANDROID');

  static const String _defBannerIos = String.fromEnvironment('ADMOB_BANNER_IOS');
  static const String _defInterstitialIos = String.fromEnvironment('ADMOB_INTERSTITIAL_IOS');
  static const String _defRewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS');
  static const String _defNativeIos = String.fromEnvironment('ADMOB_NATIVE_IOS');
  static const String _defAppOpenIos = String.fromEnvironment('ADMOB_APP_OPEN_IOS');

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static String _fromEnvFile(String key) {
    try {
      final value = dotenv.env[key];
      if (value != null && value.trim().startsWith('ca-app-pub-')) {
        return value.trim();
      }
    } catch (_) {
      // dotenv not loaded (asset missing) – fall through.
    }
    return '';
  }

  static String _resolve({
    required String format,
    required String compileTime,
    String compileTimeIos = '',
    required String testAndroid,
    required String testIos,
    String prodAndroid = '',
    String prodIos = '',
  }) {
    if (kDebugMode) return _isAndroid ? testAndroid : testIos;
    if (_isAndroid && compileTime.startsWith('ca-app-pub-')) return compileTime;
    if (!_isAndroid && compileTimeIos.startsWith('ca-app-pub-')) return compileTimeIos;
    final envKey = 'ADMOB_${format}_${_isAndroid ? 'ANDROID' : 'IOS'}';
    final fromEnv = _fromEnvFile(envKey);
    if (fromEnv.isNotEmpty) return fromEnv;
    final prod = _isAndroid ? prodAndroid : prodIos;
    if (prod.isNotEmpty) return prod;
    debugPrint('⚠️ [AdConfig]: $envKey missing — $format ads disabled.');
    return '';
  }

  static String get banner => _resolve(
        format: 'BANNER',
        compileTime: _defBannerAndroid,
        compileTimeIos: _defBannerIos,
        testAndroid: 'ca-app-pub-3940256099942544/9214589741',
        testIos: 'ca-app-pub-3940256099942544/2435281174',
      );

  static String get interstitial => _resolve(
        format: 'INTERSTITIAL',
        compileTime: _defInterstitialAndroid,
        compileTimeIos: _defInterstitialIos,
        testAndroid: 'ca-app-pub-3940256099942544/1033173712',
        testIos: 'ca-app-pub-3940256099942544/4411468910',
      );

  static String get rewarded => _resolve(
        format: 'REWARDED',
        compileTime: _defRewardedAndroid,
        compileTimeIos: _defRewardedIos,
        testAndroid: 'ca-app-pub-3940256099942544/5224354917',
        testIos: 'ca-app-pub-3940256099942544/1712485313',
        prodAndroid: _prodRewardedAndroid,
        prodIos: _prodRewardedIos,
      );

  static String get native => _resolve(
        format: 'NATIVE',
        compileTime: _defNativeAndroid,
        compileTimeIos: _defNativeIos,
        testAndroid: 'ca-app-pub-3940256099942544/2247696110',
        testIos: 'ca-app-pub-3940256099942544/3986624511',
      );

  static String get appOpen => _resolve(
        format: 'APP_OPEN',
        compileTime: _defAppOpenAndroid,
        compileTimeIos: _defAppOpenIos,
        testAndroid: 'ca-app-pub-3940256099942544/9257395921',
        testIos: 'ca-app-pub-3940256099942544/5575463023',
      );

  /// Logs which formats are live. Call once after dotenv loads.
  static void logHealth() {
    debugPrint('📊 [AdConfig] banner=${banner.isNotEmpty} '
        'interstitial=${interstitial.isNotEmpty} rewarded=${rewarded.isNotEmpty} '
        'native=${native.isNotEmpty} appOpen=${appOpen.isNotEmpty}');
  }
}
// cSpell:enable
