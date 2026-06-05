import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

/// 🚨 ARCHITECT FIX: Global Provider completely decoupled from LocalJournalService
/// This ensures the Single Responsibility Principle and guarantees O(1) memory speed.
final biometricCorrelationProvider = Provider<BiometricCorrelationService>((ref) {
  return BiometricCorrelationService();
});

/// Strongly typed output ensuring downstream AI prompts never receive null configurations.
class SomaticCorrelationResult {
  final double stressIndex; // 0.0 (Zen) to 1.0 (High Somatic Load)
  final String physiologicalState; // e.g., "Somatic Fatigue", "Regulated"
  final String contextualInsight;
  final String urgencyLevel; // "Low", "Medium", "High"

  SomaticCorrelationResult({
    required this.stressIndex,
    required this.physiologicalState,
    required this.contextualInsight,
    required this.urgencyLevel,
  });

  Map<String, dynamic> toJson() => {
    'stress_index': stressIndex.toStringAsFixed(2),
    'physiological_state': physiologicalState,
    'contextual_insight': contextualInsight,
    'urgency_level': urgencyLevel,
  };
}

/// 🚨 NEUROCALM'S DEFENSIBLE MOAT: The Biometric Correlation Engine
/// Translates raw Apple Health / Google Fit data into psychological contexts offline.
class BiometricCorrelationService {
  static const String _historyKey = 'somatic_7day_history';

  BiometricCorrelationService();

  /// Analyzes the user's current health metrics against their personal historical baseline.
  /// Generates a unified psychological stress multiplier for the AI Engine.
  Future<SomaticCorrelationResult> correlateCurrentState({
    required double currentSleepHours,
    required int currentSteps,
  }) async {
    try {
      // 1. Fetch the user's rolling 7-day baseline from isolated high-speed storage
      final baseline = await _calculate7DayBaseline();

      // 2. Calculate Deviation Percentages (Handling division by zero safely)
      double sleepDeviation = 0.0;
      if (baseline['avg_sleep']! > 0) {
        sleepDeviation = (baseline['avg_sleep']! - currentSleepHours) / baseline['avg_sleep']!;
      }

      double activityDeviation = 0.0;
      if (baseline['avg_steps']! > 0) {
        activityDeviation = (baseline['avg_steps']! - currentSteps) / baseline['avg_steps']!;
      }

      // 3. Compute Somatic Stress Index (SSI)
      // Weighting: Sleep deficit impacts emotional regulation heavier (60%) than step deficit (40%)
      double rawStressIndex = (math.max(0, sleepDeviation) * 0.6) + (math.max(0, activityDeviation) * 0.4);
      
      // Add absolute floor penalties for extreme physical exhaustion (Regardless of baseline)
      if (currentSleepHours > 0 && currentSleepHours < 4.5) rawStressIndex += 0.3;
      if (currentSteps > 0 && currentSteps < 1500) rawStressIndex += 0.15;

      // Clamp strictly between 0.0 and 1.0 to prevent downstream AI mathematical overflow
      final double finalStressIndex = rawStressIndex.clamp(0.0, 1.0);

      // 4. Update the rolling baseline with today's data (Fire and forget to prevent UI lag)
      _updateRollingHistory(currentSleepHours, currentSteps).ignore();

      // 5. Generate Legally-Compliant Wellness Categorizations
      return _generateLegallySafeResult(finalStressIndex, currentSleepHours, currentSteps);

    } catch (e) {
      debugPrint('🚨 [Biometric Correlation Error]: $e');
      // Graceful degradation object to prevent UI Red Screens of Death
      return SomaticCorrelationResult(
        stressIndex: 0.2, // Default low-stress baseline
        physiologicalState: "Baseline Unknown",
        contextualInsight: "Insufficient data to establish a physical baseline.",
        urgencyLevel: "Low",
      );
    }
  }

  /// --------------------------------------------------------
  /// ISOLATED DATA MANAGEMENT: 7-Day Rolling Window
  /// --------------------------------------------------------
  
  /// Calculates a personalized rolling average to prevent false-positives.
  /// (e.g., An athlete's baseline of 15,000 steps vs a desk worker's 4,000 steps).
  Future<Map<String, double>> _calculate7DayBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString(_historyKey);
      
      if (historyJson == null) {
        // Safe global average defaults if user is brand new
        return {'avg_sleep': 7.0, 'avg_steps': 5000.0};
      }

      final List<dynamic> history = jsonDecode(historyJson);
      if (history.isEmpty) return {'avg_sleep': 7.0, 'avg_steps': 5000.0};

      double totalSleep = 0;
      int totalSteps = 0;
      int validRecords = 0;

      for (var record in history) {
        final double sleep = (record['sleep'] as num?)?.toDouble() ?? 0.0;
        final int steps = (record['steps'] as num?)?.toInt() ?? 0;
        
        if (sleep > 0 || steps > 0) {
          totalSleep += sleep;
          totalSteps += steps;
          validRecords++;
        }
      }

      if (validRecords == 0) return {'avg_sleep': 7.0, 'avg_steps': 5000.0};

      return {
        'avg_sleep': totalSleep / validRecords,
        'avg_steps': totalSteps / validRecords,
      };
    } catch (e) {
      debugPrint('⚠️ [Baseline Calculation Warning]: $e');
      return {'avg_sleep': 7.0, 'avg_steps': 5000.0};
    }
  }

  /// Keeps a rolling log of exactly the last 7 days to maintain dynamic accuracy 
  /// without polluting SharedPreferences storage memory over years of usage.
  Future<void> _updateRollingHistory(double sleep, int steps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String todayKey = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      
      List<dynamic> history = [];
      final String? existingHistory = prefs.getString(_historyKey);
      if (existingHistory != null) {
        history = jsonDecode(existingHistory);
      }

      // Remove today's entry if it already exists (to overwrite with latest synced data)
      history.removeWhere((record) => record['date'] == todayKey);

      // Append latest metrics
      history.add({
        'date': todayKey,
        'sleep': sleep,
        'steps': steps,
      });

      // Keep only the last 7 days to prevent SharedPreferences bloat
      if (history.length > 7) {
        history = history.sublist(history.length - 7);
      }

      await prefs.setString(_historyKey, jsonEncode(history));
    } catch (e) {
      debugPrint('⚠️ [History Update Warning]: $e');
    }
  }

  /// --------------------------------------------------------
  /// LEGAL & COMPLIANCE GUARDRAIL
  /// --------------------------------------------------------
  
  /// Translates raw index math into strictly "General Wellness" vocabulary.
  /// This intentionally bypasses medical terminology to avoid FDA/CE medical device scrutiny.
  SomaticCorrelationResult _generateLegallySafeResult(double index, double sleep, int steps) {
    if (index >= 0.7) {
      return SomaticCorrelationResult(
        stressIndex: index,
        physiologicalState: "Somatic Overload",
        contextualInsight: "High physical exhaustion detected (${sleep.toStringAsFixed(1)}h rest). Cognitive resilience is naturally lowered today. Focus on parasympathetic grounding.",
        urgencyLevel: "High",
      );
    } else if (index >= 0.4) {
      return SomaticCorrelationResult(
        stressIndex: index,
        physiologicalState: "Elevated Tension",
        contextualInsight: "Slight deviation from your physical baseline. You may experience heightened emotional reactivity.",
        urgencyLevel: "Medium",
      );
    } else {
      return SomaticCorrelationResult(
        stressIndex: index,
        physiologicalState: "Physiologically Regulated",
        contextualInsight: "Physical baseline is stable. Optimal conditions for deep cognitive journaling.",
        urgencyLevel: "Low",
      );
    }
  }
}