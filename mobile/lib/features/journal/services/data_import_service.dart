import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_journal_service.dart';

/// Service Response Wrapper for highly predictable UI snackbar and loading handling
class DataImportResult {
  final bool success;
  final String message;
  final int recordsImported;

  DataImportResult({required this.success, required this.message, this.recordsImported = 0});
}

/// 🚨 ARCHITECT UPGRADE: Global Provider for Dependency Injection
/// Guarantees access parameters across both platform worker channels and user views.
final dataImportServiceProvider = Provider<DataImportService>((ref) {
  return DataImportService(LocalJournalService.instance);
});

class DataImportService {
  final LocalJournalService _localDatabase;
  final Health _health = Health();

  /// Defines the specific biometric data profiles required for psycho-somatic translation
  final List<HealthDataType> _types = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.STEPS,
  ];

  DataImportService(this._localDatabase);

  // ============================================================================
  // CORE IMPORT PIPELINE ENGINE
  // ============================================================================
  /// Requests hardware-level operating permissions and aggregates continuous raw baseline telemetry.
  /// Automatically synchronizes layout nodes via Riverpod `Ref` parameters upon transaction closure.
  Future<DataImportResult> syncHistoricalData(WidgetRef ref, {int daysToFetch = 30}) async {
    try {
      // 1. Enforce strict permissions auditing before reading device channels
      bool hasPermissions = await _health.hasPermissions(_types) ?? false;
      if (!hasPermissions) {
        hasPermissions = await _health.requestAuthorization(_types);
      }

      if (!hasPermissions) {
        return DataImportResult(
          success: false, 
          message: 'Health tracking permissions denied. Please verify your platform privacy settings.'
        );
      }

      // 2. Formulate parsing windows
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: daysToFetch));

      // 3. Extract continuous metrics collections from platform storage repositories
      List<HealthDataPoint> rawData = await _health.getHealthDataFromTypes(
        startTime: startDate, 
        endTime: now, 
        types: _types
      );

      if (rawData.isEmpty) {
        return DataImportResult(
          success: true, 
          message: 'No historical hardware baseline logs discovered during this pass.', 
          recordsImported: 0
        );
      }

      // 4. Compact continuous timeline entries to clean distinct calendar datestamps (YYYY-MM-DD)
      final aggregatedData = _aggregateDataByDay(rawData);
      int importedCount = 0;
      
      for (var entry in aggregatedData.entries) {
        final dateStr = entry.key;
        final metrics = entry.value;
        
        final double sleepHours = (metrics['sleep_minutes'] ?? 0) / 60.0;
        final int steps = metrics['steps'] ?? 0;

        // Skip structural voids to guarantee a compact, clean local file timeline
        if (sleepHours == 0 && steps == 0) continue;

        String emotion = _deriveEmotionFromSomaticData(sleepHours, steps);
        String insight = _generateSomaticInsight(sleepHours, steps);

        // Core Hooked model configuration mappings matching analytics states to reward views
        final slmFeatures = {
          'source': Platform.isIOS ? 'Apple Health' : 'Google Fit',
          'detected_emotion': emotion,
          'cognitive_distortion': sleepHours < 5 ? 'Physical Exhaustion' : 'Somatic Regulation',
          'reframing_action': sleepHours < 5 
              ? 'Focus entirely on parasympathetic nervous system repair today. Attempt 10 minutes of Yoga Nidra.' 
              : 'Physical metrics are stable. Utilize this momentum for deep cognitive journaling.',
          'urgency_level': sleepHours < 4 ? 'Medium' : 'Low',
          'sleep_hours_recorded': sleepHours.toStringAsFixed(1),
          'steps_recorded': steps,
        };

        // 5. Commit atomically down into the verified local SQLite layer
        await _localDatabase.saveEntry(JournalEntry(
          date: '${dateStr}T12:00:00.000Z', // Anchor neatly to afternoon timestamps to bypass zone boundaries
          sessionType: 'Health Sync',
          emotion: emotion,
          aiInsight: insight,
          slmFeaturesJson: jsonEncode(slmFeatures),
        ));
        
        importedCount++;
      }

      // 6. 🚨 ARCHITECT STATE REFRESH: Alert Riverpod to update view states instantly
      if (importedCount > 0) {
        ref.read(journalTimelineProvider.notifier).refresh().ignore();
      }

      return DataImportResult(
        success: true, 
        message: 'Successfully processed and synchronized $importedCount days of physical telemetry.', 
        recordsImported: importedCount
      );

    } catch (e) {
      debugPrint('🚨 [Data Import Service Core Error]: $e');
      return DataImportResult(
        success: false, 
        message: 'Platform tracking communication failure. Please verify active sensor sync states.'
      );
    }
  }

  // ============================================================================
  // DATA REDUCTION & CLEANSING AGGREGATOR
  // ============================================================================
  /// Condenses overlapping data streams into a structured daily map layout.
  Map<String, Map<String, dynamic>> _aggregateDataByDay(List<HealthDataPoint> rawData) {
    Map<String, Map<String, dynamic>> dailyMap = {};
    
    // Purge parallel device duplicate collections to protect against tracking telemetry multiplication bugs
    List<HealthDataPoint> cleanData = _health.removeDuplicates(rawData);

    for (var point in cleanData) {
      String dateKey = DateFormat('yyyy-MM-dd').format(point.dateFrom);

      if (!dailyMap.containsKey(dateKey)) {
        dailyMap[dateKey] = {'sleep_minutes': 0, 'steps': 0};
      }

      if (point.type == HealthDataType.STEPS) {
        dailyMap[dateKey]!['steps'] += (point.value as num).toInt();
      } else if (point.type == HealthDataType.SLEEP_ASLEEP) {
        dailyMap[dateKey]!['sleep_minutes'] += (point.value as num).toInt();
      }
    }
    return dailyMap;
  }

  // ============================================================================
  // SOMATIC TRANSLATION MATRIX
  // ============================================================================
  /// Translates absolute data integers directly into emotional indicators.
  String _deriveEmotionFromSomaticData(double sleepHours, int steps) {
    if (sleepHours > 0 && sleepHours < 5) return 'Fatigue';
    if (sleepHours >= 7 && steps > 8000) return 'Energized';
    if (sleepHours >= 6) return 'Calm';
    if (steps < 2000) return 'Lethargic';
    return 'Neutral';
  }

  /// Synthesizes contextual behavioral descriptions based on somatic properties.
  String _generateSomaticInsight(double sleepHours, int steps) {
    String insight = "Somatic Auto-Sync: ";
    if (sleepHours > 0) {
      insight += "Recorded ${sleepHours.toStringAsFixed(1)} hours of sleep. ";
      if (sleepHours < 5) insight += "Lack of deep sleep highly correlates with increased cortisol levels today. ";
    }
    if (steps > 0) {
      insight += "Moved $steps steps. ";
      if (steps > 8000) insight += "High activity levels naturally flush stress hormones.";
    }
    return insight.trim();
  }
}