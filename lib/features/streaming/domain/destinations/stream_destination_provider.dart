import '../../data/models/stream_studio_config.dart';
import '../streaming_enums.dart';
import 'stream_live_credentials.dart';

/// Pluggable live destination — YouTube, Facebook, Twitch, custom RTMP, future SRT/Instagram.
abstract class StreamDestinationProvider {
  StreamPlatform get platform;

  String get label;

  /// Whether OAuth / API auto-create is available for this destination.
  bool get supportsOAuth;

  /// Creates a live broadcast and returns ingest credentials.
  /// Returns `null` when user must sign in or enter credentials manually.
  Future<StreamLiveCredentials?> createLiveBroadcast(StreamStudioConfig config);

  /// Validates manual RTMP settings (custom servers).
  Future<StreamLiveCredentials?> resolveManualCredentials(
    StreamStudioConfig config,
  );
}
