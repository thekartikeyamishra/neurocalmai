import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error } //[cite: 15]

class AuthNotifier extends Notifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance; //[cite: 15]
  final FlutterSecureStorage _storage = const FlutterSecureStorage(); //[cite: 15]
  
  StreamSubscription<User?>? _authStateSubscription;
  String? errorMessage; //[cite: 15]

  @override
  AuthState build() {
    // Clean up the subscription if the provider is ever destroyed
    ref.onDispose(() {
      _authStateSubscription?.cancel();
    });

    // 🚨 ARCHITECT UPGRADE: Real-time Reactivity
    // Instead of checking state once, we listen to the Firebase Auth stream.
    // When the frictionless anonymous login fires in main.dart, this instantly updates the UI.
    _authStateSubscription = _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _cacheToken(user); //[cite: 15]
        state = AuthState.authenticated; //[cite: 15]
      } else {
        state = AuthState.unauthenticated; //[cite: 15]
      }
    });

    return _auth.currentUser != null ? AuthState.authenticated : AuthState.initial;
  }

  Future<void> _cacheToken(User user) async {
    try {
      final token = await user.getIdToken(); //[cite: 15]
      if (token != null) {
        await _storage.write(key: 'auth_token', value: token); //[cite: 15]
        // Store hashed UID for SLM data lake referencing[cite: 15]
        await _storage.write(key: 'user_id', value: user.uid.hashCode.toString()); //[cite: 15]
      }
    } catch (e) {
      debugPrint('🚨 [Auth Service]: Token caching failed: $e');
    }
  }

  /// 🚨 Frictionless Anonymous Authentication
  /// Grants the user a secure Firebase UID without requiring an email or password.
  Future<void> signInAnonymously() async {
    state = AuthState.loading; //[cite: 15]
    try {
      if (_auth.currentUser == null) {
        final userCredential = await _auth.signInAnonymously(); //[cite: 15]
        if (userCredential.user != null) {
          await _cacheToken(userCredential.user!); //[cite: 15]
          state = AuthState.authenticated; //[cite: 15]
          debugPrint('✅ [Auth Service]: Anonymous session established.');
        }
      } else {
        // Fallback in case they are already logged in
        state = AuthState.authenticated;
      }
    } catch (e) {
      debugPrint('🚨 [Auth Service Error]: $e');
      errorMessage = "Authentication failed. Please check your connection."; //[cite: 15]
      state = AuthState.error; //[cite: 15]
      
      // Revert to unauthenticated after a delay to allow UI to show error[cite: 15]
      Future.delayed(const Duration(seconds: 3), () {
        if (state == AuthState.error) {
          state = AuthState.unauthenticated; //[cite: 15]
        }
      });
    }
  }

  Future<void> signOut() async {
    state = AuthState.loading; //[cite: 15]
    try {
      await _auth.signOut(); //[cite: 15]
      await _storage.delete(key: 'auth_token'); //[cite: 15]
      await _storage.delete(key: 'user_id'); //[cite: 15]
      state = AuthState.unauthenticated; //[cite: 15]
      debugPrint('✅ [Auth Service]: Session securely terminated.');
    } catch (e) {
      debugPrint('🚨 [Auth Service Error]: Failed to sign out: $e');
      state = AuthState.error;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier()); //[cite: 15]