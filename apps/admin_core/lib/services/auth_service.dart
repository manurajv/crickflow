import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Auth against the shared CrickFlow Firebase project (same as mobile).
///
/// No anonymous sign-in. Persistence + Google use Firebase Auth web APIs.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Fires when ID tokens refresh — useful for claims-aware sessions later.
  Stream<User?> idTokenChanges() => _auth.idTokenChanges();

  User? get currentUser => _auth.currentUser;

  /// [rememberMe] maps to LOCAL vs SESSION persistence on web.
  Future<void> configurePersistence({required bool rememberMe}) async {
    if (!kIsWeb) return;
    await _auth.setPersistence(
      rememberMe ? Persistence.LOCAL : Persistence.SESSION,
    );
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    await configurePersistence(rememberMe: rememberMe);
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Google Sign-In via Firebase popup (web) / redirect fallback.
  Future<UserCredential> signInWithGoogle({bool rememberMe = true}) async {
    await configurePersistence(rememberMe: rememberMe);
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');
    try {
      return await _auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-blocked' || e.code == 'operation-not-supported-in-this-environment') {
        await _auth.signInWithRedirect(provider);
        throw const _GoogleRedirectStarted();
      }
      rethrow;
    }
  }

  Future<UserCredential?> completeGoogleRedirectIfAny() {
    return _auth.getRedirectResult();
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Forces a token refresh (custom claims sync preparation).
  Future<String?> refreshIdToken({bool forceRefresh = true}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  /// Reads custom claims when present (empty until Cloud Functions set them).
  Future<Map<String, dynamic>> readCustomClaims({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return const {};
    final result = await user.getIdTokenResult(forceRefresh);
    return Map<String, dynamic>.from(result.claims ?? const {});
  }
}

class _GoogleRedirectStarted implements Exception {
  const _GoogleRedirectStarted();

  @override
  String toString() => 'Google sign-in redirect started';
}
