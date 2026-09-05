import 'dart:convert';
import 'dart:typed_data'; // Handles raw binary audio streams
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../../../core/services/secure_ai_gateway.dart';

/// Production-ready service managing multimodal AI pipelines (OpenAI & Gemini Gateway)[cite: 10, 11].
/// Built with cascading failovers to ensure uninterrupted therapy sessions 
/// even during third-party model deprecations or API outages[cite: 11].
class OpenAIService {
  // Singleton Pattern for efficient network resource management[cite: 11]
  static final OpenAIService instance = OpenAIService._internal();
  late final Dio _dio;

  OpenAIService._internal() {
    // 20-second timeout ensures rural and low-bandwidth users have sufficient time[cite: 11]
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ));
  }

  /// Extracts the OpenAI API key safely from .env[cite: 11]
  String get _apiKey {
    final key = dotenv.env['OPENAI_API_KEY'] ?? '';
    return key.trim();
  }

  /// Dynamic model selection backed by Firebase Remote Config
  String get _primaryChatModel {
    try {
      final remoteModel = FirebaseRemoteConfig.instance.getString('openai_chat_model');
      if (remoteModel.isNotEmpty) return remoteModel;
    } catch (_) {}
    return 'gpt-4o-mini'; // High performance, low token latency[cite: 11]
  }

  String get _fallbackChatModel {
    try {
      final fallback = FirebaseRemoteConfig.instance.getString('openai_fallback_model');
      if (fallback.isNotEmpty) return fallback;
    } catch (_) {}
    return 'gpt-4o'; // Secondary fallback if 4o-mini undergoes maintenance
  }

  /// Maps frontend dialect strings to OpenAI Whisper's required ISO-639-1 format[cite: 11]
  String _getWhisperLangCode(String dialect) {
    final lower = dialect.toLowerCase();
    if (lower.contains('hindi') || lower.contains('bhojpuri')) return 'hi';
    if (lower.contains('tamil')) return 'ta';
    if (lower.contains('marathi')) return 'mr';
    if (lower.contains('bengali')) return 'bn';
    if (lower.contains('telugu')) return 'te';
    return 'en'; // Default to English[cite: 11]
  }

  // ===========================================================================
  // 1. SPEECH-TO-TEXT PIPELINE (Whisper-1)[cite: 11]
  // ===========================================================================
  Future<String> transcribeAudio(String filePath, String dialect) async {
    if (_apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY is not configured.');
    }

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: 'audio.m4a'),
        'model': 'whisper-1',
        'language': _getWhisperLangCode(dialect),
      });

      final response = await _dio.post(
        'https://api.openai.com/v1/audio/transcriptions',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      return response.data['text'] ?? '';
      
    } on DioException catch (e) {
      debugPrint('[Whisper Network Error]: ${e.response?.data ?? e.message}');
      throw Exception('Could not understand the audio due to network issues.');
    } catch (e) {
      debugPrint('[Whisper System Error]: $e');
      throw Exception('Unexpected error during audio transcription.');
    }
  }

  // ===========================================================================
  // 2. COGNITIVE BEHAVIORAL THERAPY PIPELINE (CASCADING RESILIENCE)
  // ===========================================================================
  Future<Map<String, dynamic>> generateTherapyResponse(
    String userMessage, 
    List<Map<String, String>> history, 
    String dialect,
  ) async {
    // 1. If OpenAI key is present, attempt primary cloud-configured model
    if (_apiKey.isNotEmpty) {
      try {
        return await _executeOpenAiChat(
          userMessage: userMessage,
          history: history,
          dialect: dialect,
          model: _primaryChatModel,
        );
      } catch (primaryError) {
        debugPrint('⚠️ [OpenAI Chat Primary Failed]: $primaryError. Trying fallback model ($_fallbackChatModel)...');
        
        // 2. Secondary OpenAI fallback model attempt
        try {
          return await _executeOpenAiChat(
            userMessage: userMessage,
            history: history,
            dialect: dialect,
            model: _fallbackChatModel,
          );
        } catch (secondaryError) {
          debugPrint('⚠️ [OpenAI Chat Secondary Failed]: $secondaryError');
        }
      }
    }

    // 3. Redundancy: Cascade directly to SecureAIGateway (Gemini)[cite: 10]
    try {
      debugPrint('🔄 [OpenAIService]: Cascading to SecureAIGateway backup...');
      final cbtResult = await SecureAIGateway().generateCBTReframe(
        userText: userMessage,
        isVoiceTranscribed: false,
      );

      final reframe = cbtResult['reframe']?.toString() ?? cbtResult['action']?.toString();
      final distortion = cbtResult['distortion']?.toString() ?? 'none';

      if (reframe != null && reframe.isNotEmpty) {
        return {
          "reply": reframe,
          "slm_features": {
            "detected_emotion": distortion != 'none' ? "anxiety" : "neutral",
            "cognitive_distortion": distortion,
            "urgency_level": "medium",
          }
        };
      }
    } catch (gatewayError) {
      debugPrint('🚨 [SecureAIGateway Backup Error]: $gatewayError');
    }

    // 4. Safe offline/failsafe response to prevent UI crashes[cite: 11]
    return _getFallbackResponse();
  }

  /// Internal caller for OpenAI chat completions endpoint
  Future<Map<String, dynamic>> _executeOpenAiChat({
    required String userMessage,
    required List<Map<String, String>> history,
    required String dialect,
    required String model,
  }) async {
    final systemPrompt = '''
You are NeuroCalm, a highly empathetic Cognitive Behavioral Therapy (CBT) assistant.
Rules:
1. Validate the user's emotions.
2. Keep responses short and simple (under 3 sentences) to prevent cognitive overload.
3. Never provide medical diagnoses.
4. You must write the actual therapy reply entirely in the dialect/language: $dialect.
5. The JSON keys MUST REMAIN IN ENGLISH.

Required JSON Structure:
{
  "reply": "Your localized empathetic response here.",
  "slm_features": {
    "detected_emotion": "anxiety|sadness|anger|neutral",
    "cognitive_distortion": "catastrophizing|black_and_white_thinking|none",
    "urgency_level": "low|medium|high"
  }
}''';

    final List<Map<String, dynamic>> messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history.map((h) => {
        'role': h['role'] == 'user' ? 'user' : 'assistant', 
        'content': h['content']
      }),
      {'role': 'user', 'content': userMessage}
    ];

    final response = await _dio.post(
      'https://api.openai.com/v1/chat/completions',
      data: {
        'model': model,
        'messages': messages,
        'max_tokens': 250,
        'temperature': 0.6,
        'response_format': {'type': 'json_object'},
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );

    final rawContent = response.data['choices'][0]['message']['content'];
    final sanitizedJson = _sanitizeJson(rawContent.toString());
    return jsonDecode(sanitizedJson) as Map<String, dynamic>;
  }

  /// Defensively sanitizes JSON strings in case markdown blocks are returned
  String _sanitizeJson(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }

  // ===========================================================================
  // 3. TEXT-TO-SPEECH PIPELINE (Hyper-Realistic Human Voice)[cite: 11]
  // ===========================================================================
  Future<Uint8List> generateSpeechAudio(String text) async {
    if (_apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY is missing from environment.');
    }

    try {
      final response = await _dio.post(
        '[https://api.openai.com/v1/audio/speech](https://api.openai.com/v1/audio/speech)',
        data: {
          'model': 'tts-1',
          'input': text,
          'voice': 'nova', // Warm, empathetic therapeutic tone[cite: 11]
          'response_format': 'mp3',
        },
        options: Options(
          responseType: ResponseType.bytes, // Binary byte stream[cite: 11]
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      return Uint8List.fromList(response.data);

    } on DioException catch (e) {
      debugPrint('[OpenAI TTS Error]: ${e.response?.data ?? e.message}');
      throw Exception('Failed to generate human voice audio.');
    } catch (e) {
      debugPrint('[OpenAI TTS System Error]: $e');
      throw Exception('Unexpected error during audio generation.');
    }
  }

  // ===========================================================================
  // 4. FAILSAFE RESPONSES[cite: 11]
  // ===========================================================================
  Map<String, dynamic> _getFallbackResponse() {
    return {
      "reply": "I hear how heavy this feels. Take a slow, grounding breath with me. What is one small thing right in front of you right now?",
      "slm_features": {
        "detected_emotion": "anxiety", 
        "cognitive_distortion": "none", 
        "urgency_level": "low"
      }
    };
  }
}