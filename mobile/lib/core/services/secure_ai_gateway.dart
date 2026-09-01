import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// A production-ready gateway for all AI interactions[cite: 9].
/// By routing LLM requests through Firebase Cloud Functions rather than 
/// calling Gemini directly from the client device, we ensure[cite: 9]:
/// 1. Zero API key exposure to client-side reverse engineering[cite: 9].
/// 2. Server-side request sanitization and PII protection before touching the LLM[cite: 9].
/// 3. Centralized rate limiting, margin protection, and abuse prevention.
class SecureAIGateway {
  // Singleton instance
  static final SecureAIGateway _instance = SecureAIGateway._internal();
  factory SecureAIGateway() => _instance;
  SecureAIGateway._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Processes a user's text or transcribed thought through Firebase Cloud Functions[cite: 1, 9]
  /// and returns a structured Cognitive Behavioral Therapy (CBT) insight map[cite: 1, 9].
  Future<Map<String, dynamic>> generateCBTReframe({
    required String userText,
    bool isVoiceTranscribed = false,
  }) async {
    final cleanInput = userText.trim();
    if (cleanInput.isEmpty) {
      throw Exception("Input cannot be empty. Please enter or speak your thoughts.");
    }

    try {
      // Points directly to the exported Cloud Function 'generateCBTReframe'
      final HttpsCallable callable = _functions.httpsCallable(
        'generateCBTReframe',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      // Payload matching the schema in ai_gateway.ts
      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'userText': cleanInput,
        'isVoiceTranscribed': isVoiceTranscribed,
      });

      if (result.data != null && result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      } else {
        throw Exception("Invalid data format received from AI Gateway.");
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint("🚨 [FirebaseFunctionsException] Code: ${e.code} | Message: ${e.message}");
      debugPrint("Details: ${e.details}");

      switch (e.code) {
        case 'unauthenticated':
          throw Exception("Authentication required. Please sign in to reframe your thoughts.");
        case 'resource-exhausted':
          throw Exception("Service is busy with high traffic. Please try again in a moment.");
        case 'invalid-argument':
          throw Exception("Invalid input provided. Please try rephrasing your thought.");
        case 'unavailable':
          throw Exception("The service is temporarily offline. Please check your internet connection.");
        default:
          throw Exception(e.message ?? "Failed to generate CBT insight. Please try again.");
      }
    } on TimeoutException catch (_) {
      debugPrint("🚨 [AI Gateway Timeout]: Generation exceeded 30s threshold.");
      throw Exception("Request timed out. Please check your connection and try again.");
    } catch (e) {
      debugPrint("🚨 [SecureAIGateway Unexpected Error]: $e");
      throw Exception("An unexpected error occurred while processing your session.");
    }
  }

  /// Processes biometric data (heart rate variance, tremor frequencies)[cite: 9]
  /// to request an adaptive somatic grounding rhythm from the server[cite: 9].
  Future<Map<String, dynamic>> generateSomaticGroundingRhythm({
    required double tremorFrequency,
    required int baselineHeartRate,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'generateSomaticRhythm',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 15),
        ),
      );

      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'tremor_freq': tremorFrequency,
        'bpm': baselineHeartRate,
      });

      if (result.data != null && result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      } else {
        throw Exception("Invalid somatic rhythm format.");
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint("🚨 [Somatic Gateway Error]: ${e.message}");
      throw Exception(e.message ?? "Failed to sync somatic grounding rhythm.");
    } catch (e) {
      debugPrint("🚨 [Somatic Gateway Unexpected Error]: $e");
      throw Exception("Could not initialize grounding session.");
    }
  }
}