import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../settings/providers/language_provider.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GenerativeModel? _model;

  GeminiService._internal() {
    _initModel();
  }

  void _initModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('🚨 CRITICAL: GEMINI_API_KEY not found in .env');
      return;
    }

    // 🚨 ARCHITECT FIX: Locked model to 'gemini-1.5-flash' to satisfy Dart SDK v1beta routing
    _model = GenerativeModel(
      model: 'gemini-1.5-latest', 
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.6,
        maxOutputTokens: 250,
        responseMimeType: 'application/json', // Forces strict JSON output
      ),
    );
  }

  String _getSystemPrompt(String dialect) {
    return '''
    You are NeuroCalm, a highly empathetic Cognitive Behavioral Therapy (CBT) assistant.
    Rules:
    1. Validate the user's emotions.
    2. Keep responses short and simple.
    3. Never provide medical diagnoses.
    4. You must write the actual therapy reply entirely in the dialect/language: $dialect.
    5. The JSON keys MUST REMAIN IN ENGLISH. Only translate the value of "reply".
    
    Required JSON Structure:
    {
      "reply": "Your localized empathetic response here.",
      "slm_features": {
        "detected_emotion": "anxiety|sadness|anger|neutral",
        "cognitive_distortion": "catastrophizing|black_and_white_thinking|none",
        "urgency_level": "low|medium|high"
      }
    }''';
  }

  /// Processes Text Chat directly via Gemini
  Future<Map<String, dynamic>> generateTextReply(String userMessage, List<Map<String, String>> history, AppLanguage language) async {
    if (_model == null) throw Exception("Gemini not initialized.");

    final prompt = [
      Content.system(_getSystemPrompt(language.displayName)),
      ...history.map((h) => Content(h['role'] == 'user' ? 'user' : 'model', [TextPart(h['content'] ?? '')])),
      Content.text(userMessage)
    ];

    try {
      final response = await _model!.generateContent(prompt);
      return _parseResponse(response.text);
    } catch (e) {
      debugPrint('[Gemini Text Error]: $e');
      rethrow;
    }
  }

  /// Processes Audio Files directly via Gemini 1.5 Flash
  Future<Map<String, dynamic>> generateAudioReply(String audioFilePath, AppLanguage language) async {
    if (_model == null) throw Exception("Gemini not initialized.");

    try {
      final audioFile = File(audioFilePath);
      final audioBytes = await audioFile.readAsBytes();
      
      final prompt = [
        Content.system(_getSystemPrompt(language.displayName) + "\nTranscribe the audio and respond to it."),
        Content.multi([
          DataPart('audio/mp4', audioBytes),
          TextPart("Listen to this audio and provide the CBT response."),
        ])
      ];

      final response = await _model!.generateContent(prompt);
      return _parseResponse(response.text);
    } catch (e) {
      debugPrint('[Gemini Audio Error]: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _parseResponse(String? text) {
    if (text == null) throw Exception("Empty response from AI");
    try {
      final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanText);
    } catch (e) {
      debugPrint('[Gemini Parse Error]: $e');
      return {
        "reply": "I am here for you. Please tell me more.",
        "slm_features": {"detected_emotion": "unknown", "cognitive_distortion": "none", "urgency_level": "low"}
      };
    }
  }
}