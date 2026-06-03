import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class StreakData {
  final int currentStreak;
  final int freezesAvailable;
  final Set<String> completedDates;

  StreakData({
    required this.currentStreak,
    required this.freezesAvailable,
    required this.completedDates,
  });
}

class StreakService {
  static final StreakService instance = StreakService._internal();
  StreakService._internal();

  static const String _lastActiveKey = 'last_active_date';
  static const String _streakCountKey = 'current_streak';
  static const String _freezesKey = 'streak_freezes';
  static const String _completedDatesKey = 'completed_dates_list';

  /// 🚨 ARCHITECT FIX: Standardized format 'yyyy-MM-dd' to prevent timezone/time-of-day bugs
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<StreakData> recordActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now();
      final todayStr = _formatDate(now);

      final lastActiveStr = prefs.getString(_lastActiveKey);
      int currentStreak = prefs.getInt(_streakCountKey) ?? 0;
      int freezes = prefs.getInt(_freezesKey) ?? 1; // 1 free grace day

      List<String> datesList = prefs.getStringList(_completedDatesKey) ?? [];
      Set<String> completedDates = datesList.toSet();

      if (lastActiveStr != null) {
        final lastActiveDate = DateFormat('yyyy-MM-dd').parse(lastActiveStr);
        final todayDate = DateFormat('yyyy-MM-dd').parse(todayStr);
        final differenceInDays = todayDate.difference(lastActiveDate).inDays;

        if (differenceInDays == 1) {
          currentStreak++; // Perfect consecutive day
        } else if (differenceInDays > 1) {
          if (freezes > 0 && differenceInDays == 2) {
            freezes--;
            currentStreak++;
            debugPrint('[StreakService]: Streak saved by Freeze Mechanism.');
          } else {
            currentStreak = 1;
            debugPrint('[StreakService]: Streak reset due to inactivity.');
          }
        }
      } else {
        currentStreak = 1; // First time ever
      }

      if (!completedDates.contains(todayStr)) {
        completedDates.add(todayStr);
      }

      await prefs.setString(_lastActiveKey, todayStr);
      await prefs.setInt(_streakCountKey, currentStreak);
      await prefs.setInt(_freezesKey, freezes);
      await prefs.setStringList(_completedDatesKey, completedDates.toList());

      return StreakData(
        currentStreak: currentStreak,
        freezesAvailable: freezes,
        completedDates: completedDates,
      );
    } catch (e) {
      debugPrint('[StreakService Error]: $e');
      return StreakData(
        currentStreak: 1,
        freezesAvailable: 1,
        completedDates: {},
      );
    }
  }

  Future<StreakData> getStreakData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentStreak = prefs.getInt(_streakCountKey) ?? 0;
      final freezes = prefs.getInt(_freezesKey) ?? 1;
      final datesList = prefs.getStringList(_completedDatesKey) ?? [];

      return StreakData(
        currentStreak: currentStreak,
        freezesAvailable: freezes,
        completedDates: datesList.toSet(),
      );
    } catch (e) {
      debugPrint('[StreakService Error]: $e');
      return StreakData(
        currentStreak: 0,
        freezesAvailable: 1,
        completedDates: {},
      );
    }
  }

  /// 🚨 PRIVACY FIX: Expose data wiping utility so users can reset their tracking progress
  Future<void> clearStreakData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastActiveKey);
      await prefs.remove(_streakCountKey);
      await prefs.remove(_freezesKey);
      await prefs.remove(_completedDatesKey);
      debugPrint(
        '🗑️ [StreakService]: All local streak data successfully wiped.',
      );
    } catch (e) {
      debugPrint('🚨 [StreakService Error]: Failed to wipe streak data - $e');
    }
  }
}
