import 'dart:convert';
import 'dart:typed_data'; // 🚨 NEW IMPORT: For handling raw binary audio streams
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  // Singleton Pattern for efficient network resource management
  static final OpenAIService instance = OpenAIService._internal();
  late final Dio _dio;

  OpenAIService._internal() {
    // 20-second timeout ensures rural users have time to upload/download audio payloads
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ));
  }

  /// Securely extracts the API key directly from the .env vault
  String get _apiKey {
    final key = dotenv.env['OPENAI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('CRITICAL: OPENAI_API_KEY is missing from .env file.');
    }
    return key;
  }

  /// Maps the frontend dialect string to OpenAI Whisper's required ISO-639-1 format
  String _getWhisperLangCode(String dialect) {
    final lower = dialect.toLowerCase();
    if (lower.contains('hindi') || lower.contains('bhojpuri')) return 'hi';
    if (lower.contains('tamil')) return 'ta';
    if (lower.contains('marathi')) return 'mr';
    if (lower.contains('bengali')) return 'bn';
    if (lower.contains('telugu')) return 'te';
    return 'en'; // Default to English
  }

  // ===========================================================================
  // 1. SPEECH-TO-TEXT PIPELINE (Whisper-1)
  // ===========================================================================
  Future<String> transcribeAudio(String filePath, String dialect) async {
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
  // 2. COGNITIVE BEHAVIORAL THERAPY PIPELINE (GPT-4o-mini)
  // ===========================================================================
  Future<Map<String, dynamic>> generateTherapyResponse(String userMessage, List<Map<String, String>> history, String dialect) async {
    try {
      // Psychological System Prompt enforcing CBT rules and strict JSON structure
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

      // Map Flutter chat history to OpenAI's required Message format
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
          'model': 'gpt-4o-mini', // Highest speed, lowest cost per token
          'messages': messages,
          'max_tokens': 250, // Strict governance to prevent API billing abuse
          'temperature': 0.6, // Low temperature for clinical consistency
          'response_format': {'type': 'json_object'}, // Enforces valid JSON
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      final rawContent = response.data['choices'][0]['message']['content'];
      return jsonDecode(rawContent);

    } on DioException catch (e) {
      debugPrint('[OpenAI API Error]: ${e.response?.data ?? e.message}');
      return _getFallbackResponse();
    } catch (e) {
      debugPrint('[OpenAI Parse Error]: $e');
      return _getFallbackResponse();
    }
  }

  // ===========================================================================
  // 3. TEXT-TO-SPEECH PIPELINE (Hyper-Realistic Human Voice)
  // ===========================================================================
  /// Generates a warm, empathetic human voice payload as raw MP3 bytes
  Future<Uint8List> generateSpeechAudio(String text) async {
    try {
      final response = await _dio.post(
        'https://api.openai.com/v1/audio/speech',
        data: {
          'model': 'tts-1', // Optimized for speed/lowest latency
          'input': text,
          'voice': 'nova', // 'nova' is statistically the warmest, most empathetic voice
          'response_format': 'mp3',
        },
        options: Options(
          // CRITICAL: Tells Dio not to parse as JSON, but to return the raw byte stream
          responseType: ResponseType.bytes, 
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      // Return the raw binary array for our local AudioPlaybackService
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
  // 4. FAILSAFE MECHANISMS
  // ===========================================================================
  /// Guarantees the UI never crashes by supplying a perfectly formatted fallback object
  Map<String, dynamic> _getFallbackResponse() {
    return {
      "reply": "I'm having trouble connecting right now. Take a deep breath, I am still here.",
      "slm_features": {
        "detected_emotion": "unknown", 
        "cognitive_distortion": "none", 
        "urgency_level": "low"
      }
    };
  }
}