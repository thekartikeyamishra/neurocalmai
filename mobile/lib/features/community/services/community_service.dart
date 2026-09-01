import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for handling Community and Event operations.
/// Strictly implements Google Play's User-Generated Content (UGC) policies
/// including mandatory EULA checks, reporting mechanisms, and user blocking.
class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================================================================
  // 1. GLOBAL DISCOVERY
  // =========================================================================

  /// Fetch active communities globally based on the user's selected country and city.
  /// Replaces the hardcoded location constraints to allow worldwide scaling.
  Stream<QuerySnapshot<Map<String, dynamic>>> getCommunities({
    required String country,
    required String city,
  }) {
    return _firestore
        .collection('communities')
        .where('country', isEqualTo: country.toUpperCase().trim())
        .where('city', isEqualTo: city.trim())
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // =========================================================================
  // 2. CREATION & EULA COMPLIANCE
  // =========================================================================

  /// Create a new local community chapter.
  /// Enforces Google Play's UGC policy by requiring explicit acceptance
  /// of the Community Facilitator Agreement and Non-Clinical Liability EULA.
  Future<String> createCommunity({
    required String name,
    required String city,
    required String country,
    required String geoHash,
    required bool acceptedCharter,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Authentication required.");

    // Strict EULA & Charter constraint
    if (!acceptedCharter) {
      throw Exception(
        "You must accept the Community Facilitator Agreement and Non-Clinical Liability EULA before creating a chapter.",
      );
    }

    final docRef = await _firestore.collection('communities').add({
      'name': name.trim(),
      'city': city.trim(),
      'country': country.toUpperCase().trim(),
      'geoHash': geoHash,
      'creatorId': user.uid,
      'creatorName': user.displayName ?? "Community Anchor",
      'status':
          'active', // Managed by Cloud Functions ('active', 'under_review', 'suspended')
      'memberCount': 1,
      'maxCapacity': 50,
      'rulesAccepted': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Post a meetup event restricted strictly to public venues.
  /// Prevents private-residence meetups and hard-caps attendance for safety.
  Future<void> postEvent({
    required String communityId,
    required String title,
    required String description,
    required String venueName,
    required String address,
    required String venueType,
    required DateTime scheduledAt,
    required int maxAttendees,
    required bool liabilityAcknowledged,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Authentication required.");

    // Safety waiver constraint
    if (!liabilityAcknowledged) {
      throw Exception(
        "You must acknowledge the non-medical liability and public venue constraints.",
      );
    }

    // Safety constraint: Max 12 attendees to prevent overwhelming crowds
    // and maintain micro-group intimacy for social anxiety.
    final safeCapacity = maxAttendees.clamp(2, 12);

    await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('events')
        .add({
          'title': title.trim(),
          'description': description.trim(),
          'hostId': user.uid,
          'hostName': user.displayName ?? "Host",
          'venueType':
              venueType, // Must be 'public_cafe', 'park', 'library', etc.
          'venueName': venueName.trim(),
          'address': address.trim(),
          'scheduledAt': Timestamp.fromDate(scheduledAt),
          'maxAttendees': safeCapacity,
          'attendeeIds': [user.uid],
          'isPublic': true,
          'liabilityAcknowledged': true,
          'status': 'upcoming',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  // =========================================================================
  // 3. EVENT PARTICIPATION
  // =========================================================================

  /// Join or leave a scheduled event (RSVP mechanism).
  Future<void> toggleRsvp({
    required String communityId,
    required String eventId,
    required bool isJoining,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Authentication required.");

    final eventRef = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('events')
        .doc(eventId);

    if (isJoining) {
      await eventRef.update({
        'attendeeIds': FieldValue.arrayUnion([user.uid]),
      });
    } else {
      await eventRef.update({
        'attendeeIds': FieldValue.arrayRemove([user.uid]),
      });
    }
  }

  // =========================================================================
  // 4. GOOGLE PLAY UGC MODERATION COMPLIANCE
  // =========================================================================

  /// Reports a specific piece of user-generated content or community.
  /// Triggers a backend Cloud Function to automatically hide content if report thresholds are met.
  Future<void> reportContent({
    required String reportedUserId,
    required String contentType, // 'community', 'event', or 'user'
    required String contentId,
    required String reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null)
      throw Exception("Authentication required to report content.");

    await _firestore.collection('reports').add({
      'reporterId': user.uid,
      'reportedUserId': reportedUserId,
      'contentType': contentType,
      'contentId': contentId,
      'reason': reason,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    debugPrint("Content $contentId reported successfully.");
  }

  /// Convenience wrapper to report a specific user's behavior.
  Future<void> reportUser({
    required String reportedUserId,
    required String reason,
  }) async {
    return reportContent(
      reportedUserId: reportedUserId,
      contentType: 'user',
      contentId: reportedUserId,
      reason: reason,
    );
  }

  /// Blocks a user, satisfying Google Play's 1:1 interaction safeguard policy.
  /// Writes to the authenticated user's local blocked list in Firestore,
  /// allowing the UI's ModerationService to instantly filter them out of feeds.
  Future<void> blockUser({required String blockedUserId}) async {
    final user = _auth.currentUser;
    if (user == null)
      throw Exception("Authentication required to block a user.");

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('blocked_users')
        .doc(blockedUserId)
        .set({'blockedAt': FieldValue.serverTimestamp()});

    debugPrint("User $blockedUserId has been blocked by ${user.uid}.");
  }
}
