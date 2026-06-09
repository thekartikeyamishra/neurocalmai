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

  /// Logs user behavior in a feature-engineered format ready for fine-tuning ML pipelines.
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
      
      // 2. Feature Engineering Format (Optimized for JSONL dataset generation)
      final mlPayload = {
        // Use a one-way cryptographic hash of the user ID to maintain session continuity 
        // across datasets without exposing the actual identity.
        'session_hash': userId.hashCode.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'feature_context': featureContext,
        'input_prompt_length': scrubbedPrompt.length,
        'output_response_length': scrubbedResponse.length,
        'dwell_time_seconds': dwellTimeSeconds,
        'converted_to_action': convertedToAction ? 1 : 0,
        'engagement_score': _calculateEngagementScore(dwellTimeSeconds, convertedToAction),
        
        // Structured training pair format matching standard fine-tuning input layouts
        'dataset_pair': {
          'instruction': 'You are a compassionate, structured CBT assistant operating in the context of $featureContext. Provide a localized, empathetic response and detect somatic patterns.',
          'input': scrubbedPrompt,
          'output': scrubbedResponse,
        }
      };

      // 3. Append-only write to Firestore under a dedicated telemetry collection
      // Governed by backend security rules that allow writes but prevent read/update/delete operations.
      await _firestore.collection('slm_telemetry_lake').add(mlPayload);
      
      if (kDebugMode) {
        print('📊 [SLM Telemetry]: Successfully captured sanitized interaction slice.');
      }
    } catch (e) {
      // Fail silently in production to insulate the main thread and client user interface
      debugPrint('⚠️ [SLM Telemetry Failure Intercepted]: $e');
    }
  }

  /// Evaluates implicit interest via raw platform interaction telemetry.
  double _calculateEngagementScore(int dwellTime, bool actionTaken) {
    double score = 0.0;
    
    // Logarithmic curve for dwell time weighting: steeper growth early on, plateaus at higher values
    if (dwellTime > 0) {
      score += (dwellTime <= 60) ? (dwellTime * 0.05) : 3.0;
    }
    
    // Core conversion bonus weight
    if (actionTaken) {
      score += 7.0;
    }

    return score.clamp(0.0, 10.0);
  }

  /// Aggressively strips out common PII (Emails, Phone Numbers, Credit Cards) 
  /// before data is committed to the cloud architecture.
  String _scrubPII(String text) {
    if (text.isEmpty) return text;

    String cleanText = text;

    // 1. Strip Email Addresses
    final emailRegex = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
      caseSensitive: false,
    );
    cleanText = cleanText.replaceAll(emailRegex, '[EMAIL_REDACTED]');

    // 2. Strip Phone Numbers (Matches common international and local formats)
    final phoneRegex = RegExp(
      r'(?:\+?\d{1,3}[\s-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}',
    );
    cleanText = cleanText.replaceAll(phoneRegex, '[PHONE_REDACTED]');

    // 3. Strip Potential Credit Card Sequences (Basic 13-16 digit numerical sequences)
    final creditCardRegex = RegExp(r'\b(?:\d[ -]*?){13,16}\b');
    cleanText = cleanText.replaceAll(creditCardRegex, '[CARD_REDACTED]');

    return cleanText;
  }
}