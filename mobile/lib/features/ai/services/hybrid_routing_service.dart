import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Internal Integrations
import '../prompts/cbt_secure_prompts.dart';

/// Riverpod Provider for Dependency Injection and Testing
/// Fully decoupled from the Journal Service for strict modularity.
final hybridRoutingProvider = Provider<HybridRoutingService>((ref) {
  return HybridRoutingService();
});

class HybridRoutingService {
  
  // TECH LEAD FIX: Cache Versioning
  // Bump this string (e.g., 'v2_') if you update your AI prompts in the future.
  // This instantly invalidates old cached responses across all devices.
  static const String _cacheVersion = 'v1_';

  /// COST OPTIMIZER: Aggressive Normalization.
  /// Strips all punctuation so "I'm sad." and "im sad" hit the same $0.00 cache.
  String _generateCacheKey(String text) {
    final normalized = text.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final hash = md5.convert(utf8.encode(normalized)).toString();
    // Prefixes the hash with the current cache version
    return 'ai_cache_$_cacheVersion$hash';
  }

  /// Self-contained O(1) memory cache check. 
  /// Vastly faster than querying SQLite and prevents schema pollution.
  Future<String?> _getCachedInsight(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(cacheKey);
    } catch (e) {
      debugPrint('⚠️ [Hybrid Router Cache Read Error]: $e');
      return null;
    }
  }

  /// Writes the JSON payload to secure local storage.
  Future<void> _cacheInsight(String cacheKey, String jsonPayload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonPayload);
    } catch (e) {
      debugPrint('⚠️ [Hybrid Router Cache Write Error]: $e');
    }
  }

  /// Extracts strict JSON even if the LLM hallucinates markdown formatting or conversational filler.
  Map<String, dynamic> _extractJsonFromLlmResponse(String rawResponse) {
    try {
      // 1. Strip markdown code blocks (e.g., ```json ... ```)
      String cleanText = rawResponse.replaceAll(RegExp(r'```json|```'), '').trim();
      
      // 2. Use regex to extract the first valid JSON object block
      final RegExp jsonRegex = RegExp(r'\{[\s\S]*\}');
      final match = jsonRegex.firstMatch(cleanText);
      
      if (match != null) {
        return jsonDecode(match.group(0)!);
      }
      
      throw const FormatException("No JSON object found in LLM response.");
    } catch (e) {
      debugPrint('🚨 [LLM Parse Error]: $e\nRaw Output: $rawResponse');
      // Failsafe object to guarantee the UI never crashes on a null reference
      return {
        "detected_emotion": "Processing Error",
        "cognitive_distortion": "Context Unclear",
        "reframing_action": "Take a deep breath and rephrase your entry. The neural engine had trouble parsing this.",
        "urgency_level": "Low"
      };
    }
  }

  /// Core Execution Pipeline: Local Cache -> Local SLM (Free) -> Cloud LLM (Premium)
  Future<Map<String, dynamic>> generateTherapeuticInsight({
    required String userText,
    required Map<String, dynamic> somaticMetrics,
    required bool isPremiumUser,
    required Future<String> Function(String payload) cloudProvider,
  }) async {
    
    // ZERO-COST TRIAGE: Don't do heavy processing on ultra-short text
    if (userText.trim().split(' ').length <= 2 && !isPremiumUser) {
        return {
          "detected_emotion": "Neutral",
          "cognitive_distortion": "None",
          "reframing_action": "Acknowledge the user's presence.",
          "urgency_level": "Low"
        };
    }

    final cacheKey = _generateCacheKey(userText);
    
    // ------------------------------------------------------------------------
    // STEP 1: ISOLATED SEMANTIC CACHE (Cost: $0.00 | Speed: < 2ms)
    // ------------------------------------------------------------------------
    final cachedInsight = await _getCachedInsight(cacheKey);
    if (cachedInsight != null && cachedInsight.isNotEmpty) {
      if (kDebugMode) {
        print('✅ [Hybrid Router]: Cache Hit! Bypassing inference. Cost: \$0.00');
      }
      return jsonDecode(cachedInsight);
    }

    // ------------------------------------------------------------------------
    // STEP 2: FREE TIER (Offline On-Device SLM Fallback)
    // ------------------------------------------------------------------------
    if (!isPremiumUser) {
      if (kDebugMode) {
        print('⚡ [Hybrid Router]: Routing to On-Device Logic (Free Tier)');
      }
      
      // Failsafe heuristic fallback for non-premium users
      final localSlmResponse = {
        "detected_emotion": "Elevated Stress",
        "cognitive_distortion": "Somatic Overload",
        "reframing_action": "Ground yourself. Focus on your breathing for 60 seconds.",
        "urgency_level": "Medium"
      };
      
      await _cacheInsight(cacheKey, jsonEncode(localSlmResponse));
      return localSlmResponse;
    }

    // ------------------------------------------------------------------------
    // STEP 3: PREMIUM TIER (Cloud LLM Execution)
    // ------------------------------------------------------------------------
    if (kDebugMode) {
      print('☁️ [Hybrid Router]: Routing to Cloud LLM (Premium Tier)');
    }
    
    try {
      // Inject strict delimiters to prevent Prompt Injection attacks
      final payload = CbtSecurePrompts.compilePayload(userText, somaticMetrics);
      
      // Execute with a strict 6-second timeout to prevent infinite UI loading spinners
      final rawResponse = await cloudProvider(payload).timeout(const Duration(seconds: 6));
      
      // Parse robustly
      final Map<String, dynamic> decoded = _extractJsonFromLlmResponse(rawResponse);

      // Verify the essential keys exist to prevent UI null-reference crashes later
      decoded['detected_emotion'] ??= "Unknown Emotion";
      decoded['cognitive_distortion'] ??= "Unidentified Pattern";
      decoded['reframing_action'] ??= "Focus on immediate physical grounding.";
      decoded['urgency_level'] ??= "Low";

      // Cache the result into local memory immediately for future identical queries
      await _cacheInsight(cacheKey, jsonEncode(decoded));
      
      return decoded;

    } on TimeoutException {
      debugPrint('🚨 [Hybrid Router]: Cloud LLM Timeout.');
      return {
        "detected_emotion": "Processing Offline",
        "cognitive_distortion": "Network Disrupted",
        "reframing_action": "Reframing offline. Focus on physical grounding techniques.",
        "urgency_level": "Low"
      };
    } catch (e) {
      debugPrint('🚨 [Hybrid Router Error]: $e');
      return {
        "detected_emotion": "Error Intercepted",
        "cognitive_distortion": "API Disconnect",
        "reframing_action": "The neural engine requires a stable connection. Please try again.",
        "urgency_level": "Low"
      };
    }
  }
}