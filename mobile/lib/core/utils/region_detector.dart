import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// A lightweight, synchronous utility class to determine the device's region.
/// This acts as the routing logic for our dual-track monetization strategy,
/// ensuring users in India see the Wallet/Sachet UI while International users 
/// see the Subscription Hard Paywall.
class RegionDetector {
  
  /// Determines if the user's primary device region is set to India.
  /// 
  /// Note: This reads the OS-level locale settings. While users can spoof this 
  /// in their device settings, it serves as an excellent, zero-latency heuristic 
  /// to route the initial UI flow. Actual currency validation happens securely 
  /// on the backend via RevenueCat and the App Stores.
  static bool get isUserInIndia {
    try {
      // PlatformDispatcher is the modern, web-safe approach in Flutter 3.0+
      // replacing the older window.locale method.
      final String? countryCode = ui.PlatformDispatcher.instance.locale.countryCode;
      
      if (countryCode != null && countryCode.toUpperCase() == 'IN') {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("🚨 [RegionDetector Error]: $e");
      // Fail-safe: Default to the international subscription model if detection fails
      return false;
    }
  }

  /// Retrieves the raw 2-letter ISO country code of the device (e.g., 'US', 'IN', 'GB').
  /// Useful for analytics, ASO routing, or passing precise regions to backend API calls.
  static String get deviceCountryCode {
    try {
       final String? countryCode = ui.PlatformDispatcher.instance.locale.countryCode;
       return countryCode?.toUpperCase() ?? 'US'; // Default to US if unavailable
    } catch (e) {
       debugPrint("🚨 [Country Code Fetch Error]: $e");
       return 'US';
    }
  }

  /// Convenience method to retrieve the primary language code (e.g., 'en', 'hi').
  /// Can be used to dynamically set the default TTS or UI dialect on first boot.
  static String get deviceLanguageCode {
    try {
      final String languageCode = ui.PlatformDispatcher.instance.locale.languageCode;
      return languageCode.toLowerCase();
    } catch (e) {
      debugPrint("🚨 [Language Code Fetch Error]: $e");
      return 'en'; // Default to English
    }
  }
}