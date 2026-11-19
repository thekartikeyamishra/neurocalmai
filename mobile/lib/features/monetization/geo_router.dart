import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/iap_service.dart';
import '../../core/utils/region_detector.dart';

enum MonetizationType { adSupported, subscription }

class UserAccessState {
  final MonetizationType type;
  final bool hasPremiumAccess;
  final String countryCode;

  UserAccessState({
    required this.type,
    this.hasPremiumAccess = false,
    this.countryCode = 'US',
  });
}

/// FIX: this was a hard-coded mock ('IN') with an artificial 800 ms delay,
/// and it routed every non-Indian user to "subscription", which hid ads from
/// the highest-paying markets (US/UK/EU) while they never subscribed either.
/// Now: every non-premium user is ad-supported (free tier) in every region;
/// pricing/paywall localisation is handled by the store + RegionDetector.
class GeoRoutingService {
  Future<UserAccessState> determineRouting() async {
    final premium = IAPService().isPremium;
    return UserAccessState(
      type: premium ? MonetizationType.subscription : MonetizationType.adSupported,
      hasPremiumAccess: premium,
      countryCode: RegionDetector.deviceCountryCode,
    );
  }
}

final geoRouterProvider = FutureProvider<UserAccessState>((ref) async {
  return GeoRoutingService().determineRouting();
});
