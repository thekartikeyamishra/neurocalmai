import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

// Internal Integrations
import '../../journal/services/local_journal_service.dart';

/// 🚨 ARCHITECT UPGRADE: Global Provider for Dependency Injection
final habitLoopServiceProvider = Provider<HabitLoopService>((ref) {
  return HabitLoopService(LocalJournalService.instance);
});

/// Core Engine for Retention (The Hooked Model)
class HabitLoopService {
  final LocalJournalService _localDatabase;

  HabitLoopService(this._localDatabase);

  /// --------------------------------------------------------
  /// 1. PHASE 1: THE TRIGGER (Bio-Somatic Evaluation)
  /// --------------------------------------------------------
  /// Evaluates current somatic variables against rolling averages to surface bio-empathic triggers.
  /// Designed to be called by a background worker or on app resume.
  Future<Map<String, dynamic>?> evaluateSomaticTriggers({
    required double currentSleepHours,
    required int currentSteps,
  }) async {
    try {
      // Baseline parameters derived from standard operational ranges
      const double sleepDangerThreshold = 5.0;
      const int sedentaryStepThreshold = 3000;

      if (currentSleepHours > 0 && currentSleepHours < sleepDangerThreshold) {
        return {
          'triggerType': 'SOMATIC_EXHAUSTION',
          'notificationTitle': 'System Check: High Cortisol Risk',
          'notificationBody': 'Your sleep data indicates a short rest window. Let\'s recalibrate your stress response.',
          'contextPayload': {'urgency': 'High', 'focus': 'Amygdala Calming'}
        };
      }

      if (currentSteps > 0 && currentSteps < sedentaryStepThreshold) {
        return {
          'triggerType': 'SOMATIC_STAGNATION',
          'notificationTitle': 'Mindfulness Check-In',
          'notificationBody': 'Physical stagnation detected. A short mental resetting sequence is ready for you.',
          'contextPayload': {'urgency': 'Low', 'focus': 'Somatic Shifting'}
        };
      }
      
      return null;
    } catch (e) {
      debugPrint('⚠️ [Habit Loop Trigger Error]: $e');
      return null;
    }
  }

  /// --------------------------------------------------------
  /// 2. PHASE 3 & 4: VARIABLE REWARD & INVESTMENT
  /// --------------------------------------------------------
  /// Commits user selection to the SQLite weight table to customize the local SLM profile.
  /// Utilizes atomic transactions to prevent race conditions during rapid button taps.
  Future<void> commitCognitiveInvestment({
    required String cognitiveDistortion,
    required String successfulReframingPattern,
    required bool userHelpfulnessRating,
  }) async {
    try {
      // Custom haptic feedback engine signaling investment reinforcement to the user's nervous system
      if (userHelpfulnessRating) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.lightImpact();
      } else {
        await HapticFeedback.selectionClick();
      }

      final int weightAdjustment = userHelpfulnessRating ? 1 : -1;
      final db = await _localDatabase.database; // Await the secure database instance
      
      // Ensure the localized structural table exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS slm_user_biases (
          distortion_key TEXT PRIMARY KEY,
          pattern_value TEXT,
          synaptic_weight INTEGER DEFAULT 0,
          last_updated_timestamp TEXT
        )
      ''');

      // 🚨 TECH LEAD FIX: Atomic transaction ensuring zero database corruption
      await db.transaction((txn) async {
        final List<Map<String, dynamic>> existing = await txn.query(
          'slm_user_biases',
          where: 'distortion_key = ?',
          whereArgs: [cognitiveDistortion],
        );

        final nowIso = DateTime.now().toUtc().toIso8601String();

        if (existing.isEmpty) {
          await txn.insert('slm_user_biases', {
            'distortion_key': cognitiveDistortion,
            'pattern_value': successfulReframingPattern,
            'synaptic_weight': weightAdjustment,
            'last_updated_timestamp': nowIso,
          });
        } else {
          final int currentWeight = existing.first['synaptic_weight'] as int;
          // Prevent weights from dropping endlessly into negatives if user rejects often
          final int newWeight = (currentWeight + weightAdjustment).clamp(-5, 50); 
          
          await txn.update(
            'slm_user_biases',
            {
              'pattern_value': successfulReframingPattern, // Update to the most recent pattern context
              'synaptic_weight': newWeight,
              'last_updated_timestamp': nowIso,
            },
            where: 'distortion_key = ?',
            whereArgs: [cognitiveDistortion],
          );
        }
      });
      
      debugPrint('💾 [Synaptic Investment]: Registered bias update for $cognitiveDistortion');
    } catch (e) {
      debugPrint('🚨 [Cognitive Investment Error]: $e');
    }
  }

  /// --------------------------------------------------------
  /// 3. LOOP CLOSURE: RETRIEVING THE INVESTMENT
  /// --------------------------------------------------------
  /// Fetches the user's top positively reinforced biases.
  /// Used by HybridRoutingService to inject personalized context into future AI prompts.
  Future<List<Map<String, dynamic>>> getTopCognitiveBiases({int limit = 3}) async {
    try {
      final db = await _localDatabase.database;
      
      // Check if table exists first to prevent crashes on fresh installs
      final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='slm_user_biases'");
          
      if (tableCheck.isEmpty) return [];

      // Fetch the highest weighted patterns that the user explicitly found helpful (> 0)
      final List<Map<String, dynamic>> topBiases = await db.query(
        'slm_user_biases',
        where: 'synaptic_weight > ?',
        whereArgs: [0],
        orderBy: 'synaptic_weight DESC',
        limit: limit,
      );

      return topBiases;
    } catch (e) {
      debugPrint('🚨 [Bias Retrieval Error]: $e');
      return [];
    }
  }
}