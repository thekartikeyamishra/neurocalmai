import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// A production-ready authentication service managing anonymous sessions
/// and secure credential linking. By using [linkWithCredential], the user's
/// original UID remains unchanged, ensuring that local SQLite/Isar data
/// and RevenueCat purchase histories are perfectly preserved upon upgrading.
class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Uses the v7.0.0+ singleton pattern for GoogleSignIn
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleInitialized = false;

  /// Ensures Google Sign-In is initialized exactly once per session.
  Future<void> _ensureGoogleInitialized() async {
    if (!_isGoogleInitialized) {
      await _googleSignIn.initialize();
      _isGoogleInitialized = true;
    }
  }

  /// Gets the current authenticated user stream.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Retrieves the current user, ensuring they exist.
  User? get currentUser => _auth.currentUser;

  /// Initializes an anonymous session if the user is not already signed in.
  /// This supports the offline-first, privacy-first onboarding flow.
  Future<User?> signInAnonymously() async {
    try {
      if (_auth.currentUser != null) {
        return _auth.currentUser;
      }
      final UserCredential cred = await _auth.signInAnonymously();
      debugPrint('✅ [AuthService]: Anonymous session started: ${cred.user?.uid}');
      return cred.user;
    } catch (e) {
      debugPrint('🚨 [AuthService Error]: Anonymous sign-in failed: $e');
      throw Exception('Failed to initialize secure session. Check network connection.');
    }
  }

  /// Upgrades an anonymous account by linking it with an Email and Password.
  Future<User?> linkEmailCredential({
    required String email,
    required String password,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No active session found to link.');
    }

    if (!user.isAnonymous) {
      throw Exception('Account is already secured with permanent credentials.');
    }

    try {
      final AuthCredential credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );

      final UserCredential linkedUser = await user.linkWithCredential(credential);
      debugPrint('✅ [AuthService]: Email linked successfully to UID: ${linkedUser.user?.uid}');
      return linkedUser.user;
      
    } on FirebaseAuthException catch (e) {
      _handleLinkingError(e);
    } catch (e) {
      debugPrint('🚨 [AuthService Error]: Unexpected email link error: $e');
      throw Exception('An unexpected error occurred while securing your account.');
    }
  }

  /// Upgrades an anonymous account by linking it with a Google account.
  Future<User?> linkGoogleCredential() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('No active session found to link.');
    }

    if (!user.isAnonymous) {
      throw Exception('Account is already secured with permanent credentials.');
    }

    try {
      await _ensureGoogleInitialized();

      // Trigger the native Google Sign-In flow using v7.0.0+ authenticate method.
      // authenticate() throws an exception if canceled, so no null check is needed.
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // Authorization step to retrieve the accessToken
      final clientAuth = await googleUser.authorizationClient.authorizeScopes(['email', 'profile']);
      
      // googleUser.authentication is now synchronous in v7.0.0+
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential linkedUser = await user.linkWithCredential(credential);
      debugPrint('✅ [AuthService]: Google linked successfully to UID: ${linkedUser.user?.uid}');
      return linkedUser.user;

    } on FirebaseAuthException catch (e) {
      if (_isGoogleInitialized) {
        await _googleSignIn.signOut();
      }
      _handleLinkingError(e);
    } catch (e) {
      if (_isGoogleInitialized) {
        await _googleSignIn.signOut();
      }
      debugPrint('🚨 [AuthService Error]: Google link error: $e');
      throw Exception('An error occurred or the request was canceled while securing your account with Google.');
    }
  }

  /// Signs the user out of all active providers.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      
      // currentUser state is no longer tracked directly by _googleSignIn in v7.0.0+
      if (_isGoogleInitialized) {
        await _googleSignIn.signOut();
      }
      
      debugPrint('✅ [AuthService]: User signed out successfully.');
    } catch (e) {
      debugPrint('🚨 [AuthService Error]: Sign out failed: $e');
      throw Exception('Failed to sign out. Please try again.');
    }
  }

  /// Translates raw Firebase error codes into user-friendly security messages.
  Never _handleLinkingError(FirebaseAuthException e) {
    debugPrint('🚨 [FirebaseAuthException] Code: ${e.code} | Message: ${e.message}');
    switch (e.code) {
      case 'credential-already-in-use':
      case 'email-already-in-use':
        throw Exception(
          'This email is already registered to another NeuroCalm account. '
          'Please use a different email or sign in directly.',
        );
      case 'invalid-email':
        throw Exception('The email address provided is invalid.');
      case 'weak-password':
        throw Exception('Please choose a stronger password (minimum 6 characters).');
      case 'provider-already-linked':
        throw Exception('This account is already linked to a secure provider.');
      case 'network-request-failed':
        throw Exception('Network connection lost. Please check your internet and try again.');
      default:
        throw Exception(e.message ?? 'Failed to secure account. Please try again.');
    }
  }
}