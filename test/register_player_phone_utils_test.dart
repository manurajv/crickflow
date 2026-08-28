import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/core/utils/phone_auth_utils.dart';
import 'package:crickflow/core/utils/deep_link_utils.dart';
import 'package:crickflow/core/utils/player_invite_utils.dart';
import 'package:crickflow/data/models/register_player_models.dart';

void main() {
  group('PhoneAuthUtils', () {
    test('accepts the same national length as login', () {
      expect(PhoneAuthUtils.isValidNationalNumber('771234567'), isTrue);
      expect(PhoneAuthUtils.isValidNationalNumber('123'), isFalse);
      expect(PhoneAuthUtils.isValidNationalNumber('77-123-4567'), isTrue);
    });

    test('builds E.164 from dial code and national digits', () {
      expect(
        PhoneAuthUtils.toE164(dialCode: '+94', nationalNumber: '771234567'),
        '+94771234567',
      );
      expect(
        PhoneAuthUtils.toE164(dialCode: '94', nationalNumber: '77 123 4567'),
        '+94771234567',
      );
    });

    test('splits E.164 using known cricket dial codes', () {
      final parts = PhoneAuthUtils.splitE164('+94771234567');
      expect(parts.dialCode, '+94');
      expect(parts.national, '771234567');
    });

    test('maps OTP errors without leaking Firebase URLs', () {
      expect(
        PhoneAuthUtils.friendlyAuthError('invalid-verification-code'),
        contains('incorrect'),
      );
      expect(
        PhoneAuthUtils.friendlyAuthError('https://foo.firebaseapp.com'),
        isNot(contains('http')),
      );
    });

    test('detects Firebase device rate-limit (17010 / unusual activity)', () {
      expect(
        PhoneAuthUtils.isDeviceRateLimited(
          'We have blocked all requests from this device due to unusual activity',
        ),
        isTrue,
      );
      expect(PhoneAuthUtils.isDeviceRateLimited('status code: 17010'), isTrue);
      expect(
        PhoneAuthUtils.friendlyAuthError('too-many-requests'),
        contains('temporarily blocked'),
      );
    });
  });

  group('ExistingPlayerMatch', () {
    test('parses public lookup payload without private fields', () {
      final match = ExistingPlayerMatch.fromMap({
        'exists': true,
        'uid': 'abc',
        'playerDocId': 'abc',
        'playerId': 'CF000001',
        'displayName': 'Jane Doe',
        'photoUrl': null,
        'onboardingCompleted': true,
        'email': 'secret@example.com',
      });
      expect(match.uid, 'abc');
      expect(match.playerId, 'CF000001');
      expect(match.displayName, 'Jane Doe');
    });
  });

  group('Player invite links', () {
    test('uses consumer web host', () {
      expect(
        DeepLinkUtils.playerInviteUri('abc123').toString(),
        'https://crickflow.web.app/invite/abc123',
      );
    });

    test('maps crickflow.web.app invite URLs into the app path', () {
      expect(
        DeepLinkUtils.pathFromUri(
          Uri.parse('https://crickflow.web.app/invite/abc123/'),
        ),
        '/invite/abc123',
      );
    });

    test('masks invited phone numbers', () {
      expect(PlayerInviteUtils.maskPhone('+94771234567'), '+••••4567');
    });
  });
}
