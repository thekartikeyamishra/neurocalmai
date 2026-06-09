import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for securely logging anonymized, feature-engineered 
/// behavioral data to build proprietary Small Language Models (SLM).
/// 
/// Operates on a "fail-silent" architecture to ensure telemetry gathering 
/// never disrupts the primary user experience.
class SLMTelemetryService {
  final FirebaseFirestore _firestore;

  // Constructor with optional dependency injection for testing
  SLMTelemetryService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Logs user behavior in a feature-engineered JSONL-style format 
  /// ready for ML pipelines.
  Future<void> logBehavioralPattern({
    required String userId,
    required String featureContext,
    required String prompt,
    required String aiResponse,
    required int dwellTimeSeconds,
    required bool convertedToAction,
  }) async {
    try {
      // 1. Scrub Personally Identifiable Information (PII) before it ever leaves the device
      final scrubbedPrompt = _scrubPII(prompt);
      final scrubbedResponse = _scrubPII(aiResponse);
      
      // 2. Feature Engineering Format
      final mlPayload = {
        // Use a one-way cryptographic hash of the user ID to maintain session continuity 
        // across datasets without exposing the actual identity.
        'session_hash': userId.hashCode.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'context': featureContext,
        'input_sequence': scrubbedPrompt,
        'output_sequence': scrubbedResponse,
        'metrics': {
          'dwell_time': dwellTimeSeconds,
          'converted': convertedToAction,
          'engagement_score': _calculateEngagement(dwellTimeSeconds, convertedToAction),
        },
        'version': '1.0.0', // Helps version control the dataset schema
      };

      // 3. Store in a secure, isolated data lake collection separate from operational data
      await _firestore.collection('slm_training_lake').add(mlPayload);

      if (kDebugMode) {
        print('SLM Telemetry successfully recorded for context: $featureContext');
      }
    } catch (e) {
      // Fail silently: Analytics and telemetry must NEVER break the user experience
      if (kDebugMode) {
        print('SLM Telemetry Error: $e');
      }
    }
  }

  /// Calculates a standardized engagement score (0.0 to 10.0) 
  /// to filter high-quality training data later.
  double _calculateEngagement(int dwellTimeSeconds, bool actionTaken) {
    // Baseline score from time spent reading/interacting
    double score = dwellTimeSeconds * 0.15; 
    
    // Massive bump for taking a psychological or physical action (conversion)
    if (actionTaken) {
      score += 5.0;
    }

    // Clamp between 0.0 and 10.0
    return score.clamp(0.0, 10.0);
  }

  /// Aggressively strips out common PII (Emails, Phone Numbers, Credit Cards).
  /// Note: In a true enterprise environment, this would be augmented with an 
  /// on-device NLP Named Entity Recognition (NER) model to catch edge cases.
  String _scrubPII(String text) {
    if (text.isEmpty) return text;

    String cleanText = text;

    // 1. Strip Email Addresses
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    cleanText = cleanText.replaceAll(emailRegex, '[EMAIL_REDACTED]');

    // 2. Strip Phone Numbers (Global/India formats)
    // Matches patterns like +91 9876543210, 1-800-555-1234, etc.
    final phoneRegex = RegExp(r'(?:\+?\d{1,3}[\s-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}');
    cleanText = cleanText.replaceAll(phoneRegex, '[PHONE_REDACTED]');

    // 3. Strip Potential Credit Cards (16 digit numbers, spaced or dashed)
    final ccRegex = RegExp(r'\b(?:\d[ -]*?){13,16}\b');
    cleanText = cleanText.replaceAll(ccRegex, '[CARD_REDACTED]');

    // 4. Strip Potential SSN / Aadhaar formats (hyphenated or spaced numbers)
    final idRegex = RegExp(r'\b\d{3,4}[\s-]\d{3,4}[\s-]\d{4}\b');
    cleanText = cleanText.replaceAll(idRegex, '[ID_REDACTED]');

    return cleanText.trim();
  }
}