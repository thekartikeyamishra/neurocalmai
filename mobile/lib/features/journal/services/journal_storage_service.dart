import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/structured_journal_entry.dart';
import 'local_journal_service.dart';

/// Structured journal storage — ON-DEVICE ONLY.
///
/// PRIVACY FIX: the product promise is "your journals stay on your device",
/// but this service wrote entries to a cloud `/journals` collection. It now
/// stores everything in the local SQLite journal (the same one the "My
/// Journal" timeline reads), and migrates any legacy cloud entries down to
/// the device once, then deletes them from the cloud.
class JournalStorageService {
  static final JournalStorageService instance = JournalStorageService._internal();
  JournalStorageService._internal();

  static const String _marker = 'structured_v1';
  static const String _kMigrated = 'journals_cloud_migrated_v1';

  String _uid() => FirebaseAuth.instance.currentUser?.uid ?? 'local';

  static String _labelFor(String intentId) {
    switch (intentId) {
      case 'cbt_wizard':
        return 'CBT Reframe';
      case 'sleep_dump':
        return 'Sleep Dump';
      case 'guided_task':
        return 'Task Unblock';
      case 'standard_journal':
        return 'Reflection';
      default:
        return 'Journal';
    }
  }

  Map<String, dynamic> _toJsonSafe(StructuredJournalEntry e) => {
        'marker': _marker,
        'id': e.id,
        'userId': e.userId,
        'intentId': e.intentId,
        'intensity': e.intensity,
        'rawInputs': e.rawInputs,
        'aiDistortionTag': e.aiDistortionTag,
        'aiSocraticQuestion': e.aiSocraticQuestion,
        'userReframe': e.userReframe,
        'createdAt': e.createdAt.toIso8601String(),
        'updatedAt': e.updatedAt.toIso8601String(),
      };

  /// Saves an entry locally. Never throws to the UI (journals must not be lost
  /// silently, so failures are logged and surfaced via the return value).
  Future<bool> saveEntry(StructuredJournalEntry entry) async {
    try {
      final normalized = entry.userId == 'current_user' || entry.userId.isEmpty
          ? entry.copyWith(userId: _uid())
          : entry;
      final insightParts = <String>[
        if ((normalized.userReframe ?? '').isNotEmpty) normalized.userReframe!,
        if ((normalized.aiSocraticQuestion ?? '').isNotEmpty) normalized.aiSocraticQuestion!,
        if ((normalized.userReframe ?? '').isEmpty && (normalized.aiSocraticQuestion ?? '').isEmpty)
          normalized.rawInputs.values.join(' · '),
      ];
      await LocalJournalService.instance.saveEntry(JournalEntry(
        date: normalized.createdAt.toIso8601String(),
        sessionType: _labelFor(normalized.intentId),
        emotion: normalized.aiDistortionTag ?? 'reflection',
        aiInsight: insightParts.join('\n\n'),
        slmFeaturesJson: jsonEncode(_toJsonSafe(normalized)),
      ));
      return true;
    } catch (e) {
      debugPrint('🚨 [Journal Storage]: local save failed: $e');
      return false;
    }
  }

  /// Most recent structured entries (local).
  Future<List<StructuredJournalEntry>> getRecentEntries({int limit = 20}) async {
    try {
      final rows = await LocalJournalService.instance.fetchHistory();
      final out = <StructuredJournalEntry>[];
      for (final row in rows) {
        final raw = row.slmFeaturesJson;
        if (raw == null || !raw.contains(_marker)) continue;
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          out.add(StructuredJournalEntry.fromMap(map, (map['id'] ?? '${row.id}').toString()));
        }
        if (out.length >= limit) break;
      }
      return out;
    } catch (e) {
      debugPrint('🚨 [Journal Storage]: read failed: $e');
      return [];
    }
  }

  /// Local entries are deleted from the timeline by row id.
  Future<void> deleteEntry(String documentId) async {
    final id = int.tryParse(documentId);
    if (id != null) await LocalJournalService.instance.deleteEntry(id);
  }

  Future<Map<String, int>> getDistortionFrequency(int daysBack) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysBack));
    final entries = await getRecentEntries(limit: 500);
    final Map<String, int> frequencies = {};
    for (final e in entries) {
      if (e.createdAt.isBefore(cutoff)) continue;
      final d = e.aiDistortionTag;
      if (d != null && d.isNotEmpty && d != 'none') {
        frequencies[d] = (frequencies[d] ?? 0) + 1;
      }
    }
    return frequencies;
  }

  Stream<List<StructuredJournalEntry>> streamEntries() async* {
    yield await getRecentEntries();
  }

  /// One-time: copy legacy cloud journals to the device, then delete them
  /// from Firestore. Safe to call every launch; retries until it succeeds.
  Future<void> migrateCloudJournalsToDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kMigrated) == true) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('journals')
          .where('userId', isEqualTo: uid)
          .limit(500)
          .get(const GetOptions(source: Source.server));
      for (final doc in snap.docs) {
        final entry = StructuredJournalEntry.fromMap(doc.data(), doc.id);
        final saved = await saveEntry(entry);
        if (saved) await doc.reference.delete();
      }
      await prefs.setBool(_kMigrated, true);
      if (snap.docs.isNotEmpty) {
        debugPrint('🔒 [Journal Storage]: moved ${snap.docs.length} entries to device.');
      }
    } catch (e) {
      debugPrint('ℹ️ [Journal Storage]: migration deferred: $e');
    }
  }
}
