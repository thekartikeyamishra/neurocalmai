import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'remote_config_service.dart';

/// A production-ready gateway for all AI interactions[cite: 10].
/// By routing LLM requests through Firebase Cloud Functions rather than 
/// calling Gemini directly from the client device, we ensure[cite: 10]:
/// 1. Zero API key exposure to client-side reverse engineering[cite: 10].
/// 2. Server-side request sanitization and PII protection before touching the LLM[cite: 10].
/// 3. Resilient model routing via Firebase Remote Config with automatic fallback switching.
class SecureAIGateway {
  // Singleton instance
  static final SecureAIGateway _instance = SecureAIGateway._internal();
  factory SecureAIGateway() => _instance;
  SecureAIGateway._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Processes a user's text or transcribed thought through Firebase Cloud Functions[cite: 10]
  /// and returns a structured Cognitive Behavioral Therapy (CBT) insight map[cite: 10].
  ///
  /// Uses [RemoteConfigService] to dynamically select the model and cascades
  /// to the fallback model if a 404 or backend failure occurs.
  Future<Map<String, dynamic>> generateCBTReframe({
    required String userText,
    bool isVoiceTranscribed = false,
  }) async {
    final cleanInput = userText.trim();
    if (cleanInput.isEmpty) {
      throw Exception("Input cannot be empty. Please enter or speak your thoughts.");
    }

    final primaryModel = RemoteConfigService().primaryAiModel;
    final fallbackModel = RemoteConfigService().fallbackAiModel;

    try {
      // 1. Primary Attempt using the active Cloud-configured model
      return await _executeCbtCall(
        cleanInput: cleanInput,
        isVoiceTranscribed: isVoiceTranscribed,
        modelName: primaryModel,
      );
    } catch (primaryError) {
      debugPrint("⚠️ [AI Gateway]: Primary model ($primaryModel) failed: $primaryError. Attempting fallback ($fallbackModel)...");

      // 2. Cascading Fallback Attempt if primary fails or returns 404
      try {
        return await _executeCbtCall(
          cleanInput: cleanInput,
          isVoiceTranscribed: isVoiceTranscribed,
          modelName: fallbackModel,
        );
      } catch (fallbackError) {
        debugPrint("🚨 [AI Gateway]: Fallback model ($fallbackModel) also failed: $fallbackError");
        _handleGatewayException(fallbackError);
      }
    }
  }

  /// Internal invocation handler for the Cloud Function endpoint.
  Future<Map<String, dynamic>> _executeCbtCall({
    required String cleanInput,
    required bool isVoiceTranscribed,
    required String modelName,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable(
      'generateCBTReframe',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 30),
      ),
    );

    final HttpsCallableResult result = await callable.call(<String, dynamic>{
      'userText': cleanInput,
      'isVoiceTranscribed': isVoiceTranscribed,
      'model': modelName,
    });

    if (result.data != null && result.data is Map) {
      return Map<String, dynamic>.from(result.data as Map);
    } else {
      throw Exception("Invalid data format received from AI Gateway.");
    }
  }

  /// Translates raw server and network errors into clean, user-facing error messages.
  Never _handleGatewayException(Object error) {
    if (error is FirebaseFunctionsException) {
      debugPrint("🚨 [FirebaseFunctionsException] Code: ${error.code} | Message: ${error.message}");
      debugPrint("Details: ${error.details}");

      switch (error.code) {
        case 'unauthenticated':
          throw Exception("Authentication required. Please sign in to reframe your thoughts.");
        case 'resource-exhausted':
          throw Exception("Service is busy with high traffic. Please try again in a moment.");
        case 'invalid-argument':
          throw Exception("Invalid input provided. Please try rephrasing your thought.");
        case 'not-found':
          throw Exception("The selected AI service is temporarily unavailable. Please try again shortly.");
        case 'unavailable':
          throw Exception("The service is temporarily offline. Please check your internet connection.");
        default:
          final msg = error.message ?? "";
          if (msg.contains("NOT_FOUND") || msg.contains("404")) {
            throw Exception("The AI service route is currently updating. Please try again in a few moments.");
          }
          throw Exception(msg.isNotEmpty ? msg : "Failed to generate CBT insight. Please try again.");
      }
    } else if (error is TimeoutException) {
      debugPrint("🚨 [AI Gateway Timeout]: Generation exceeded 30s threshold.");
      throw Exception("Request timed out. Please check your connection and try again.");
    } else {
      final errorStr = error.toString();
      if (errorStr.contains("NOT_FOUND") || errorStr.contains("404")) {
        throw Exception("The AI model endpoint is currently updating. Please try again in a few moments.");
      }
      throw Exception("An unexpected error occurred while processing your session.");
    }
  }

  /// Processes biometric data (heart rate variance, tremor frequencies)[cite: 10]
  /// to request an adaptive somatic grounding rhythm from the server[cite: 10].
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