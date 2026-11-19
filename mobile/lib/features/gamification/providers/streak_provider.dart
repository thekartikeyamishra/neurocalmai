import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Represents the current gamification state for the user.
class StreakState {
  final int currentStreak;
  final int highestStreak;
  final int totalCbtSessions;
  final DateTime? lastCompletionDate;

  const StreakState({
    this.currentStreak = 0,
    this.highestStreak = 0,
    this.totalCbtSessions = 0,
    this.lastCompletionDate,
  });

  StreakState copyWith({
    int? currentStreak,
    int? highestStreak,
    int? totalCbtSessions,
    DateTime? lastCompletionDate,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      highestStreak: highestStreak ?? this.highestStreak,
      totalCbtSessions: totalCbtSessions ?? this.totalCbtSessions,
      lastCompletionDate: lastCompletionDate ?? this.lastCompletionDate,
    );
  }
}

/// A production-ready Riverpod AsyncNotifier that manages the user's CBT streak.
/// It interfaces directly with a local SQLite database to ensure the gamification
/// loop (like the Cognitive Tree) works perfectly offline and remains entirely private.
class StreakNotifier extends AsyncNotifier<StreakState> {
  static const String _tableName = 'gamification_stats';
  Database? _database;

  @override
  Future<StreakState> build() async {
    await _initDatabase();
    return _fetchStateFromDb();
  }

  /// Initializes the local SQLite database for offline-first tracking.
  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'neurocalm_gamification.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            currentStreak INTEGER NOT NULL DEFAULT 0,
            highestStreak INTEGER NOT NULL DEFAULT 0,
            totalCbtSessions INTEGER NOT NULL DEFAULT 0,
            lastCompletionDate TEXT
          )
        ''');
        // Insert initial empty state row
        await db.insert(_tableName, {
          'id': 1,
          'currentStreak': 0,
          'highestStreak': 0,
          'totalCbtSessions': 0,
          'lastCompletionDate': null,
        });
      },
    );
  }

  /// Fetches the current streak state from SQLite.
  Future<StreakState> _fetchStateFromDb() async {
    if (_database == null) throw Exception('Database not initialized');
    
    final List<Map<String, dynamic>> maps = await _database!.query(_tableName, where: 'id = 1');
    
    if (maps.isEmpty) return const StreakState();

    final data = maps.first;
    final lastDateStr = data['lastCompletionDate'] as String?;
    final lastDate = lastDateStr != null ? DateTime.parse(lastDateStr) : null;

    // Evaluate if the streak was broken due to inactivity (missed yesterday)
    int currentStreak = data['currentStreak'] as int;
    final highestStreak = data['highestStreak'] as int;
    final totalSessions = data['totalCbtSessions'] as int;

    if (lastDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastLogDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      
      final difference = today.difference(lastLogDay).inDays;
      
      // If more than 1 day has passed, the streak is broken
      if (difference > 1) {
        currentStreak = 0;
        await _updateDbState(
          currentStreak: 0,
          highestStreak: highestStreak,
          totalSessions: totalSessions,
          lastCompletionDate: lastDate,
        );
      }
    }

    return StreakState(
      currentStreak: currentStreak,
      highestStreak: highestStreak,
      totalCbtSessions: totalSessions,
      lastCompletionDate: lastDate,
    );
  }

  /// Logs a CBT completion, calculates streak logic, and persists to SQLite.
  /// Call this when the user successfully completes a voice reframe or somatic session.
  Future<void> logCbtCompletion() async {
    // Ensure the current state is loaded before mutating
    final currentState = state.value;
    if (currentState == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    int newStreak = currentState.currentStreak;
    int newHighest = currentState.highestStreak;
    int newTotal = currentState.totalCbtSessions + 1;
    DateTime? lastLogDay;

    if (currentState.lastCompletionDate != null) {
      lastLogDay = DateTime(
        currentState.lastCompletionDate!.year,
        currentState.lastCompletionDate!.month,
        currentState.lastCompletionDate!.day,
      );
    }

    if (lastLogDay == null) {
      // First time ever logging a session
      newStreak = 1;
    } else {
      final difference = today.difference(lastLogDay).inDays;
      if (difference == 1) {
        // Logged consecutive days
        newStreak += 1;
      } else if (difference > 1) {
        // Streak broken
        newStreak = 1;
      }
      // If difference == 0, they already logged today; streak remains the same, 
      // but we still increment totalCbtSessions.
    }

    if (newStreak > newHighest) {
      newHighest = newStreak;
    }

    // Persist to local database
    await _updateDbState(
      currentStreak: newStreak,
      highestStreak: newHighest,
      totalSessions: newTotal,
      lastCompletionDate: now,
    );

    // Update Riverpod UI state
    state = AsyncData(
      currentState.copyWith(
        currentStreak: newStreak,
        highestStreak: newHighest,
        totalCbtSessions: newTotal,
        lastCompletionDate: now,
      ),
    );
    
    debugPrint('✅ [Gamification]: CBT Logged. Current Streak: $newStreak');
  }

  /// Updates the single local database row.
  Future<void> _updateDbState({
    required int currentStreak,
    required int highestStreak,
    required int totalSessions,
    required DateTime? lastCompletionDate,
  }) async {
    if (_database == null) return;
    
    await _database!.update(
      _tableName,
      {
        'currentStreak': currentStreak,
        'highestStreak': highestStreak,
        'totalCbtSessions': totalSessions,
        'lastCompletionDate': lastCompletionDate?.toIso8601String(),
      },
      where: 'id = 1',
    );
  }
}

/// Global provider for the StreakNotifier.
/// Bind this to the `CognitiveTreeWidget` to dynamically drive branch growth and blooms.
final streakProvider = AsyncNotifierProvider<StreakNotifier, StreakState>(() {
  return StreakNotifier();
});