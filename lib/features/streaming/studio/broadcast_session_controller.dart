import '../../../../core/constants/enums.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/repositories/match_repository.dart';
import '../../../../data/services/stream_service.dart';
import '../data/models/stream_studio_config.dart';
import '../domain/destinations/stream_destination_registry.dart';
import '../domain/destinations/stream_live_credentials.dart';
import '../domain/stream_credential_normalizer.dart';
import '../domain/streaming_enums.dart';
import '../domain/streaming_mode.dart';
import '../services/stream_platform_service.dart';

/// Result of preparing or starting a broadcast session.
class BroadcastSessionResult {
  const BroadcastSessionResult({
    required this.config,
    this.credentials,
    this.errorMessage,
  });

  final StreamStudioConfig config;
  final StreamLiveCredentials? credentials;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

/// Orchestrates credential resolution, native RTMP publish, and external encoder mode.
class BroadcastSessionController {
  BroadcastSessionController({
    required StreamService streamService,
    required StreamDestinationRegistry destinationRegistry,
    required MatchRepository matchRepository,
  })  : _streamService = streamService,
        _destinations = destinationRegistry,
        _matchRepository = matchRepository;

  final StreamService _streamService;
  final StreamDestinationRegistry _destinations;
  final MatchRepository _matchRepository;

  /// Resolves RTMP credentials via OAuth/API or manual entry.
  Future<BroadcastSessionResult> resolveCredentials(
    StreamStudioConfig config,
  ) async {
    final normalized = _normalizeConfig(config);
    final provider = _destinations.forPlatform(normalized.platform);

    // Linked YouTube with no stream key — create a broadcast automatically.
    if (normalized.platform == StreamPlatform.youtube &&
        normalized.youtubeBroadcastId.isEmpty &&
        normalized.youtubeChannelId.isNotEmpty &&
        normalized.streamKey.trim().isEmpty &&
        provider.supportsOAuth) {
      try {
        final creds = await provider.createLiveBroadcast(normalized);
        if (creds != null) {
          return BroadcastSessionResult(
            config: _applyCredentials(normalized, creds),
            credentials: creds,
          );
        }
      } on StreamPlatformException catch (e) {
        if (normalized.streamKey.trim().isEmpty) {
          return BroadcastSessionResult(
            config: normalized,
            errorMessage: e.message,
          );
        }
      }
    }

    if (normalized.streamKey.trim().isNotEmpty) {
      final manual = await provider.resolveManualCredentials(normalized);
      if (manual != null) {
        return BroadcastSessionResult(
          config: _applyCredentials(normalized, manual),
          credentials: manual,
        );
      }
    }

    try {
      final creds = await provider.createLiveBroadcast(normalized);
      if (creds == null) {
        return BroadcastSessionResult(
          config: normalized,
          errorMessage: provider.supportsOAuth
              ? 'Sign in and link ${provider.label} first'
              : 'Enter RTMP URL and stream key',
        );
      }
      return BroadcastSessionResult(
        config: _applyCredentials(normalized, creds),
        credentials: creds,
      );
    } on StreamPlatformException catch (e) {
      return BroadcastSessionResult(
        config: normalized,
        errorMessage: e.message,
      );
    }
  }

  /// Starts native camera RTMP or marks external encoder session live.
  Future<BroadcastSessionResult> startBroadcast({
    required String matchId,
    required StreamStudioConfig config,
    required MatchModel match,
  }) async {
    var workingConfig = _normalizeConfig(config);
    if (!workingConfig.orientationLocked) {
      workingConfig = workingConfig.copyWith(orientationLocked: true);
    }

    final credsResult = await resolveCredentials(workingConfig);
    if (!credsResult.isSuccess) return credsResult;
    var resolved = credsResult.config;

    if (resolved.streamKey.trim().isEmpty) {
      return BroadcastSessionResult(
        config: resolved,
        errorMessage: 'Enter or create a stream key',
      );
    }

    if (resolved.rtmpUrl.trim().isEmpty) {
      return BroadcastSessionResult(
        config: resolved,
        errorMessage: 'Select an RTMP server URL',
      );
    }

    await _streamService.lockOrientation(resolved.orientation);

    if (resolved.streamingMode == StreamingMode.externalEncoder) {
      await _persistStreamMeta(
        matchId: matchId,
        match: match,
        config: resolved,
        status: StreamStatus.live,
      );
      return BroadcastSessionResult(
        config: resolved,
        credentials: credsResult.credentials,
      );
    }

    try {
      String? recordPath;
      if (resolved.recordLocally) {
        recordPath = await StreamService.defaultRecordingPath(matchId);
      }
      await _streamService.startStream(
        rtmpUrl: resolved.rtmpUrl,
        streamKey: resolved.streamKey,
        bitrate: resolved.effectiveBitrateKbps * 1024,
        resolution: resolved.resolution,
        localRecordingPath: recordPath,
      );

      if (!_streamService.isStreaming) {
        await _streamService.stopStream();
        await _streamService.resumePreviewAfterStreamEnd();
        return BroadcastSessionResult(
          config: resolved,
          errorMessage:
              'RTMP connection failed. Check server URL, stream key, and network.',
        );
      }

      await _persistStreamMeta(
        matchId: matchId,
        match: match,
        config: resolved,
        status: StreamStatus.live,
      );
      return BroadcastSessionResult(
        config: resolved.copyWith(orientationLocked: true),
        credentials: credsResult.credentials,
      );
    } catch (e) {
      await _streamService.stopStream();
      await _streamService.resumePreviewAfterStreamEnd();
      return BroadcastSessionResult(
        config: resolved,
        errorMessage: '$e',
      );
    }
  }

  Future<void> endBroadcast({
    required String matchId,
    required StreamStudioConfig config,
    required MatchModel match,
    required bool wasNativeStream,
  }) async {
    if (wasNativeStream) {
      await _streamService.stopStream();
      await _streamService.resumePreviewAfterStreamEnd();
    }
    await _persistStreamMeta(
      matchId: matchId,
      match: match,
      config: config,
      status: StreamStatus.ended,
    );
  }

  StreamLiveCredentials? credentialsFromConfig(StreamStudioConfig config) {
    if (config.streamKey.trim().isEmpty) return null;
    return StreamLiveCredentials(
      rtmpUrl: config.rtmpUrl,
      streamKey: config.streamKey,
      watchUrl: config.youtubeWatchUrl,
      broadcastId: config.youtubeBroadcastId,
    );
  }

  /// Public overlay browser source for OBS (transparent scoreboard page).
  static String overlayBrowserSourceUrl(String matchId) {
    return 'https://${DeepLinkUtils.firebaseHostingHost}/live/$matchId';
  }

  StreamStudioConfig _applyCredentials(
    StreamStudioConfig config,
    StreamLiveCredentials creds,
  ) {
    return config.copyWith(
      rtmpUrl: creds.rtmpUrl,
      streamKey: creds.streamKey,
      youtubeWatchUrl: creds.watchUrl.isNotEmpty
          ? creds.watchUrl
          : config.youtubeWatchUrl,
      youtubeBroadcastId: creds.broadcastId.isNotEmpty
          ? creds.broadcastId
          : config.youtubeBroadcastId,
    );
  }

  StreamStudioConfig _normalizeConfig(StreamStudioConfig config) {
    final normalized = StreamCredentialNormalizer.normalize(
      rtmpUrl: config.rtmpUrl,
      streamKey: config.streamKey,
      platform: config.platform,
    );
    return config.copyWith(
      rtmpUrl: normalized.rtmpUrl,
      streamKey: normalized.streamKey,
    );
  }

  Future<void> _persistStreamMeta({
    required String matchId,
    required MatchModel match,
    required StreamStudioConfig config,
    required StreamStatus status,
  }) async {
    final destination = switch (config.platform) {
      StreamPlatform.customRtmp => StreamDestination.customRtmp,
      StreamPlatform.youtube => StreamDestination.youtube,
      StreamPlatform.facebook => StreamDestination.youtube,
      StreamPlatform.twitch => StreamDestination.youtube,
    };

    final stream = StreamMetadataModel(
      status: status,
      destination: destination,
      rtmpUrl: config.rtmpUrl,
      streamKey: config.streamKey,
      startedAt:
          status == StreamStatus.live ? DateTime.now() : match.stream.startedAt,
      youtubeWatchUrl: config.youtubeWatchUrl.isEmpty
          ? match.stream.youtubeWatchUrl
          : config.youtubeWatchUrl,
      webrtcEnabled: match.stream.webrtcEnabled,
    );

    await _matchRepository.updateStreamMetadata(matchId, stream);
  }
}
