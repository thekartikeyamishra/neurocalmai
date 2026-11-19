import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../safety/crisis_support_sheet.dart';
import '../../features/monetization/widgets/out_of_reflections_sheet.dart';
import 'wallet_service.dart';

/// Thrown when the free daily allowance and credits are exhausted.
class OutOfReflectionsException implements Exception {
  final String message;
  OutOfReflectionsException([this.message = 'Your free reflections for today are used up.']);
  @override
  String toString() => message;
}

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

    // Model choice, fallbacks and cost limits now live on the server
    // (functions/src/ai.ts). The client never names a model, so a retired
    // model is fixed with a server deploy instead of a Play Store release.
    try {
      final result = await _executeCbtCallWithRetry(
        cleanInput: cleanInput,
        isVoiceTranscribed: isVoiceTranscribed,
      );
      if (result['crisis'] == true) CrisisSupport.show();
      return result;
    } catch (error) {
      debugPrint("🚨 [AI Gateway]: CBT reframe failed: $error");
      _handleGatewayException(error);
    }
  }

  /// Conversational reply for journals, chat and voice (metered on server:
  /// free daily allowance -> credits -> premium). Replaces the old
  /// client-side Gemini/OpenAI calls whose API keys shipped inside the APK.
  Future<Map<String, dynamic>> generateTherapyReply({
    String message = '',
    List<Map<String, String>> history = const [],
    String language = 'English',
    String? audioBase64,
    String audioMime = 'audio/mp4',
  }) async {
    await _ensureAuthenticated();
    final callable = _functions.httpsCallable(
      'aiTherapyReply',
      options: HttpsCallableOptions(timeout: Duration(seconds: audioBase64 != null ? 60 : 30)),
    );
    try {
      final result = await callable.call<dynamic>(<String, dynamic>{
        'message': message.length > 1200 ? message.substring(0, 1200) : message,
        'history': history.length > 4 ? history.sublist(history.length - 4) : history,
        'language': language,
        if (audioBase64 != null) 'audioBase64': audioBase64,
        if (audioBase64 != null) 'audioMime': audioMime,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      WalletService().applyMeterUpdate(
        freeRemaining: (data['freeRemaining'] as num?)?.toInt(),
        balance: (data['balance'] as num?)?.toInt(),
      );
      if (data['crisis'] == true) CrisisSupport.show();
      if (data['slm_features'] is Map) {
        data['slm_features'] = Map<String, dynamic>.from(data['slm_features'] as Map);
      }
      return data;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final reason = details is Map ? details['reason'] : null;
      if (e.code == 'resource-exhausted' && reason == 'credits') {
        OutOfReflectionsSheet.show();
        throw OutOfReflectionsException();
      }
      if (e.code == 'unauthenticated') {
        await _ensureAuthenticated(forceRefresh: true);
      }
      _handleGatewayException(e);
    } catch (e) {
      _handleGatewayException(e);
    }
  }

  /// Wraps [_executeCbtCall] with an automatic auth-refresh retry to eliminate
  /// transient 401/UNAUTHENTICATED errors without user interruption.
  Future<Map<String, dynamic>> _executeCbtCallWithRetry({
    required String cleanInput,
    required bool isVoiceTranscribed,
  }) async {
    try {
      return await _executeCbtCall(
        cleanInput: cleanInput,
        isVoiceTranscribed: isVoiceTranscribed,
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
        );
      }
      rethrow;
    }
  }

  /// Internal invocation handler for the Cloud Function endpoint.
  Future<Map<String, dynamic>> _executeCbtCall({
    required String cleanInput,
    required bool isVoiceTranscribed,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable(
      'generateCBTReframe',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );

    // Passes the newly injected modelName up to the Cloud Function
    final HttpsCallableResult result = await callable.call(<String, dynamic>{
      'userText': cleanInput,
      'isVoiceTranscribed': isVoiceTranscribed,
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
          // Safely intercept quota/billing errors mapped by the backend to present a user-friendly message.
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
          // Never surface raw backend errors (could leak provider details).
          throw Exception("Something went wrong on our side. Please try again in a moment.");
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