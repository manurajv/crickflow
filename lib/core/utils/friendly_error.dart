import 'package:firebase_core/firebase_core.dart';

/// Short, user-facing text for any error shown in the UI.
///
/// Raw Firebase exceptions ("[cloud_firestore/permission-denied] The caller
/// does not have permission…") are never shown to users. Messages written
/// for users (Cloud Function errors, `Exception('Team not found')`, etc.)
/// pass through without the "Exception: " prefix.
String friendlyError(Object? error) {
  if (error == null) return _generic;
  if (error is FirebaseException) {
    final message = error.message?.trim() ?? '';
    if (_isConnectionCode(error.code) || _isConnectionText(message)) {
      return _offline;
    }
    // Callable functions send messages written for users.
    if (error.plugin == 'firebase_functions' &&
        message.isNotEmpty &&
        !_looksTechnical(message)) {
      return _withFieldLabels(message);
    }
    return _forCode(error.code);
  }

  final raw = error.toString().trim();
  final lower = raw.toLowerCase();
  final bracketCode =
      RegExp(r'\[[a-z_]+/([a-z0-9_-]+)\]').firstMatch(lower)?.group(1);
  if (bracketCode != null) {
    if (_isConnectionCode(bracketCode) || _isConnectionText(raw)) {
      return _offline;
    }
    return _forCode(bracketCode);
  }
  if (_isConnectionText(raw)) return _offline;
  for (final code in _codes.keys) {
    // Only distinctive codes; words like "cancelled" also appear in real
    // user-facing messages.
    if (!code.contains('-') && code != 'unauthenticated') continue;
    if (lower.contains(code) || lower.contains(code.replaceAll('-', '_'))) {
      if (_isConnectionCode(code)) return _offline;
      return _forCode(code);
    }
  }
  if (lower.contains('insufficient permissions')) {
    return _forCode('permission-denied');
  }

  var cleaned = raw;
  for (final prefix in const [
    'Exception: ',
    'Bad state: ',
    'Invalid argument(s): ',
    'Invalid argument: ',
    'StateError: ',
    'ArgumentError: ',
    'FormatException: ',
  ]) {
    if (cleaned.startsWith(prefix)) cleaned = cleaned.substring(prefix.length);
  }
  cleaned = cleaned.trim();
  if (cleaned.isEmpty || cleaned.length > 200 || _looksTechnical(cleaned)) {
    return _generic;
  }
  return _withFieldLabels(cleaned);
}

const _generic = 'Something went wrong. Please try again.';
const _offline = 'No internet connection. Check your connection and try again.';

const Map<String, String> _codes = {
  'permission-denied':
      "You don't have access to this. Pull to refresh or sign in again if you think you should.",
  'unauthorized':
      "You don't have access to this. Pull to refresh or sign in again if you think you should.",
  'unauthenticated': 'Please sign in to continue.',
  'requires-recent-login': 'Please sign in again to continue.',
  'unavailable': _offline,
  'network-request-failed': _offline,
  'deadline-exceeded': _offline,
  'retry-limit-exceeded': _offline,
  'not-found': 'This item is no longer available.',
  'object-not-found': 'This file is no longer available.',
  'already-exists': 'This already exists.',
  'resource-exhausted': 'Too many requests. Please wait a moment and try again.',
  'quota-exceeded': 'Too many requests. Please wait a moment and try again.',
  'too-many-requests': 'Too many attempts. Please wait a moment and try again.',
  'cancelled': 'The action was cancelled.',
  'canceled': 'The action was cancelled.',
  'aborted': 'Someone else changed this at the same time. Please try again.',
  'failed-precondition': "This can't be done right now. Please try again.",
  'invalid-credential': 'Incorrect email or password.',
  'wrong-password': 'Incorrect email or password.',
  'user-not-found': 'No account found with these details.',
  'email-already-in-use': 'An account already exists with this email.',
  'weak-password': 'Please choose a stronger password.',
  'invalid-email': 'Please enter a valid email address.',
  'user-disabled': 'This account has been disabled.',
  'invalid-verification-code': 'The code is incorrect. Please try again.',
  'session-expired': 'The code has expired. Please request a new one.',
  'invalid-argument': "Some details aren't valid. Please check and try again.",
  'internal': _generic,
  'unknown': _generic,
};

const _connectionCodes = {
  'unavailable',
  'network-request-failed',
  'deadline-exceeded',
  'retry-limit-exceeded',
};

bool _isConnectionCode(String code) => _connectionCodes.contains(code);

bool _isConnectionText(String text) {
  final lower = text.toLowerCase();
  return lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('network-request-failed') ||
      lower.contains('failed to fetch') ||
      lower.contains('clientexception') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('timeoutexception') ||
      lower.contains('timeout') &&
          (lower.contains('connection') ||
              lower.contains('network') ||
              lower.contains('deadline')) ||
      lower.contains('offline') ||
      lower.contains('no internet') ||
      lower.contains('network_error') ||
      lower.contains('network error');
}

String _forCode(String code) => _codes[code] ?? _generic;

const _fieldLabels = {
  'profilePhotoUrl': 'Profile photo',
  'nationalIdDocUrl': 'National ID document',
  'passportDocUrl': 'Passport document',
  'crickFlowPlayerId': 'CrickFlow Player ID',
  'fullName': 'Full name',
  'dateOfBirth': 'Date of birth',
  'phoneNumber': 'Phone',
  'nationalId': 'National ID',
  'passportNumber': 'Passport',
};

String _withFieldLabels(String message) {
  var out = message;
  for (final e in _fieldLabels.entries) {
    out = out.replaceAll(e.key, e.value);
  }
  return out;
}

bool _looksTechnical(String text) {
  final lower = text.toLowerCase();
  return lower.contains('instance of') ||
      lower.contains('exception') ||
      lower.contains('stack') ||
      lower.contains('null check') ||
      lower.contains('dart:') ||
      lower.contains('package:') ||
      lower.contains('firestore') ||
      lower.contains('grpc') ||
      lower.contains('type \'') ||
      lower.contains('nosuchmethod');
}


/// User-facing text for a photo / document upload failure.
String friendlyUploadError(Object? error, {bool isDocument = true}) {
  final limit = isDocument ? '5 MB' : '2 MB';
  if (error == null) return 'Could not upload the photo. Please try again.';
  if (error is FirebaseException) {
    final message = error.message?.trim() ?? '';
    if (_isConnectionCode(error.code) || _isConnectionText(message)) {
      return _offline;
    }
    if (error.code == 'unauthorized' ||
        error.code == 'permission-denied' ||
        error.code == 'unauthenticated') {
      return "This photo couldn't be uploaded. It may be too large (max $limit), "
          "isn't an allowed image type, or you don't have permission.";
    }
  }
  final raw = error.toString();
  if (_isConnectionText(raw)) return _offline;
  final lower = raw.toLowerCase();
  if (lower.contains('too large') || lower.contains('exceeds the maximum')) {
    return 'This photo is too large. Use a photo under $limit.';
  }
  if (lower.contains('empty') && lower.contains('crop')) {
    return 'The cropped photo is empty. Please try again.';
  }
  return friendlyError(error);
}
