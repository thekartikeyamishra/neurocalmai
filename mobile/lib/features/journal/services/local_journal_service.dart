import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// DATA MODEL
// ============================================================================
class JournalEntry {
  final int? id;
  final String date;            
  final String sessionType;     
  final String emotion;         
  final String aiInsight;       
  final String? slmFeaturesJson;

  JournalEntry({
    this.id,
    required this.date,
    required this.sessionType,
    required this.emotion,
    required this.aiInsight,
    this.slmFeaturesJson,       
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'sessionType': sessionType,
      'emotion': emotion,
      'aiInsight': aiInsight,
      'slmFeaturesJson': slmFeaturesJson, 
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as int?,
      date: map['date'] as String,
      sessionType: map['sessionType'] as String,
      emotion: map['emotion'] as String,
      aiInsight: map['aiInsight'] as String,
      slmFeaturesJson: map['slmFeaturesJson'] as String?, 
    );
  }
}

// ============================================================================
// DATABASE SERVICE (Singleton)
// ============================================================================
class LocalJournalService {
  static final LocalJournalService instance = LocalJournalService._internal();
  LocalJournalService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'neurocalm_journal.db');
    return await openDatabase(
      path,
      version: 2, 
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, 
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE journal(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        sessionType TEXT NOT NULL,
        emotion TEXT NOT NULL,
        aiInsight TEXT NOT NULL,
        slmFeaturesJson TEXT
      )
    ''');
    debugPrint('[LocalJournalService]: Offline SQLite Database created (v2).');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE journal ADD COLUMN slmFeaturesJson TEXT;');
      debugPrint('[LocalJournalService]: Database upgraded to v2. Added slmFeaturesJson.');
    }
  }

  Future<void> saveEntry(JournalEntry entry) async {
    try {
      final db = await database;
      await db.insert(
        'journal', 
        entry.toMap(), 
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    } catch (e) {
      debugPrint('[LocalJournalService Error]: Failed to save entry - $e');
    }
  }

  Future<List<JournalEntry>> fetchHistory() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'journal', 
        orderBy: 'date DESC'
      );
      return List.generate(maps.length, (i) => JournalEntry.fromMap(maps[i]));
    } catch (e) {
      debugPrint('[LocalJournalService Error]: Failed to fetch history - $e');
      return [];
    }
  }

  // 🚨 TECH LEAD FIX: Added missing method required by BiometricCorrelationService
  Future<List<JournalEntry>> getRecentHealthSyncEntries({required int days}) async {
    try {
      final db = await database;
      final cutoffDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();

      final List<Map<String, dynamic>> maps = await db.query(
        'journal',
        where: 'sessionType = ? AND date >= ?',
        whereArgs: ['Health Sync', cutoffDate],
        orderBy: 'date DESC',
      );

      return List.generate(maps.length, (i) => JournalEntry.fromMap(maps[i]));
    } catch (e) {
      debugPrint('[LocalJournalService Error]: Failed to fetch health sync entries - $e');
      return [];
    }
  }

  Future<void> deleteEntry(int id) async {
    try {
      final db = await database;
      await db.delete('journal', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[LocalJournalService Error]: Failed to delete entry - $e');
    }
  }

  Future<void> clearAllData() async {
    try {
      final db = await database;
      await db.delete('journal');
      debugPrint('[LocalJournalService]: ALL device data purged securely.');
    } catch (e) {
      debugPrint('[LocalJournalService Error]: Failed to clear data - $e');
    }
  }
}

// ============================================================================
// RIVERPOD REACTIVE BRIDGE
// This ensures the Timeline UI updates instantly when background syncs occur.
// ============================================================================
class JournalTimelineNotifier extends AsyncNotifier<List<JournalEntry>> {
  @override
  Future<List<JournalEntry>> build() async {
    return await LocalJournalService.instance.fetchHistory();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await LocalJournalService.instance.fetchHistory());
  }
  
  Future<void> addEntry(JournalEntry entry) async {
    await LocalJournalService.instance.saveEntry(entry);
    await refresh(); // Instantly triggers a UI rebuild
  }

  Future<void> removeEntry(int id) async {
    await LocalJournalService.instance.deleteEntry(id);
    await refresh();
  }
}

final journalTimelineProvider = AsyncNotifierProvider<JournalTimelineNotifier, List<JournalEntry>>(() {
  return JournalTimelineNotifier();
});