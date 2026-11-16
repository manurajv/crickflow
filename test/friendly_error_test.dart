import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crickflow/core/utils/friendly_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore permission-denied never shows raw text', () {
    final e = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'The caller does not have permission to execute the specified operation.',
    );
    final text = friendlyError(e);
    expect(text, isNot(contains('cloud_firestore')));
    expect(text, contains("don't have access"));
  });

  test('stringified Firebase errors are mapped', () {
    expect(
      friendlyError(Exception('[cloud_firestore/unavailable] The service is currently unavailable.')),
      'No internet connection. Check your connection and try again.',
    );
  });

  test('connection codes and timeouts use a clear offline message', () {
    expect(
      friendlyError(FirebaseException(
        plugin: 'firebase_functions',
        code: 'unavailable',
        message: 'UNAVAILABLE',
      )),
      'No internet connection. Check your connection and try again.',
    );
    expect(
      friendlyError(FirebaseException(
        plugin: 'cloud_functions',
        code: 'deadline-exceeded',
        message: 'Deadline expired',
      )),
      'No internet connection. Check your connection and try again.',
    );
    expect(
      friendlyError(FirebaseException(
        plugin: 'firebase_functions',
        code: 'network-request-failed',
      )),
      'No internet connection. Check your connection and try again.',
    );
    expect(
      friendlyError(Exception('ClientException: Failed host lookup')),
      'No internet connection. Check your connection and try again.',
    );
  });

  test('callable invalid-argument keeps the server reason and uses labels', () {
    final e = FirebaseException(
      plugin: 'firebase_functions',
      code: 'invalid-argument',
      message:
          'Registration documents must be uploaded for this player in this organization: profilePhotoUrl',
    );
    expect(
      friendlyError(e),
      'Registration documents must be uploaded for this player in this organization: Profile photo',
    );
  });

  test('callable function messages written for users pass through', () {
    final e = FirebaseException(
      plugin: 'firebase_functions',
      code: 'permission-denied',
      message: 'Only org admins can approve requests.',
    );
    expect(friendlyError(e), 'Only org admins can approve requests.');
  });

  test('plain user-facing exceptions keep their message without prefix', () {
    expect(friendlyError(Exception('Team not found')), 'Team not found');
    expect(friendlyError(StateError('Invitation is no longer pending')), 'Invitation is no longer pending');
  });

  test('technical errors fall back to a generic message', () {
    expect(friendlyError(TypeError()), 'Something went wrong. Please try again.');
    expect(friendlyError(null), 'Something went wrong. Please try again.');
  });

  test('upload errors name size, permission, and connection problems', () {
    expect(
      friendlyUploadError(Exception('This photo is too large. Use a photo under 5 MB.')),
      'This photo is too large. Use a photo under 5 MB.',
    );
    expect(
      friendlyUploadError(FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthorized',
        message: 'User is not authorized',
      )),
      contains('too large'),
    );
    expect(
      friendlyUploadError(FirebaseException(
        plugin: 'firebase_storage',
        code: 'retry-limit-exceeded',
      )),
      'No internet connection. Check your connection and try again.',
    );
  });
}
