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
      contains('Connection problem'),
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
}
