import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// A production-ready service to safely handle location data.
/// Extracts the user's current location and truncates the latitude 
/// and longitude to severely limit precision (approx 10km radius), 
/// guaranteeing that exact coordinates are never transmitted to the backend.
class LocationPrivacyService {
  // Singleton instance
  static final LocationPrivacyService instance = LocationPrivacyService._internal();
  LocationPrivacyService._internal();

  /// Requests the user's location, ensuring all permissions are granted,
  /// and returns a privacy-safe truncated location map.
  Future<Map<String, double>?> getCoarseLocation() async {
    try {
      // 1. Check if location services are enabled at the OS level
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled on this device.');
      }

      // 2. Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions were denied by the user.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied. Please enable them in system settings to join a Grounding Circle.',
        );
      }

      // 3. Fetch the current position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Truncate coordinates to 1 decimal place.
      // 1 decimal place of latitude/longitude equates to roughly ~11.1 kilometers.
      // This effectively anonymizes the user's location before it reaches Firestore.
      final double safeLat = double.parse(position.latitude.toStringAsFixed(1));
      final double safeLng = double.parse(position.longitude.toStringAsFixed(1));

      debugPrint('✅ [LocationPrivacy]: Raw coordinates truncated. Safe Hub Location: $safeLat, $safeLng');

      return {
        'latitude': safeLat,
        'longitude': safeLng,
      };
    } catch (e) {
      debugPrint('🚨 [LocationPrivacy Error]: Failed to acquire coarse location: $e');
      return null;
    }
  }
}