import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'remote_config_service.dart';

/// A production-ready gateway for all AI interactions.
/// Routes LLM requests through Firebase Cloud Functions to ensure zero API key
/// exposure, server-side sanitization, and resilient fallback routing.
class SecureAIGateway {
  // Singleton instance
  static final SecureAIGateway _instance = SecureAIGateway._internal();
  factory SecureAIGateway() => _instance;
  SecureAIGateway._internal();

  // Region explicitly pinned to match deployed Cloud Functions
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Guarantees the client holds an authenticated, active token prior to calling Cloud Functions.
  /// Uses silent anonymous authentication to avoid interrupting the user flow.
  Future<void> _ensureAuthenticated({bool forceRefresh = false}) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      try {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
        debugPrint('✅ [Auth]: User silently authenticated for AI Gateway.');
      } catch (e) {
        debugPrint('🚨 [Auth Error]: Failed silent sign-in: $e');
        throw Exception(
          'Could not securely authenticate with the AI gateway. '
          'Please verify that Anonymous Authentication is enabled in the Firebase Console.',
        );
      }
    }

    if (user != null) {
      // Force token retrieval/refresh to guarantee an active JWT is sent in headers
      await user.getIdToken(forceRefresh);
    }
  }

  /// Processes user text or voice transcripts through Firebase Cloud Functions
  /// and returns a structured Cognitive Behavioral Therapy (CBT) insight map.
  Future<Map<String, dynamic>> generateCBTReframe({
    required String userText,
    bool isVoiceTranscribed = false,
  }) async {
    final cleanInput = userText.trim();
    if (cleanInput.isEmpty) {
      throw Exception(
        "Input cannot be empty. Please enter or speak your thoughts.",
      );
    }

    // Ensure active auth session exists before attempting execution
    await _ensureAuthenticated();

    // 🚨 ARCHITECT FIX: Override deprecated Gemini models from Remote Config.
    // The gemini-1.5 and gemini-2.0 series have been sunset by Google.
    // We force an upgrade to the latest stable endpoints (gemini-3.8-flash & gemini-3.5-flash-lite).
    final String primaryModel = 'gemini-3.8-flash';
    final String fallbackModel = 'gemini-3.5-flash-lite';

    try {
      // 1. Primary attempt using the latest 3.8 Flash model
      return await _executeCbtCallWithRetry(
        cleanInput: cleanInput,
        isVoiceTranscribed: isVoiceTranscribed,
        modelName: primaryModel,
      );
    } catch (primaryError) {
      debugPrint(
        "⚠️ [AI Gateway]: Primary model ($primaryModel) failed: $primaryError. Attempting fallback ($fallbackModel)...",
      );

      // 2. Cascading fallback attempt using the 3.5 Flash-Lite model
      try {
        return await _executeCbtCallWithRetry(
          cleanInput: cleanInput,
          isVoiceTranscribed: isVoiceTranscribed,
          modelName: fallbackModel,
        );
      } catch (fallbackError) {
        debugPrint(
          "🚨 [AI Gateway]: Fallback model ($fallbackModel) also failed: $fallbackError",
        );
        _handleGatewayException(fallbackError);
      }
    }
  }

  /// Wraps [_executeCbtCall] with an automatic auth-refresh retry to eliminate
  /// transient 401/UNAUTHENTICATED errors without user interruption.
  Future<Map<String, dynamic>> _executeCbtCallWithRetry({
    required String cleanInput,
    required bool isVoiceTranscribed,
    required String modelName,
  }) async {
    try {
      return await _executeCbtCall(
        cleanInput: cleanInput,
        isVoiceTranscribed: isVoiceTranscribed,
        modelName: modelName,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        debugPrint(
          '⚠️ [AI Gateway]: Received unauthenticated code. Refreshing token and retrying once...',
        );
        await _ensureAuthenticated(forceRefresh: true);
        return await _executeCbtCall(
          cleanInput: cleanInput,
          isVoiceTranscribed: isVoiceTranscribed,
          modelName: modelName,
        );
      }
      rethrow;
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
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );

    // Passes the newly injected modelName up to the Cloud Function
    final HttpsCallableResult result = await callable.call(<String, dynamic>{
      'userText': cleanInput,
      'isVoiceTranscribed': isVoiceTranscribed,
      'model': modelName, 
    });

    if (result.data != null) {
      if (result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      } else if (result.data is String) {
        try {
          final decoded = jsonDecode(result.data as String);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          // Fall through to exception below
        }
      }
    }

    throw Exception("Invalid data format received from AI Gateway.");
  }

  /// Translates raw server and network errors into clean, user-facing error messages.
  Never _handleGatewayException(Object error) {
    if (error is FirebaseFunctionsException) {
      debugPrint(
        "🚨 [FirebaseFunctionsException] Code: ${error.code} | Message: ${error.message}",
      );

      switch (error.code) {
        case 'unauthenticated':
          throw Exception(
            "Session expired. Please restart the app to reconnect securely.",
          );
        case 'resource-exhausted':
          throw Exception(
            "Service is busy with high traffic. Please try again in a moment.",
          );
        case 'invalid-argument':
          throw Exception(
            "Invalid input provided. Please try rephrasing your thought.",
          );
        case 'not-found':
          throw Exception(
            "The selected AI service is temporarily unavailable. Please try again shortly.",
          );
        case 'unavailable':
          throw Exception(
            "The service is temporarily offline. Please check your internet connection.",
          );
        case 'internal':
          // Pass the exact backend exception to the UI for visibility instead of masking it
          throw Exception(error.message ?? "Failed to generate CBT insight. Please try again.");
        default:
          final msg = error.message ?? "";
          if (msg.contains("NOT_FOUND") || msg.contains("404")) {
            throw Exception(
              "The AI service route is currently updating. Please try again in a few moments.",
            );
          }
          throw Exception(
            msg.isNotEmpty
                ? msg
                : "Failed to generate CBT insight. Please try again.",
          );
      }
    } else if (error is TimeoutException) {
      debugPrint("🚨 [AI Gateway Timeout]: Generation exceeded 30s threshold.");
      throw Exception(
        "Request timed out. Please check your connection and try again.",
      );
    } else {
      final errorStr = error.toString();
      if (errorStr.contains("NOT_FOUND") || errorStr.contains("404")) {
        throw Exception(
          "The AI model endpoint is currently updating. Please try again in a few moments.",
        );
      }
      throw Exception(
        "An unexpected error occurred while processing your session.",
      );
    }
  }

  /// Processes biometric data (heart rate variance, tremor frequencies)
  /// to request an adaptive somatic grounding rhythm from the server.
  Future<Map<String, dynamic>> generateSomaticGroundingRhythm({
    required double tremorFrequency,
    required int baselineHeartRate,
  }) async {
    try {
      await _ensureAuthenticated();

      final HttpsCallable callable = _functions.httpsCallable(
        'generateSomaticRhythm',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
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
      if (e.code == 'unauthenticated') {
        // Retry once on unauthenticated
        await _ensureAuthenticated(forceRefresh: true);
        return generateSomaticGroundingRhythm(
          tremorFrequency: tremorFrequency,
          baselineHeartRate: baselineHeartRate,
        );
      }
      debugPrint("🚨 [Somatic Gateway Error]: ${e.message}");
      throw Exception(e.message ?? "Failed to sync somatic grounding rhythm.");
    } catch (e) {
      debugPrint("🚨 [Somatic Gateway Unexpected Error]: $e");
      throw Exception("Could not initialize grounding session.");
    }
  }
}