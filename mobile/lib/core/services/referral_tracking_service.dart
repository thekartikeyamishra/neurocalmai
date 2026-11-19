import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// A production-ready service for tracking and attributing organic downloads.
/// Securely extracts Play Store install referrers and syncs UTM parameters 
/// to RevenueCat, ensuring B2B2C affiliates (like yoga studios) and retargeting 
/// campaigns are perfectly credited without exposing custom API keys.
class ReferralTrackingService {
  // Singleton instance
  static final ReferralTrackingService instance = ReferralTrackingService._internal();
  ReferralTrackingService._internal();

  bool _hasProcessedReferral = false;

  /// Retrieves the install referrer broadcasted by Google Play upon installation.
  /// Safely parses the data and syncs it to RevenueCat to attribute future purchases
  /// directly to the referring source (e.g., a specific yoga studio promo link).
  Future<void> captureAndSyncReferral() async {
    // The Play Install Referrer API is Android-exclusive.
    // iOS attribution is handled separately via SKAdNetwork / Apple Search Ads.
    if (_hasProcessedReferral || !Platform.isAndroid) return;

    try {
      // Utilizing type inference to handle the plugin's internal data model safely
      final referrer = await PlayInstallReferrer.installReferrer;
      
      // Safely handle the nullable return type with a fallback to an empty string
      final String rawReferrer = referrer.installReferrer ?? '';
      
      // Ignore empty referrers or standard Google Play organic searches
      if (rawReferrer.isEmpty || rawReferrer == 'utm_source=google-play&utm_medium=organic') {
        _hasProcessedReferral = true;
        return; 
      }

      // Parse the raw UTM string into a map
      final Map<String, String> parsedAttributes = _parseUtmParameters(rawReferrer);

      if (parsedAttributes.isNotEmpty) {
        // Sync the raw attributes to RevenueCat for general reporting
        await Purchases.setAttributes(parsedAttributes);
        
        // Map standard UTM parameters to RevenueCat's native marketing attribution fields
        if (parsedAttributes.containsKey('utm_campaign')) {
          await Purchases.setCampaign(parsedAttributes['utm_campaign']!);
        }
        if (parsedAttributes.containsKey('utm_medium')) {
          await Purchases.setMediaSource(parsedAttributes['utm_medium']!);
        }
        if (parsedAttributes.containsKey('utm_source')) {
          // You can map 'utm_source' to a custom subscriber attribute to track specific studio affiliates
          await Purchases.setAttributes({'affiliate_studio_id': parsedAttributes['utm_source']!});
        }

        debugPrint('✅ [ReferralTracking]: Synced referral attributes: $parsedAttributes');
      }

      _hasProcessedReferral = true;

    } on PlatformException catch (e) {
      // Handles scenarios where the Play Store is not installed or the API is unavailable
      debugPrint('🚨 [ReferralTracking Error]: Play Install Referrer API failed: ${e.message}');
    } catch (e) {
      debugPrint('🚨 [ReferralTracking Error]: Unexpected error processing referral: $e');
    }
  }

  /// Decodes and splits the URL-encoded referral string into key-value pairs.
  /// Example input: "utm_source=studio_om&utm_medium=affiliate&utm_campaign=summer_promo"
  Map<String, String> _parseUtmParameters(String referrerString) {
    final Map<String, String> attributes = {};
    try {
      final String decodedString = Uri.decodeComponent(referrerString);
      final List<String> parts = decodedString.split('&');
      
      for (final part in parts) {
        final List<String> keyValue = part.split('=');
        if (keyValue.length == 2) {
          final String key = keyValue[0].trim();
          final String value = keyValue[1].trim();
          attributes[key] = value;
        }
      }
    } catch (e) {
      debugPrint('🚨 [ReferralTracking Error]: Failed to parse UTM string: $e');
    }
    return attributes;
  }
}