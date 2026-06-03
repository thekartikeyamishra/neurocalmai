import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthNotifier extends Notifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? errorMessage;

  @override
  AuthState build() {
    _checkAuthState();
    return AuthState.initial;
  }

  Future<void> _checkAuthState() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _cacheToken(user);
      state = AuthState.authenticated;
    } else {
      state = AuthState.unauthenticated;
    }
  }

  Future<void> _cacheToken(User user) async {
    final token = await user.getIdToken();
    if (token != null) {
      await _storage.write(key: 'auth_token', value: token);
      // Store hashed UID for SLM data lake referencing
      await _storage.write(key: 'user_id', value: user.uid.hashCode.toString());
    }
  }

  Future<void> signInAnonymously() async {
    state = AuthState.loading;
    try {
      final userCredential = await _auth.signInAnonymously();
      if (userCredential.user != null) {
        await _cacheToken(userCredential.user!);
        state = AuthState.authenticated;
      }
    } catch (e) {
      errorMessage = "Authentication failed. Please check your connection.";
      state = AuthState.error;
      // Revert to unauthenticated after a delay to allow UI to show error
      Future.delayed(const Duration(seconds: 3), () => state = AuthState.unauthenticated);
    }
  }

  Future<void> signOut() async {
    state = AuthState.loading;
    await _auth.signOut();
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_id');
    state = AuthState.unauthenticated;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier());