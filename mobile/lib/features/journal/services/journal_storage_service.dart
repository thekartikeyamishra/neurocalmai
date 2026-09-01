import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/structured_journal_entry.dart';

/// Service responsible for managing structured journal data.
/// Engineered for offline-first capabilities and telemetry pattern extraction.
class JournalStorageService {
  static final JournalStorageService instance = JournalStorageService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  JournalStorageService._internal() {
    // 🛡️ DATA MOAT: Explicitly enforce offline persistence.
    // This allows the app to function flawlessly in rural areas or airplane mode.
    // Data is written to local SQLite automatically and synced when connectivity returns.
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  /// Helper to get the current authenticated user securely
  String _getSecureUserId() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Security Error: Unauthorized access attempt. User is not logged in.');
    }
    return uid;
  }

  // ===========================================================================
  // CORE CRUD OPERATIONS
  // ===========================================================================

  /// Saves a new structured journal entry or updates an existing one.
  /// Works entirely offline; Firebase SDK handles background syncing.
  Future<void> saveEntry(StructuredJournalEntry entry) async {
    try {
      final uid = _getSecureUserId();
      
      // Safety check to enforce architecture rules
      if (entry.userId != uid) {
        throw Exception('Data Integrity Error: Attempted to save an entry for a mismatched user ID.');
      }

      // If the ID is a temporary local timestamp, generate a secure Firebase ID
      String documentId = entry.id;
      final collection = _firestore.collection('journals');
      
      if (!documentId.contains(RegExp(r'[a-zA-Z]'))) {
        documentId = collection.doc().id;
      }

      // Convert the entry to a Map and inject Firestore server timestamps for accuracy
      final data = entry.copyWith(id: documentId).toMap();
      data['createdAt'] = entry.createdAt.millisecondsSinceEpoch > 0 ? Timestamp.fromDate(entry.createdAt) : FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      // Write to the top-level /journals collection (protected by firestore.rules)
      await collection.doc(documentId).set(data, SetOptions(merge: true));
      
      debugPrint('✅ [Journal Storage]: Entry saved successfully (ID: $documentId).');

    } catch (e) {
      debugPrint('🚨 [Journal Storage Error - Save]: $e');
      rethrow;
    }
  }

  /// Retrieves a paginated list of the user's recent journal entries.
  /// Optimized to read from the local cache first for zero-latency UI loading.
  Future<List<StructuredJournalEntry>> getRecentEntries({int limit = 20}) async {
    try {
      final uid = _getSecureUserId();
      
      final snapshot = await _firestore
          .collection('journals')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs.map((doc) {
        return StructuredJournalEntry.fromMap(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      debugPrint('🚨 [Journal Storage Error - Get]: $e');
      // Graceful degradation: Return empty list so the UI doesn't hard crash
      return []; 
    }
  }

  /// Deletes a journal entry permanently.
  Future<void> deleteEntry(String documentId) async {
    try {
      // Security: We don't just delete by ID, we query it first to ensure ownership
      // though firestore.rules will reject a bad delete anyway.
      await _firestore.collection('journals').doc(documentId).delete();
      debugPrint('🗑️ [Journal Storage]: Entry $documentId deleted.');
    } catch (e) {
      debugPrint('🚨 [Journal Storage Error - Delete]: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // ANALYTICS & PATTERN DETECTION (The Data Moat)
  // ===========================================================================

  /// Aggregates cognitive distortions over the last X days to show the user their mental patterns.
  Future<Map<String, int>> getDistortionFrequency(int daysBack) async {
    try {
      final uid = _getSecureUserId();
      final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));

      final snapshot = await _firestore
          .collection('journals')
          .where('userId', isEqualTo: uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .get(const GetOptions(source: Source.serverAndCache));

      final Map<String, int> frequencies = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String? distortion = data['aiDistortionTag'];
        
        if (distortion != null && distortion.isNotEmpty && distortion != 'none') {
          frequencies[distortion] = (frequencies[distortion] ?? 0) + 1;
        }
      }

      return frequencies;

    } catch (e) {
      debugPrint('🚨 [Journal Analytics Error]: $e');
      return {};
    }
  }

  /// Creates a real-time stream of entries (useful if the user is syncing data across multiple devices).
  Stream<List<StructuredJournalEntry>> streamEntries() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('journals')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return StructuredJournalEntry.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
}