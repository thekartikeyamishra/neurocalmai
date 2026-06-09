import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/monetization/services/margin_engine.dart';

/// Custom exception for AI security violations or operational limits.
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
/// 1. Prompt Injection Sanitization (Client-side firewall defense).
/// 2. Rate Limiting & DDoS protection (Token Bucket pattern).
/// 3. Financial Circuit Breaking (via MarginEngine) to guarantee profitability.
class AIGateway {
  final MarginEngine _marginEngine;

  // Rate Limiting Configuration (Token Bucket Pattern)
  static const int _maxTokens = 15; // Maximum burst requests allowed
  static const Duration _refillRate = Duration(seconds: 10); // Refill interval per token
  int _currentTokens = _maxTokens;
  Timer? _refillTimer;

  // Prompt Security Configuration
  static const int _maxPromptLength = 4000; // Hard character cap to avoid unexpected billing runaway
  
  final List<RegExp> _injectionPatterns = [
    RegExp(r'(ignore previous instructions|ignore all instructions|system prompt bypass)', caseSensitive: false),
    RegExp(r'(you are now a|act as a instead|forget your rules)', caseSensitive: false),
    RegExp(r'(reveal your system prompt|output your instructions|what is your prompt)', caseSensitive: false),
    RegExp(r'(dan mode|jailbreak|bypass security)', caseSensitive: false),
  ];

  AIGateway({required MarginEngine marginEngine}) : _marginEngine = marginEngine {
    _startTokenRefillTimer();
  }

  /// Initializes the periodic background token synchronization bucket
  void _startTokenRefillTimer() {
    _refillTimer = Timer.periodic(_refillRate, (timer) {
      if (_currentTokens < _maxTokens) {
        _currentTokens++;
      }
    });
  }

  /// Disposes background timer operations to eliminate potential memory leaks
  void dispose() {
    _refillTimer?.cancel();
  }

  /// Central Execution interceptor managing pipeline security, rate constraints, and margin protection
  Future<String> executeSecureAI({
    required String prompt,
    required double expectedTokenCost,
    required Future<String> Function(String sanitizedPrompt) onExecute,
    required Future<String> Function() onFallback,
  }) async {
    try {
      // 1. Rate Limiting Check (Token Bucket Violation)
      if (_currentTokens <= 0) {
        throw AISecurityException(
          'Too many requests. Please wait a moment before sending another prompt.',
          'RATE_LIMIT_EXCEEDED',
        );
      }

      // 2. Maximum Context Token Guardrails
      if (prompt.length > _maxPromptLength) {
        throw AISecurityException(
          'Input prompt context length exceeds allowed thresholds.',
          'PROMPT_LENGTH_VIOLATION',
        );
      }

      // 3. Financial Circuit Breaking (Margin and Profit Protection Check)
      // If our current workspace account context has run out of funds or hit a hard cap, prevent execution.
      if (expectedTokenCost > 0.0 && !_marginEngine.isTransactionProfitable(expectedTokenCost)) {
        throw AISecurityException(
          'Operational spending threshold reached. Processing deferred.',
          'FINANCIAL_CIRCUIT_BREAKER_ACTIVE',
        );
      }

      // Consume one rate limiting token from the tracking bucket
      _currentTokens--;

      // 4. Prompt Sanitization Inspection
      final cleanPrompt = _sanitizePrompt(prompt);

      // 5. Execute secure underlying platform AI transaction flow
      return await onExecute(cleanPrompt);

    } on AISecurityException catch (e) {
      if (kDebugMode) {
        print('🛡️ [AIGateway Security Block]: ${e.message} [${e.code}]');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [AIGateway Unexpected Error]: $e');
      }
      // Automatic fallback graceful mitigation loop to shield the presentation screen layer
      return await onFallback();
    }
  }

  /// Robust scanner checking against injection variations and stripping unauthorized sub-elements
  String _sanitizePrompt(String input) {
    String sanitized = input;

    // Reject and strip adversarial layout variations
    for (var pattern in _injectionPatterns) {
      if (pattern.hasMatch(sanitized)) {
        if (kDebugMode) {
          print('🛡️ [AIGateway]: Malicious payload match blocked: ${pattern.pattern}');
        }
        // Scrub the problematic text slice out of the pipeline footprint
        sanitized = sanitized.replaceAll(pattern, '[REDACTED_SECURITY_POLICY]');
      }
    }

    // Secondary layer cleaning to scrub script blocks if content ever passes to WebViews
    sanitized = sanitized.replaceAll(RegExp(r'<script.*?>([\s\S]*?)<\/script>', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'<\/?[^>]+(>|$)', caseSensitive: false), ''); // Strips markup elements

    return sanitized;
  }
}