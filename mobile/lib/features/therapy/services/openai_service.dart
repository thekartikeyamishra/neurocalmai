import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../../../core/services/secure_ai_gateway.dart';

/// Backwards-compatible facade (name kept so existing screens compile).
///
/// SECURITY/COST FIX: the old implementation called OpenAI from the device
/// with `OPENAI_API_KEY` bundled in the APK, and its TTS endpoint URL was
/// malformed. Everything now routes through the server gateway, which owns
/// keys, models, quotas and crisis safety. Rotate the OpenAI key after this
/// release ships — any key that was ever in an APK must be considered leaked.
class OpenAIService {
  static final OpenAIService instance = OpenAIService._internal();
  OpenAIService._internal();

  Future<Map<String, dynamic>> generateTherapyResponse(
    String userMessage,
    List<Map<String, String>> history,
    String dialect,
  ) async {
    try {
      final data = await SecureAIGateway().generateTherapyReply(
        message: userMessage,
        history: history,
        language: dialect,
      );
      final features = data['slm_features'] is Map
          ? Map<String, dynamic>.from(data['slm_features'] as Map)
          : <String, dynamic>{};
      return {
        'reply': data['reply'] ?? _fallback['reply'],
        'slm_features': {
          'detected_emotion': features['detected_emotion'] ?? 'neutral',
          'cognitive_distortion': features['cognitive_distortion'] ?? 'none',
          'urgency_level': features['urgency_level'] ?? 'low',
        },
        if (data['crisis'] == true) 'crisis': true,
      };
    } on OutOfReflectionsException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ [TherapyFacade]: $e');
      return Map<String, dynamic>.from(_fallback);
    }
  }

  /// Transcription now happens server-side inside `aiTherapyReply`.
  Future<String> transcribeAudio(String filePath, String dialect) async {
    throw UnsupportedError('Use GeminiService.generateAudioReply (server-side transcription).');
  }

  /// Device TTS (flutter_tts) is used instead: free, offline and private.
  Future<Uint8List> generateSpeechAudio(String text) async {
    throw UnsupportedError('Cloud TTS disabled; use on-device TTS.');
  }

  static const Map<String, dynamic> _fallback = {
    'reply': 'I hear how heavy this feels. Take a slow, grounding breath with me. '
        'What is one small thing right in front of you right now?',
    'slm_features': {
      'detected_emotion': 'anxiety',
      'cognitive_distortion': 'none',
      'urgency_level': 'low',
    },
  };
}
