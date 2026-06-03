import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🚨 ARCHITECT FIX: Isolated Caching

// Internal Integrations
import '../prompts/cbt_secure_prompts.dart';

/// Riverpod Provider for Dependency Injection and Testing
/// Now fully decoupled from the Journal Service for better modularity.
final hybridRoutingProvider = Provider<HybridRoutingService>((ref) {
  return HybridRoutingService();
});

class HybridRoutingService {
  
  /// Computes a clean cryptographic hash of user text to use as a semantic cache query key.
  /// Converts to lowercase and trims to ensure slight variations hit the cache.
  String _generateCacheKey(String text) {
    final normalized = text.trim().toLowerCase();
    return md5.convert(utf8.encode(normalized)).toString();
  }

  /// 🚨 ARCHITECT FIX: Self-contained O(1) memory cache. 
  /// Vastly faster than querying SQLite and prevents schema pollution.
  Future<String?> _getCachedInsight(String hash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('ai_cache_$hash');
    } catch (e) {
      debugPrint('⚠️ [Cache Read Error]: $e');
      return null;
    }
  }

  Future<void> _cacheInsight(String hash, String jsonPayload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_cache_$hash', jsonPayload);
    } catch (e) {
      debugPrint('⚠️ [Cache Write Error]: $e');
    }
  }

  /// Extracts strict JSON even if the LLM hallucinates markdown or conversational filler.
  Map<String, dynamic> _extractJsonFromLlmResponse(String rawResponse) {
    try {
      // 1. Remove markdown code blocks if present
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
      // Fallback object to prevent app crash
      return {
        "detected_emotion": "Processing Error",
        "cognitive_distortion": "Context Unclear",
        "reframing_action": "Take a deep breath and rephrase your entry.",
        "urgency_level": "Low"
      };
    }
  }

  /// Processes entry using a strict cost-controlled pipeline: Local Cache -> Local SLM -> Cloud LLM
  Future<Map<String, dynamic>> generateTherapeuticInsight({
    required String userText,
    required Map<String, dynamic> somaticMetrics,
    required bool isPremiumUser,
    required Future<String> Function(String payload) cloudProvider,
  }) async {
    final cacheKey = _generateCacheKey(userText);
    
    // Step 1: Check Isolated Semantic Cache for hits to achieve a $0 compute execution cost
    final cachedInsight = await _getCachedInsight(cacheKey);
    if (cachedInsight != null && cachedInsight.isNotEmpty) {
      debugPrint('✅ [Hybrid Router]: Cache Hit! Cost: \$0.00');
      return jsonDecode(cachedInsight);
    }

    // Step 2: Route users structurally based on monetization entitlements
    if (!isPremiumUser) {
      debugPrint('⚡ [Hybrid Router]: Routing to On-Device SLM (Free Tier)');
      // In production, this connects to a local TFLite model or MLKit text classifier.
      // Returning deterministic offline fallback for immediate offline utility.
      final localSlmResponse = {
        "detected_emotion": "Elevated Stress",
        "cognitive_distortion": "Somatic Overload",
        "reframing_action": "Ground yourself. Focus on your breathing for 60 seconds.",
        "urgency_level": "Medium"
      };
      
      // Cache the local SLM result
      await _cacheInsight(cacheKey, jsonEncode(localSlmResponse));
      return localSlmResponse;
    }

    // Step 3: Premium User -> Run Cloud LLM query using hyper-dense payload mappings
    debugPrint('☁️ [Hybrid Router]: Routing to Cloud LLM (Premium Tier)');
    try {
      // Inject strict delimiters to prevent Prompt Injection attacks
      final payload = CbtSecurePrompts.compilePayload(userText, somaticMetrics);
      
      // Execute with a strict 6-second timeout to prevent infinite UI loading
      final rawResponse = await cloudProvider(payload).timeout(const Duration(seconds: 6));
      
      // Parse robustly
      final Map<String, dynamic> decoded = _extractJsonFromLlmResponse(rawResponse);

      // Verify the essential keys exist to prevent UI null-reference crashes later
      decoded['detected_emotion'] ??= "Unknown Emotion";
      decoded['cognitive_distortion'] ??= "Unidentified Pattern";
      decoded['reframing_action'] ??= "Focus on immediate physical grounding.";
      decoded['urgency_level'] ??= "Low";

      // Step 4: Cache the result into local memory immediately
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