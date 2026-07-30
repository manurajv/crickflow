import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Maps low-level failures to user-facing admin messages.
///
/// Never includes stack traces, tokens, or raw exception dumps in UI copy.
abstract final class AdminErrors {
  static String userMessage(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
    if (error is FirebaseAuthException) {
      return _auth(error);
    }
    final raw = error.toString();
    if (raw.contains('permission-denied') || raw.contains('PERMISSION_DENIED')) {
      return 'You do not have permission to perform this action.';
    }
    if (raw.contains('unavailable') || raw.contains('network')) {
      return 'Network issue. Check your connection and retry.';
    }
    if (raw.contains('deadline-exceeded') || raw.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }
    if (raw.contains('not-found') || raw.contains('NOT_FOUND')) {
      return 'The requested item was not found.';
    }
    if (raw.contains('already-exists')) {
      return 'This record already exists.';
    }
    if (raw.contains('resource-exhausted')) {
      return 'Too many requests. Wait a moment and try again.';
    }
    if (kDebugMode) {
      // Keep debug useful without dumping secrets.
      final clipped = raw.length > 180 ? '${raw.substring(0, 180)}…' : raw;
      return clipped;
    }
    return fallback;
  }

  static String _auth(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Invalid email or password.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'network-request-failed' => 'Network error. Check your connection.',
      'email-already-in-use' => 'That email is already in use.',
      'weak-password' => 'Password is too weak.',
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This account has been disabled.',
      'popup-closed-by-user' || 'cancelled-popup-request' =>
        'Sign-in was cancelled.',
      _ => 'Authentication failed. Please try again.',
    };
  }
}
