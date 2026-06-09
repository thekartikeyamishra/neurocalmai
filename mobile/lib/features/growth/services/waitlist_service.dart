import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class WaitlistService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Constructor with optional dependency injection for easier unit testing
  WaitlistService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Submits user data to the offline community waitlist.
  /// Uses SetOptions(merge: true) to safely update existing records without wiping them.
  Future<void> joinOfflineWaitlist({
    required String city,
    required String pincode,
    required List<String> primaryNeeds,
    required bool willingToLead,
    required Map<String, dynamic> dynamicFormResponses,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Authentication error: User must be signed in to join the waitlist.');
    }

    final waitlistRef = _firestore.collection('offline_waitlist').doc(user.uid);

    try {
      await waitlistRef.set({
        'userId': user.uid,
        'email': user.email ?? 'unknown@noemail.com',
        // Normalize city string for accurate querying and counting later
        'city': city.trim().toLowerCase(),
        'pincode': pincode.trim(),
        'primaryNeeds': primaryNeeds,
        'willingToLead': willingToLead,
        'dynamicResponses': dynamicFormResponses,
        // Use serverTimestamp to prevent client-side time manipulation
        'joinedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'status': 'waiting',
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('Successfully joined waitlist for city: $city');
      }
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        print('FirebaseError joining waitlist: ${e.message}');
      }
      throw Exception('Database error: Could not process your request. Please try again.');
    } catch (e) {
      if (kDebugMode) {
        print('Unknown Error joining waitlist: $e');
      }
      throw Exception('An unexpected error occurred. Please try again later.');
    }
  }

  /// Retrieves the total number of users waitlisted in a specific city.
  /// Used to drive psychological nudging (Social Proof / FOMO) on the dashboard.
  Future<int> getWaitlistCountForCity(String city) async {
    try {
      final snapshot = await _firestore
          .collection('offline_waitlist')
          .where('city', isEqualTo: city.trim().toLowerCase())
          .count()
          .get();

      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        print('FirebaseError fetching waitlist count: ${e.message}');
      }
      // Graceful fallback to 0 to prevent UI crashes if permission or network fails
      return 0;
    } catch (e) {
      if (kDebugMode) {
        print('Unknown Error fetching waitlist count: $e');
      }
      return 0;
    }
  }

  /// Checks if the current authenticated user is already on the waitlist.
  /// Useful for hiding the nudge card to prevent annoyance and reduce churn.
  Future<bool> isUserOnWaitlist() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('offline_waitlist').doc(user.uid).get();
      return doc.exists;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking waitlist status: $e');
      }
      // Default to false on error, or true if you strictly want to avoid over-prompting
      return false; 
    }
  }
}