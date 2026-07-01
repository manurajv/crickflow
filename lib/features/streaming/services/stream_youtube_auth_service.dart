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
    final googleSignIn = GoogleSignIn(
      scopes: _youtubeScopes,
      serverClientId: kYouTubeWebClientId,
    );

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
        'No server auth code — check Web client ID in Google Cloud Console',
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
