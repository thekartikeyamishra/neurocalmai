import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'local_journal_service.dart';

class DataImportResult {
  final bool success;
  final String message;
  final int recordsImported;

  DataImportResult({required this.success, required this.message, this.recordsImported = 0});
}

class DataImportService {
  static final DataImportService instance = DataImportService._internal();
  DataImportService._internal();

  final Health _health = Health();

  final List<HealthDataType> _types = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.STEPS,
  ];

  Future<DataImportResult> syncHistoricalData({int daysToFetch = 30}) async {
    try {
      bool hasPermissions = await _health.hasPermissions(_types) ?? false;
      if (!hasPermissions) {
        hasPermissions = await _health.requestAuthorization(_types);
      }

      if (!hasPermissions) {
        return DataImportResult(success: false, message: 'Health tracking permissions denied.');
      }

      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: daysToFetch));

      List<HealthDataPoint> rawData = await _health.getHealthDataFromTypes(startTime: startDate, endTime: now, types: _types);

      if (rawData.isEmpty) {
        return DataImportResult(success: true, message: 'No historical health data found.', recordsImported: 0);
      }

      final aggregatedData = _aggregateDataByDay(rawData);
      int importedCount = 0;
      
      for (var entry in aggregatedData.entries) {
        final dateStr = entry.key;
        final metrics = entry.value;
        
        final double sleepHours = (metrics['sleep_minutes'] ?? 0) / 60.0;
        final int steps = metrics['steps'] ?? 0;

        if (sleepHours == 0 && steps == 0) continue;

        String emotion = _deriveEmotionFromSomaticData(sleepHours, steps);
        String insight = _generateSomaticInsight(sleepHours, steps);

        // 🚨 ALGORITHMIC FIX: Added missing 'reframing_action' for the Paywall/Insight Screen
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

        await LocalJournalService.instance.saveEntry(JournalEntry(
          date: '${dateStr}T12:00:00.000Z', 
          sessionType: 'Health Sync',
          emotion: emotion,
          aiInsight: insight,
          slmFeaturesJson: jsonEncode(slmFeatures),
        ));
        
        importedCount++;
      }

      return DataImportResult(success: true, message: 'Imported $importedCount days of data.', recordsImported: importedCount);

    } catch (e) {
      debugPrint('[Data Import Service Error]: $e');
      return DataImportResult(success: false, message: 'Error communicating with health tracking API.');
    }
  }

  Map<String, Map<String, dynamic>> _aggregateDataByDay(List<HealthDataPoint> rawData) {
    Map<String, Map<String, dynamic>> dailyMap = {};
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

  String _deriveEmotionFromSomaticData(double sleepHours, int steps) {
    if (sleepHours > 0 && sleepHours < 5) return 'Fatigue';
    if (sleepHours >= 7 && steps > 8000) return 'Energized';
    if (sleepHours >= 6) return 'Calm';
    if (steps < 2000) return 'Lethargic';
    return 'Neutral';
  }

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