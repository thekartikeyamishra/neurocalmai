import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../settings/providers/language_provider.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GenerativeModel? _model;

  // 🚨 COST OPTIMIZER: Maximum previous messages to send. 
  // 4 turns (2 user, 2 AI) is enough for CBT context without burning tokens.
  static const int _maxHistoryTurns = 4; 

  GeminiService._internal() {
    _initModel();
  }

  void _initModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('🚨 CRITICAL: GEMINI_API_KEY not found in .env');
      return;
    }

    // 🚨 COST OPTIMIZER: Use flash instead of pro/latest. 
    // gemini-1.5-flash is extremely cheap and incredibly fast for JSON tasks.
    _model = GenerativeModel(
      model: 'gemini-1.5-flash', 
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4, // Lowered slightly for more concise, less rambling output (saves output tokens)
        maxOutputTokens: 150, // Reduced from 250: forces the AI to be brief and saves money
        responseMimeType: 'application/json', // Forces strict JSON output
      ),
    );
  }

  String _getSystemPrompt(String dialect) {
    // 🚨 COST OPTIMIZER: Minimized system prompt. Every word here costs tokens on every single turn.
    return '''
    You are NeuroCalm, a CBT assistant.
    Rules: Validate emotions, be very brief, no medical diagnoses. Reply in $dialect. JSON keys must be English.
    {
      "reply": "Empathetic localized response",
      "slm_features": {
        "detected_emotion": "anxiety|sadness|anger|neutral",
        "cognitive_distortion": "catastrophizing|black_and_white_thinking|none",
        "urgency_level": "low|medium|high"
      }
    }''';
  }

  /// Processes Text Chat directly via Gemini
  Future<Map<String, dynamic>> generateTextReply(
    String userMessage, 
    List<Map<String, String>> history, 
    AppLanguage language
  ) async {
    if (_model == null) throw Exception("Gemini not initialized.");

    // 🚨 ZERO-COST INTERCEPTOR: Do not call LLM for basic pleasantries or 1-word agreements
    final normalizedMsg = userMessage.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    if (normalizedMsg == 'hi' || normalizedMsg == 'hello' || normalizedMsg == 'hey') {
      return _getFreeFallbackReply("Hello. How are you feeling right now?");
    }
    if (normalizedMsg == 'ok' || normalizedMsg == 'okay' || normalizedMsg == 'thanks' || normalizedMsg == 'thank you') {
      return _getFreeFallbackReply("I'm here whenever you're ready to share more.");
    }

    // 🚨 COST OPTIMIZER: Sliding Window. Only take the last N messages to prevent exponential token costs.
    final recentHistory = history.length > _maxHistoryTurns 
        ? history.sublist(history.length - _maxHistoryTurns) 
        : history;

    final prompt = [
      Content.system(_getSystemPrompt(language.displayName)),
      ...recentHistory.map((h) => Content(h['role'] == 'user' ? 'user' : 'model', [TextPart(h['content'] ?? '')])),
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
        Content.system(_getSystemPrompt(language.displayName)),
        Content.multi([
          DataPart('audio/mp4', audioBytes),
          TextPart("Transcribe the audio and provide the CBT response."),
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
      // Clean potential markdown blocks hallucinaton
      final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanText);
    } catch (e) {
      debugPrint('[Gemini Parse Error]: $e\nRaw Output: $text');
      return _getFreeFallbackReply("I am here for you. Please tell me more.");
    }
  }

  // Local helper for zero-cost routing and error states
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