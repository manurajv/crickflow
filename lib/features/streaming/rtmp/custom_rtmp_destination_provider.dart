import '../data/models/stream_studio_config.dart';
import '../domain/streaming_enums.dart';
import '../domain/destinations/stream_destination_provider.dart';
import '../domain/destinations/stream_live_credentials.dart';

class CustomRtmpDestinationProvider implements StreamDestinationProvider {
  @override
  StreamPlatform get platform => StreamPlatform.customRtmp;

  @override
  String get label => 'Custom RTMP';

  @override
  bool get supportsOAuth => false;

  @override
  Future<StreamLiveCredentials?> createLiveBroadcast(
    StreamStudioConfig config, {
    Map<String, String>? thumbnailPayload,
  }) async {
    return resolveManualCredentials(config);
  }

  @override
  Future<StreamLiveCredentials?> resolveManualCredentials(
    StreamStudioConfig config,
  ) async {
    if (config.rtmpUrl.trim().isEmpty || config.streamKey.trim().isEmpty) {
      return null;
    }
    return StreamLiveCredentials(
      rtmpUrl: config.rtmpUrl.trim(),
      streamKey: config.streamKey.trim(),
      providerLabel: label,
    );
  }
}
