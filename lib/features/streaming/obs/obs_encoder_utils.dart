import 'dart:convert';

import '../domain/destinations/stream_live_credentials.dart';

/// Helpers for external encoder (OBS) setup.
class ObsEncoderUtils {
  ObsEncoderUtils._();

  /// QR payload: JSON with RTMP server and stream key for third-party scanner apps.
  static String qrPayload(StreamLiveCredentials credentials) {
    return jsonEncode({
      'type': 'crickflow_rtmp',
      'server': credentials.rtmpUrl,
      'key': credentials.streamKey,
    });
  }

  /// Single-line OBS stream settings hint.
  static String obsInstructions(StreamLiveCredentials credentials) {
    return 'Server: ${credentials.rtmpUrl}\nStream Key: ${credentials.streamKey}';
  }
}
