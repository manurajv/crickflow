import 'package:firebase_auth/firebase_auth.dart';

import '../constants/player_profile_constants.dart';

/// Shared E.164 helpers used by login and Register New Player.
/// Keep rules aligned with [LoginScreen] phone validation.
class PhoneAuthUtils {
  PhoneAuthUtils._();

  static const minNationalDigits = 7;
  static const maxNationalDigits = 15;

  /// Local cooldown after Firebase device rate-limit (17010 / too-many-requests).
  static const rateLimitCooldown = Duration(minutes: 15);

  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  static bool isValidNationalNumber(String raw) {
    final digits = digitsOnly(raw);
    return digits.length >= minNationalDigits &&
        digits.length <= maxNationalDigits;
  }

  /// Builds `+94771234567` from a dial code and national number.
  static String toE164({
    required String dialCode,
    required String nationalNumber,
  }) {
    final dial = dialCode.startsWith('+') ? dialCode : '+$dialCode';
    return '$dial${digitsOnly(nationalNumber)}';
  }

  static bool isValidE164(String phone) =>
      RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone.trim());

  static String hintForDialCode(String dialCode) {
    return switch (dialCode) {
      '+94' => '771234567',
      '+91' => '9876543210',
      '+92' => '3001234567',
      '+880' => '1712345678',
      '+44' => '7911123456',
      '+61' => '412345678',
      '+64' => '211234567',
      '+27' => '821234567',
      '+1' => '2025551234',
      '+971' => '501234567',
      _ => '771234567',
    };
  }

  /// Splits an E.164 number into dial code + national digits using known cricket dial codes.
  static ({String dialCode, String national}) splitE164(String e164) {
    final phone = e164.trim();
    final match = CricketCountry.all
        .map((c) => c.dialCode)
        .where(phone.startsWith)
        .fold<String?>(
          null,
          (prev, code) =>
              prev == null || code.length > prev.length ? code : prev,
        );
    if (match != null) {
      return (dialCode: match, national: phone.substring(match.length));
    }
    return (
      dialCode: '+94',
      national: phone.replaceFirst(RegExp(r'^\+\d+\s*'), ''),
    );
  }

  /// Firebase temporary device block (SMS quota / abuse protection).
  static bool isDeviceRateLimited(Object? error) {
    if (error is FirebaseAuthException) {
      if (error.code == 'too-many-requests') return true;
      return _looksRateLimited('${error.code} ${error.message}');
    }
    return _looksRateLimited(error?.toString());
  }

  static bool _looksRateLimited(String? text) {
    if (text == null || text.isEmpty) return false;
    final lower = text.toLowerCase();
    return lower.contains('too-many-requests') ||
        lower.contains('too many attempts') ||
        lower.contains('too many requests') ||
        lower.contains('unusual activity') ||
        lower.contains('blocked all requests') ||
        lower.contains('17010');
  }

  static String friendlyAuthError(Object? error) {
    if (error is FirebaseAuthException) {
      if (isDeviceRateLimited(error)) {
        return 'Firebase temporarily blocked SMS from this device after too many '
            'verification attempts. Wait about 15–60 minutes (sometimes longer), '
            'or use a Firebase Console test phone number while developing.';
      }
      return friendlyAuthError(error.message ?? error.code);
    }

    final message = error?.toString();
    if (message == null || message.isEmpty) {
      return 'Phone verification failed. Please try again.';
    }
    final lower = message.toLowerCase();
    if (_looksRateLimited(message)) {
      return 'Firebase temporarily blocked SMS from this device after too many '
          'verification attempts. Wait about 15–60 minutes (sometimes longer), '
          'or use a Firebase Console test phone number while developing.';
    }
    if (lower.contains('session-expired') ||
        lower.contains('expired') ||
        lower.contains('invalid-verification-id') ||
        lower.contains('missing-verification-id')) {
      return 'That code has expired. Request a new one.';
    }
    if (lower.contains('invalid-verification-code') ||
        lower.contains('invalid-code') ||
        lower.contains('incorrect')) {
      return 'That code is incorrect. Check the SMS and try again.';
    }
    if (lower.contains('network') ||
        lower.contains('unavailable') ||
        lower.contains('timeout') ||
        lower.contains('socket') ||
        lower.contains('host')) {
      return 'Network error. Check your connection and try again.';
    }
    if (lower.contains('.web.app') ||
        lower.contains('firebaseapp') ||
        lower.contains('http')) {
      return 'Phone verification failed. Please try again.';
    }
    return message;
  }
}
