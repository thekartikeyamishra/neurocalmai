import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../core/safety/crisis_detector.dart';
import '../../../core/safety/crisis_support_sheet.dart';
import '../../../core/services/secure_ai_gateway.dart';
import '../../settings/providers/language_provider.dart';

/// Conversational CBT replies for journals, chat and voice.
///
/// SECURITY/COST FIX: this used to call Gemini directly from the phone with
/// `GEMINI_API_KEY` bundled inside the APK (`.env` is a Flutter asset, so
/// anyone could unzip the APK and bill your Google account). All calls now
/// go through the `aiTherapyReply` Cloud Function, which owns the key, the
/// model chain, input limits, crisis safety and per-user quotas.
/// Public method signatures are unchanged so no screen had to change.
class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  static const int _maxHistoryTurns = 4;
  static const int _maxInputLength = 1200;
  // Simple per-session cache so repeated identical inputs cost nothing.
  final Map<String, Map<String, dynamic>> _cache = {};

  Future<Map<String, dynamic>> generateTextReply(
    String userMessage,
    List<Map<String, String>> history,
    AppLanguage language,
  ) async {
    final normalized = userMessage.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    if (normalized.isEmpty) {
      return _fallback("Take your time. What's on your mind right now?");
    }
    if (const {'hi', 'hello', 'hey', 'namaste'}.contains(normalized)) {
      return _fallback('Hello. How are you feeling right now?');
    }

    if (CrisisDetector.isCrisis(userMessage)) {
      // Safety first, and it works offline: no model call needed.
      CrisisSupport.show();
      return {
        ..._fallback("I'm really glad you told me. You deserve support from a real person right now — "
            "please reach out to one of the helplines on screen or someone you trust."),
        'crisis': true,
      };
    }

    final safeMessage = userMessage.length > _maxInputLength
        ? userMessage.substring(0, _maxInputLength)
        : userMessage;
    final recentHistory = history.length > _maxHistoryTurns
        ? history.sublist(history.length - _maxHistoryTurns)
        : history;

    final cacheKey = '${language.displayName}|$normalized';
    if (recentHistory.isEmpty && _cache.containsKey(cacheKey)) {
      return Map<String, dynamic>.from(_cache[cacheKey]!);
    }

    try {
      final result = await SecureAIGateway().generateTherapyReply(
        message: safeMessage,
        history: recentHistory,
        language: language.displayName,
      );
      final normalizedResult = _normalize(result);
      if (recentHistory.isEmpty && normalizedResult['crisis'] != true) {
        if (_cache.length > 30) _cache.remove(_cache.keys.first);
        _cache[cacheKey] = normalizedResult;
      }
      return normalizedResult;
    } on OutOfReflectionsException {
      rethrow; // The out-of-reflections sheet is already on screen.
    } catch (e) {
      debugPrint('[AI Text Error]: $e');
      return _offlineFallback();
    }
  }

  Future<Map<String, dynamic>> generateAudioReply(String audioFilePath, AppLanguage language) async {
    final audioFile = File(audioFilePath);
    try {
      if (!await audioFile.exists()) throw Exception('Audio file not found.');
      final bytes = await audioFile.readAsBytes();
      if (bytes.isEmpty) return _fallback("I couldn't hear anything. Try again a little closer to the mic?");
      final result = await SecureAIGateway().generateTherapyReply(
        language: language.displayName,
        audioBase64: base64Encode(bytes),
        audioMime: 'audio/mp4',
      );
      return _normalize(result);
    } on OutOfReflectionsException {
      rethrow;
    } catch (e) {
      debugPrint('[AI Audio Error]: $e');
      return _offlineFallback();
    } finally {
      // Privacy: never leave voice recordings lying around on disk.
      try {
        if (await audioFile.exists()) await audioFile.delete();
      } catch (_) {}
    }
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final features = data['slm_features'] is Map
        ? Map<String, dynamic>.from(data['slm_features'] as Map)
        : <String, dynamic>{};
    return {
      'reply': (data['reply'] as String?)?.trim().isNotEmpty == true
          ? data['reply']
          : 'I am here for you. Please tell me more.',
      'slm_features': {
        'detected_emotion': features['detected_emotion'] ?? 'neutral',
        'cognitive_distortion': features['cognitive_distortion'] ?? 'none',
        'urgency_level': features['urgency_level'] ?? 'low',
      },
      if (data['transcript'] != null) 'transcript': data['transcript'],
      if (data['crisis'] == true) 'crisis': true,
    };
  }

  /// Works with zero network: a real CBT micro-exercise, not an error.
  Map<String, dynamic> _offlineFallback() => _fallback(
        "I couldn't reach the AI just now, but you can still do this: name the thought in one line, "
        "rate how true it feels (0–10), then write one piece of evidence against it. "
        "Your entry is saved on this device.",
      );

  Map<String, dynamic> _fallback(String replyText) {
    return {
      'reply': replyText,
      'slm_features': {
        'detected_emotion': 'neutral',
        'cognitive_distortion': 'none',
        'urgency_level': 'low',
      },
    };
  }
}
