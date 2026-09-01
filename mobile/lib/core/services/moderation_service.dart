import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// A production-ready singleton service managing user-side moderation.
/// Strictly required for Google Play's User-Generated Content (UGC) policies.
/// This service listens to the authenticated user's personal block-list in real-time
/// and provides synchronous filtering so blocked users instantly disappear from UI feeds.
class ModerationService {
  // Singleton instance
  static final ModerationService _instance = ModerationService._internal();
  factory ModerationService() => _instance;
  ModerationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Local cache of blocked user IDs for O(1) synchronous lookups during UI rendering
  final Set<String> _blockedUserIds = {};
  
  // Stream subscription to keep the local cache synced with Firestore
  StreamSubscription<QuerySnapshot>? _blockListSubscription;
  
  // Broadcast stream so the UI can rebuild immediately when a block occurs
  final _blockStateController = StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get blockStateStream => _blockStateController.stream;

  /// Initializes the real-time listener for blocked users.
  /// Call this when the user logs in, or in `main.dart` after Firebase init.
  void init() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Listen to the user's personal blocked list collection
    _blockListSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('blocked_users')
        .snapshots()
        .listen(
      (snapshot) {
        _blockedUserIds.clear();
        for (var doc in snapshot.docs) {
          _blockedUserIds.add(doc.id);
        }
        
        // Notify the app that the block list has updated
        _blockStateController.add(Set.from(_blockedUserIds));
        debugPrint("🛡️ ModerationService synced: ${_blockedUserIds.length} users blocked.");
      },
      onError: (e) {
        debugPrint("🚨 Error syncing block list: $e");
      },
    );
  }

  /// Synchronously checks if a user is blocked.
  /// Use this inside `StreamBuilder.map` or `ListView.builder` to instantly filter out
  /// communities, events, or posts created by blocked individuals.
  bool isUserBlocked(String targetUserId) {
    return _blockedUserIds.contains(targetUserId);
  }

  /// Manually clears the service state.
  /// Call this when the user logs out to prevent data leaking between accounts.
  void clear() {
    _blockListSubscription?.cancel();
    _blockListSubscription = null;
    _blockedUserIds.clear();
    _blockStateController.add({});
  }

  /// Disposes resources (rarely used as this lives for the app's lifecycle).
  void dispose() {
    _blockListSubscription?.cancel();
    _blockStateController.close();
  }
}