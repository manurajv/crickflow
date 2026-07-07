import '../data/models/stream_studio_config.dart';
import '../services/stream_platform_service.dart';
import '../domain/streaming_enums.dart';
import '../domain/destinations/stream_destination_provider.dart';
import '../domain/destinations/stream_live_credentials.dart';

class TwitchDestinationProvider implements StreamDestinationProvider {
  TwitchDestinationProvider(this._platformService);

  final StreamPlatformService _platformService;

  @override
  StreamPlatform get platform => StreamPlatform.twitch;

  @override
  String get label => 'Twitch';

  @override
  bool get supportsOAuth => true;

  @override
  Future<StreamLiveCredentials?> createLiveBroadcast(
    StreamStudioConfig config, {
    Map<String, String>? thumbnailPayload,
  }) async {
    final creds = await _platformService.createTwitchLive(config: config);
    if (creds == null) return null;
    return StreamLiveCredentials(
      rtmpUrl: creds.rtmpUrl,
      streamKey: creds.streamKey,
      watchUrl: creds.watchUrl,
      providerLabel: label,
    );
  }

  @override
  Future<StreamLiveCredentials?> resolveManualCredentials(
    StreamStudioConfig config,
  ) async {
    if (config.streamKey.trim().isEmpty) return null;
    return StreamLiveCredentials(
      rtmpUrl: config.rtmpUrl.isEmpty
          ? StreamPlatform.twitch.defaultRtmpUrl
          : config.rtmpUrl,
      streamKey: config.streamKey,
      providerLabel: label,
    );
  }
}
