import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

// Internal Integrations
import '../../journal/services/local_journal_service.dart';

/// 🚨 ARCHITECT UPGRADE: Global Provider for Dependency Injection
/// Establishes clean decoupled testing parameters across the operational architecture.
final habitLoopServiceProvider = Provider<HabitLoopService>((ref) {
  return HabitLoopService(LocalJournalService.instance);
});

/// Core Engine for System Retention (The Hooked Model Implementation)
/// Processes subconscious triggers, calculates engagement vectors, and weights user bias modifications.
class HabitLoopService {
  final LocalJournalService _localDatabase;

  HabitLoopService(this._localDatabase);

  // ============================================================================
  // 1. PHASE 1: THE TRIGGER (Bio-Somatic Evaluation)
  // ============================================================================
  /// Evaluates immediate somatic inputs against operational safety ranges to generate 
  /// contextually appropriate bio-empathic trigger configurations.
  /// Intended to run smoothly during system wake sequences or foreground notification transitions.
  Future<Map<String, dynamic>?> evaluateSomaticTriggers({
    required double currentSleepHours,
    required int currentSteps,
  }) async {
    try {
      // Baseline parameters derived from standard operational wellness curves
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
      debugPrint('⚠️ [Habit Loop Trigger Warning]: Structural metrics incomplete - $e');
      return null;
    }
  }

  // ============================================================================
  // 2. PHASE 3 & 4: VARIABLE REWARD & INVESTMENT
  // ============================================================================
  /// Commits user behavioral selection profiles to the local SQLite weight matrix[cite: 17].
  /// Utilizes strict isolated transaction environments to guard against race conditions[cite: 17].
  Future<void> commitCognitiveInvestment({
    required String cognitiveDistortion,
    required String successfulReframingPattern,
    required bool userHelpfulnessRating,
  }) async {
    try {
      // Custom double-tap haptic framework pulsing verification states directly down to the device
      if (userHelpfulnessRating) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.lightImpact();
      } else {
        await HapticFeedback.selectionClick();
      }

      final int weightAdjustment = userHelpfulnessRating ? 1 : -1;
      final db = await _localDatabase.database; 
      
      // Ensure the structural tracking schema is operational prior to recording transactions
      await db.execute('''
        CREATE TABLE IF NOT EXISTS slm_user_biases (
          distortion_key TEXT PRIMARY KEY,
          pattern_value TEXT,
          synaptic_weight INTEGER DEFAULT 0,
          last_updated_timestamp TEXT
        )
      ''');

      // 🚨 TECH LEAD FIX: Atomic database transaction preventing pipeline deadlocks
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
          
          // Clamp values dynamically between -5 and 50 to maintain baseline stability 
          // and prevent malicious long-tail math calculation overflows inside prompt builders.
          final int newWeight = (currentWeight + weightAdjustment).clamp(-5, 50); 
          
          await txn.update(
            'slm_user_biases',
            {
              'pattern_value': successfulReframingPattern, 
              'synaptic_weight': newWeight,
              'last_updated_timestamp': nowIso,
            },
            where: 'distortion_key = ?',
            whereArgs: [cognitiveDistortion],
          );
        }
      });
      
      debugPrint('💾 [Synaptic Investment]: Updated localized bias array for $cognitiveDistortion');
    } catch (e) {
      debugPrint('🚨 [Cognitive Investment Error]: Transaction interrupted - $e');
    }
  }

  // ============================================================================
  // 3. LOOP CLOSURE: RETRIEVING THE INVESTMENT
  // ============================================================================
  /// Extracts heavily weighted baseline elements confirmed as positive by the user[cite: 17].
  /// Injected natively into pipeline request objects to personalize subsequent interaction matrices[cite: 17].
  Future<List<Map<String, dynamic>>> getTopCognitiveBiases({int limit = 3}) async {
    try {
      final db = await _localDatabase.database;
      
      // Safe check ensuring localized structural schemas have loaded cleanly before processing queries
      final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='slm_user_biases'");
          
      if (tableCheck.isEmpty) return [];

      // Query tracking variables that contain proven therapeutic value (> 0 weight checks)[cite: 17]
      final List<Map<String, dynamic>> topBiases = await db.query(
        'slm_user_biases',
        where: 'synaptic_weight > ?',
        whereArgs: [0],
        orderBy: 'synaptic_weight DESC',
        limit: limit,
      );

      return topBiases;
    } catch (e) {
      debugPrint('🚨 [Bias Retrieval Error]: Failed to extract data vectors - $e');
      return [];
    }
  }
}