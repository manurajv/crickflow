import '../data/models/stream_studio_config.dart';
import '../domain/stream_credential_normalizer.dart';
import '../services/stream_platform_service.dart';
import '../domain/streaming_enums.dart';
import '../domain/destinations/stream_destination_provider.dart';
import '../domain/destinations/stream_live_credentials.dart';

class FacebookDestinationProvider implements StreamDestinationProvider {
  FacebookDestinationProvider(this._platformService);

  final StreamPlatformService _platformService;

  @override
  StreamPlatform get platform => StreamPlatform.facebook;

  @override
  String get label => 'Facebook Live';

  /// Graph API auto-create is not wired yet — manual RTMP from Live Producer.
  @override
  bool get supportsOAuth => false;

  @override
  Future<StreamLiveCredentials?> createLiveBroadcast(
    StreamStudioConfig config, {
    Map<String, String>? thumbnailPayload,
  }) async {
    final creds = await _platformService.createFacebookLive(config: config);
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
    final normalized = StreamCredentialNormalizer.normalize(
      rtmpUrl: config.rtmpUrl,
      streamKey: config.streamKey,
      platform: StreamPlatform.facebook,
    );
    if (normalized.streamKey.isEmpty) return null;
    final url = normalized.rtmpUrl.isNotEmpty
        ? normalized.rtmpUrl
        : StreamPlatform.facebook.defaultRtmpUrl;
    return StreamLiveCredentials(
      rtmpUrl: url,
      streamKey: normalized.streamKey,
      watchUrl: '',
      providerLabel: label,
    );
  }
}
