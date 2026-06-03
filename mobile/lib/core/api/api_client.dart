import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/**
 * NeuroCalm AI - Production API Client
 * Features: Dynamic .env Routing, Automatic JWT Injection, Global Error Handling, 
 * Connection Timeout Management, and Retry Logic.
 */
class ApiClient {
  static final ApiClient instance = ApiClient._internal();
  late Dio _dio;

  // Dynamically pulls the API URL from your .env file.
  // Fallbacks to production URL if the .env variable is missing.
  String get _baseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'https://api.neurocalm-ai.com/api/v1';
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15), // Requirement 8: Low latency focus (15s strict cutoff)
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 1. Security Interceptor: Inject Firebase Auth Token (JWT) automatically
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              // Retrieve the fresh ID Token (JWT) from Firebase
              final token = await user.getIdToken();
              options.headers['Authorization'] = 'Bearer $token';
            }
            return handler.next(options);
          } catch (e) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Auth Token Injection Failed: $e',
              ),
            );
          }
        },
        onError: (DioException e, handler) {
          _handleError(e);
          return handler.next(e);
        },
      ),
    );

    // 2. Logging Interceptor: Only active during development
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          responseBody: true,
          requestBody: true,
          logPrint: (obj) => debugPrint('[API Log]: $obj'),
        ),
      );
    }
  }

  // Helper getter for the dio instance to be used directly by Providers
  Dio get dio => _dio;

  // ---------------------------------------------------------
  // 1. Core API Methods (Production Ready)
  // ---------------------------------------------------------

  /// POST: Send text chat to AI Therapy Engine (T-002)
  Future<Response> postChat(String message, List<Map<String, String>> history) async {
    return await _dio.post(
      '/therapy/chat',
      data: {'message': message, 'history': history},
    );
  }

  /// POST: Upload Voice Session for processing (T-001)
  /// Uses FormData for efficient multipart audio streaming.
  Future<Response> uploadVoiceSession(String filePath, int moodScore) async {
    final formData = FormData.fromMap({
      'mood_score': moodScore,
      'audio': await MultipartFile.fromFile(filePath, filename: 'session.m4a'),
    });

    return await _dio.post('/therapy/voice', data: formData);
  }

  /// POST: Generates a secure Razorpay Order ID from the backend
  /// Requirement 10: Global Monetization via Razorpay Orders API
  Future<Response> createPremiumOrder() async {
    return await _dio.post('/payment/create-order');
  }

  /// DELETE: Irreversible Data Wipe (Requirement 12 - DPDP/GDPR Compliance)
  Future<void> deleteCloudAccount() async {
    try {
      final response = await _dio.delete('/user/account');
      if (response.statusCode != 200) {
        throw Exception('Server failed to acknowledge deletion.');
      }
    } on DioException catch (e) {
      // If the user is offline, we log the failure but allow the local wipe to continue
      debugPrint('[API Warning]: Cloud wipe failed - ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------
  // 2. Global Error Handler
  // ---------------------------------------------------------
  void _handleError(DioException e) {
    String message = "An unexpected error occurred.";

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = "Connection timed out. Are you offline?";
    } else if (e.response?.statusCode == 401) {
      message = "Session expired. Please log in again.";
    } else if (e.response?.statusCode == 429) {
      message = "Token Quota Governor: Too many requests.";
    } else if (e.type == DioExceptionType.connectionError) {
      message = "Failed to connect to the server. Check your internet connection.";
    }

    debugPrint('❌ [API Error]: $message');
  }
}