import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../settings/providers/language_provider.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  
  static const int _maxHistoryTurns = 4;
  
  // 🚨 COST OPTIMIZATION: Max input character length (~150 words) to prevent token stuffing
  static const int _maxInputLength = 800; 

  GeminiService._internal();

  GenerativeModel _getModel(String dialect) {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('CRITICAL: GEMINI_API_KEY not found in .env');
    }
    return GenerativeModel(
      // 🚨 FIX: Upgraded from deprecated gemini-2.5-flash to the active gemini-3.5-flash model
      model: 'gemini-3.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(_getSystemPrompt(dialect)),
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 600,
        responseMimeType: 'application/json',
      ),
    );
  }

  String _getSystemPrompt(String dialect) {
    return '''
    You are NeuroCalm, a CBT assistant.
    Rules: Validate emotions, be very brief, no medical diagnoses. Reply in $dialect. JSON keys must be English.
    
    CRITICAL INSTRUCTION: You must output ONLY raw, valid JSON.
    DO NOT output markdown blocks (like ```json).
    
    {
      "reply": "Empathetic localized response",
      "slm_features": {
        "detected_emotion": "anxiety|sadness|anger|neutral",
        "cognitive_distortion": "catastrophizing|black_and_white_thinking|none",
        "urgency_level": "low|medium|high"
      }
    }''';
  }

  Future<Map<String, dynamic>> generateTextReply(
    String userMessage,
    List<Map<String, String>> history,
    AppLanguage language
  ) async {
    // ZERO-COST INTERCEPTOR
    final normalizedMsg = userMessage.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    if (normalizedMsg == 'hi' || normalizedMsg == 'hello') {
      return _getFreeFallbackReply("Hello. How are you feeling right now?");
    }

    // 🚨 TOKEN BUDGETING: Hard clip the input string before generation
    final safeMessage = userMessage.length > _maxInputLength 
        ? '${userMessage.substring(0, _maxInputLength)}...' 
        : userMessage;

    final recentHistory = history.length > _maxHistoryTurns
        ? history.sublist(history.length - _maxHistoryTurns)
        : history;

    final prompt = [
      ...recentHistory.map((h) => Content(h['role'] == 'user' ? 'user' : 'model', [TextPart(h['content'] ?? '')])),
      Content.text(safeMessage)
    ];

    try {
      final model = _getModel(language.displayName);
      final response = await model.generateContent(prompt);
      return _parseResponse(response.text);
    } catch (e) {
      debugPrint('[Gemini Text Error]: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateAudioReply(String audioFilePath, AppLanguage language) async {
    try {
      final audioFile = File(audioFilePath);
      if (!await audioFile.exists()) throw Exception("Audio file not found.");

      final audioBytes = await audioFile.readAsBytes();
      final prompt = [
        Content.multi([
          DataPart('audio/mp4', audioBytes),
          TextPart("Transcribe the audio and provide the CBT response. Output ONLY valid JSON."),
        ])
      ];

      final model = _getModel(language.displayName);
      final response = await model.generateContent(prompt);
      return _parseResponse(response.text);
    } catch (e) {
      debugPrint('[Gemini Audio Error]: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _parseResponse(String? text) {
    if (text == null) throw Exception("Empty response");
    try {
      String cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final RegExp jsonRegex = RegExp(r'\{[\s\S]*\}');
      final match = jsonRegex.firstMatch(cleanText);
      if (match != null) return jsonDecode(match.group(0)!);
      throw const FormatException("No JSON structure found.");
    } catch (e) {
      return _getFreeFallbackReply("I am here for you. Please tell me more.");
    }
  }

  Map<String, dynamic> _getFreeFallbackReply(String replyText) {
    return {
      "reply": replyText,
      "slm_features": {
        "detected_emotion": "neutral",
        "cognitive_distortion": "none",
        "urgency_level": "low"
      }
    };
  }
}