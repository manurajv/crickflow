import 'package:crickflow/data/user_private_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergePrivateUserProfile', () {
    test('prefers private email, phone, and date of birth', () {
      final merged = mergePrivateUserProfile(
        {
          'email': 'old@example.com',
          'phoneNumber': '+94000000000',
          'mobile': '+94000000000',
          'dob': '1990-01-01',
        },
        {
          'email': 'new@example.com',
          'phoneNumber': '+94711111111',
          'dob': '1991-02-02',
        },
      );
      expect(merged['email'], 'new@example.com');
      expect(merged['phoneNumber'], '+94711111111');
      expect(merged['mobile'], '+94711111111');
      expect(merged['dob'], '1991-02-02');
      expect(merged['dateOfBirth'], '1991-02-02');
    });

    test('falls back to parent when private is missing or empty', () {
      final parent = {
        'email': 'keep@example.com',
        'phoneNumber': '+94700000000',
        'dob': '1992-03-03',
      };
      expect(mergePrivateUserProfile(parent, null)['email'], 'keep@example.com');
      expect(
        mergePrivateUserProfile(parent, {'email': '  ', 'phoneNumber': null})['email'],
        'keep@example.com',
      );
      expect(
        mergePrivateUserProfile(parent, {'email': '  ', 'phoneNumber': null})['phoneNumber'],
        '+94700000000',
      );
    });
  });

  test('privateUserProfilePayload dual-fills phone aliases', () {
    final payload = privateUserProfilePayload(
      email: 'a@b.c',
      phoneNumber: '+94701036188',
      dateOfBirthRaw: '1990-05-05',
      updatedAt: '2026-11-20T00:00:00.000Z',
    );
    expect(payload['phoneNumber'], '+94701036188');
    expect(payload['mobile'], '+94701036188');
    expect(payload['dob'], '1990-05-05');
    expect(payload['dateOfBirth'], '1990-05-05');
  });
}
