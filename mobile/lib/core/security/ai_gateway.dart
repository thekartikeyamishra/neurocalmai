import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/monetization/services/margin_engine.dart';

/// Custom exception for AI security violations.
class AISecurityException implements Exception {
  final String message;
  final String code;
  AISecurityException(this.message, this.code);

  @override
  String toString() => 'AISecurityException: $message (Code: $code)';
}

/// AIGateway acts as the central middleware for all outgoing LLM requests.
/// 
/// Primary Responsibilities:
/// 1. Prompt Injection Sanitization (Client-side defense).
/// 2. Rate Limiting / DDoS protection (Token Bucket pattern).
/// 3. Financial Circuit Breaking (via MarginEngine) to guarantee 5x profit.
/// 
/// Note: For zero-trust production security, API keys should never be in the client.
/// This gateway assumes you are routing calls through a secure backend (like Firebase Cloud Functions)
/// or using FlutterSecureStorage with strict App Check enforcement.
class AIGateway {
  final MarginEngine _marginEngine;

  // Rate Limiting Config (Token Bucket)
  static const int _maxTokens = 15; // Max burst requests allowed
  static const Duration _refillRate = Duration(seconds: 10); // 1 token per 10s
  int _currentTokens = _maxTokens;
  Timer? _refillTimer;

  // Security Config
  static const int _maxPromptLength = 4000; // Prevent massive payload attacks
  
  // Blacklist of common jailbreak/injection phrases
  static final List<RegExp> _injectionPatterns = [
    RegExp(r'(ignore|disregard)\s+all\s+(previous\s+)?(instructions|directions)', caseSensitive: false),
    RegExp(r'you\s+are\s+now\s+in\s+(developer|dan)\s+mode', caseSensitive: false),
    RegExp(r'system\s+prompt\s+override', caseSensitive: false),
    RegExp(r'forget\s+your\s+programming', caseSensitive: false),
    RegExp(r'bypass\s+filters', caseSensitive: false),
  ];

  AIGateway({required MarginEngine marginEngine}) : _marginEngine = marginEngine {
    _startTokenRefill();
  }

  void _startTokenRefill() {
    _refillTimer?.cancel();
    _refillTimer = Timer.periodic(_refillRate, (_) {
      if (_currentTokens < _maxTokens) {
        _currentTokens++;
      }
    });
  }

  /// Disposes resources. Call this if the gateway is ever destroyed.
  void dispose() {
    _refillTimer?.cancel();
  }

  /// The main execution wrapper for any AI request (Gemini, OpenAI, etc.).
  /// Validates security, rate limits, and margins before executing the payload.
  Future<T> executeSecureRequest<T>({
    required String rawPrompt,
    required String userId,
    required double currentMonthRevenue,
    required double currentMonthComputeCost,
    required double projectedRequestCost,
    required Future<T> Function(String sanitizedPrompt) onExecute,
    required Future<T> Function() onFallback, // Executes if blocked (e.g., returns cached/RAG data)
  }) async {
    try {
      // 1. Rate Limit Check (DDoS / Throttling Protection)
      if (_currentTokens <= 0) {
        if (kDebugMode) print('AIGateway: Rate limit exceeded. Throttling request.');
        throw AISecurityException('Too many requests. Please slow down.', 'RATE_LIMIT_EXCEEDED');
      }

      // 2. Financial Circuit Breaker (5x Margin Protection)
      final isProfitable = _marginEngine.isUnitProfitable(
        currentMonthRevenue: currentMonthRevenue,
        currentMonthComputeCost: currentMonthComputeCost + projectedRequestCost,
      );

      if (!isProfitable) {
        if (kDebugMode) print('AIGateway: Unit margin unprofitable. Routing to fallback/RAG.');
        // Instead of failing and losing the user, gracefully degrade to a free, cached, or local RAG response.
        return await onFallback();
      }

      // 3. Payload Size Validation (Cost & Buffer Overflow Protection)
      if (rawPrompt.length > _maxPromptLength) {
        throw AISecurityException('Input exceeds maximum allowed length.', 'PAYLOAD_TOO_LARGE');
      }

      // 4. Prompt Injection Sanitization
      final cleanPrompt = _sanitizePrompt(rawPrompt);

      // Deduct rate limit token
      _currentTokens--;

      // 5. Execute actual AI call
      return await onExecute(cleanPrompt);

    } on AISecurityException catch (e) {
      // Log security events to a secure analytics endpoint here in production
      if (kDebugMode) print('Security Block: ${e.message}');
      rethrow;
    } catch (e) {
      if (kDebugMode) print('AIGateway Unexpected Error: $e');
      // If it's a network or unknown error, fallback to keep the app fault-tolerant
      return await onFallback();
    }
  }

  /// Scans the prompt for malicious injection patterns and strips them, 
  /// or throws an exception if the prompt is entirely malicious.
  String _sanitizePrompt(String input) {
    String sanitized = input;

    for (var pattern in _injectionPatterns) {
      if (pattern.hasMatch(sanitized)) {
        if (kDebugMode) print('AIGateway: Malicious pattern detected: ${pattern.pattern}');
        // Option A: Strip the malicious part
        sanitized = sanitized.replaceAll(pattern, '[REDACTED_SECURITY_POLICY]');
        
        // Option B: Throw immediately (Uncomment to use strict mode)
        // throw AISecurityException('Malicious prompt structure detected.', 'PROMPT_INJECTION_BLOCKED');
      }
    }

    // Basic SQL/Script tag stripping to prevent secondary injection if data is ever rendered in a webview
    sanitized = sanitized.replaceAll(RegExp(r'<script.*?>.*?</script>', caseSensitive: false, multiLine: true), '');
    
    return sanitized.trim();
  }
}