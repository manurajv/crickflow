import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../config/youtube_oauth_config.dart';
import 'stream_platform_service.dart';

const _youtubeScopes = <String>[
  'https://www.googleapis.com/auth/youtube',
  'https://www.googleapis.com/auth/youtube.force-ssl',
];

class StreamYouTubeAuthService {
  StreamYouTubeAuthService({required StreamPlatformService platformService})
      : _platformService = platformService;

  final StreamPlatformService _platformService;

  Future<void> linkYouTubeAccount() async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw StreamPlatformException(
        'Sign in to CrickFlow first, then connect your YouTube account.',
      );
    }

    final googleSignIn = GoogleSignIn(
      scopes: _youtubeScopes,
      serverClientId: kYouTubeWebClientId,
      // Required so Google returns a refresh token for any chosen account
      // (not only the CrickFlow sign-in account).
      forceCodeForRefreshToken: true,
    );

    // Fresh consent + account picker — disconnect clears prior YouTube OAuth
    // for this app so a different Google account can be linked.
    try {
      await googleSignIn.disconnect();
    } catch (_) {}
    await googleSignIn.signOut();
    final GoogleSignInAccount? account;
    try {
      account = await googleSignIn.signIn();
    } on PlatformException catch (e) {
      throw StreamPlatformException(_messageForSignInFailure(e));
    }
    if (account == null) {
      throw StreamPlatformException('Google sign-in cancelled');
    }

    final authCode = account.serverAuthCode;
    if (authCode == null || authCode.isEmpty) {
      throw StreamPlatformException(
        'No server auth code from Google. Use the Firebase Web client ID in '
        'kYouTubeWebClientId, add your app SHA-1 in Firebase, and set '
        'YOUTUBE_CLIENT_ID/SECRET on Cloud Functions. See docs/STREAMING_SETUP.md.',
      );
    }

    await _platformService.linkYouTubeAccount(serverAuthCode: authCode);
  }
}

String _messageForSignInFailure(PlatformException error) {
  final details = error.message ?? error.code;
  if (details.contains('10') || details.contains('DEVELOPER_ERROR')) {
    return 'Google sign-in misconfigured (ApiException 10). '
        'Use the Firebase Web client ID from google-services.json as '
        'kYouTubeWebClientId, register your debug/release SHA-1 in Firebase, '
        'and set YOUTUBE_CLIENT_ID/SECRET to that same Web client. '
        'See docs/STREAMING_SETUP.md.';
  }
  return 'Google sign-in failed: $details';
}
