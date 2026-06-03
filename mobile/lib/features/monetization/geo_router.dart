import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MonetizationType { adSupported, subscription }

// A structured model holding the user's specific access rights
class UserAccessState {
  final MonetizationType type;
  final bool hasPremiumAccess;

  UserAccessState({required this.type, this.hasPremiumAccess = false});
}

// Mocking the Geo-IP service check for development. 
// In production, this data comes from your Node.js backend JWT token.
class GeoRoutingService {
  Future<UserAccessState> determineRouting() async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate API latency
    
    // Simulating an Indian Locale detection for local testing
    const detectedCountryCode = 'IN'; 

    if (detectedCountryCode == 'IN') {
      return UserAccessState(type: MonetizationType.adSupported);
    } else {
      return UserAccessState(type: MonetizationType.subscription);
    }
  }
}

// Riverpod Provider to be consumed by the UI
final geoRouterProvider = FutureProvider<UserAccessState>((ref) async {
  final service = GeoRoutingService();
  return await service.determineRouting();
});