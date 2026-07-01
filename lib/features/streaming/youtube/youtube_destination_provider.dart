import '../data/models/stream_studio_config.dart';
import '../domain/stream_credential_normalizer.dart';
import '../services/stream_platform_service.dart';
import '../domain/streaming_enums.dart';
import '../domain/destinations/stream_destination_provider.dart';
import '../domain/destinations/stream_live_credentials.dart';

class YouTubeDestinationProvider implements StreamDestinationProvider {
  YouTubeDestinationProvider(this._platformService);

  final StreamPlatformService _platformService;

  @override
  StreamPlatform get platform => StreamPlatform.youtube;

  @override
  String get label => 'YouTube Live';

  @override
  bool get supportsOAuth => true;

  @override
  Future<StreamLiveCredentials?> createLiveBroadcast(
    StreamStudioConfig config,
  ) async {
    final creds = await _platformService.createYouTubeLive(config: config);
    if (creds == null) return null;
    return StreamLiveCredentials(
      rtmpUrl: creds.rtmpUrl,
      streamKey: creds.streamKey,
      watchUrl: creds.watchUrl,
      broadcastId: creds.broadcastId,
      providerLabel: label,
    );
  }

  @override
  Future<StreamLiveCredentials?> resolveManualCredentials(
    StreamStudioConfig config,
  ) async {
    final normalized = StreamCredentialNormalizer.normalize(
      rtmpUrl: config.rtmpUrl,
      streamKey: config.streamKey,
      platform: StreamPlatform.youtube,
    );
    if (normalized.streamKey.isEmpty) return null;
    final url = normalized.rtmpUrl.isNotEmpty
        ? normalized.rtmpUrl
        : StreamPlatform.youtube.defaultRtmpUrl;
    return StreamLiveCredentials(
      rtmpUrl: url,
      streamKey: normalized.streamKey,
      watchUrl: config.youtubeWatchUrl,
      broadcastId: config.youtubeBroadcastId,
      providerLabel: label,
    );
  }
}
