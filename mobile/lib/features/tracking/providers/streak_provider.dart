import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// Internal Integrations
import '../../journal/services/local_journal_service.dart';

/// Represents the mathematically verified state of the user's consistency.
class StreakState {
  final int currentStreak;
  final Set<String> completedDates;

  StreakState({
    required this.currentStreak,
    required this.completedDates,
  });
}

/// 🚨 ARCHITECT UPGRADE: Single Source of Truth Engine
/// This completely replaces SharedPreferences tracking. It queries the SQLite 
/// database directly in O(N) time to guarantee the calendar is never desynced.
class StreakNotifier extends AsyncNotifier<StreakState> {
  
  @override
  Future<StreakState> build() async {
    return await _calculateStreak();
  }

  /// Traverses user journaling history to calculate active consistency intervals safely.
  Future<StreakState> _calculateStreak() async {
    try {
      final entries = await LocalJournalService.instance.fetchHistory();
      
      if (entries.isEmpty) {
        return StreakState(currentStreak: 0, completedDates: {});
      }

      final Set<String> completed = {};
      final formatter = DateFormat('yyyy-MM-dd');
      
      // 1. Map all SQLite entries to absolute local dates (YYYY-MM-DD)
      for (var entry in entries) {
        final date = DateTime.parse(entry.date).toLocal();
        completed.add(formatter.format(date));
      }

      // Guard against timezone/midnight calculation runtime drift by freezing immediate time
      final DateTime now = DateTime.now();
      final String todayStr = formatter.format(now);
      final String yesterdayStr = formatter.format(now.subtract(const Duration(days: 1)));

      int streak = 0;
      DateTime cursor = now;

      // 2. Grace Period Logic: If they haven't logged today, but logged yesterday,
      // the streak is pending, not broken.
      if (!completed.contains(todayStr) && completed.contains(yesterdayStr)) {
        cursor = now.subtract(const Duration(days: 1));
      }

      // 3. Count consecutively backwards
      while (completed.contains(formatter.format(cursor))) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }

      return StreakState(currentStreak: streak, completedDates: completed);
    } catch (e) {
      debugPrint('🚨 [Streak Provider Error]: Failed parsing history array values - $e');
      return StreakState(currentStreak: 0, completedDates: {});
    }
  }

  /// Call this whenever a new journal entry is saved to instantly update the UI Calendar
  Future<void> refreshStreak() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _calculateStreak());
  }
}

/// Global Provider for the Habit Calendar
final streakProvider = AsyncNotifierProvider<StreakNotifier, StreakState>(() {
  return StreakNotifier();
});