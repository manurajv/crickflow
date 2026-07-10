import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/repositories/match_repository.dart';
import '../../../../data/services/stream_service.dart';
import '../data/models/stream_studio_config.dart';
import '../domain/destinations/stream_destination_provider.dart';
import '../domain/destinations/stream_destination_registry.dart';
import '../domain/destinations/stream_live_credentials.dart';
import '../domain/stream_credential_normalizer.dart';
import '../domain/streaming_enums.dart';
import '../domain/streaming_mode.dart';
import '../services/stream_platform_service.dart';
import '../services/stream_youtube_thumbnail_service.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../domain/streaming/stream_playback_merger.dart';

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
    required Ref ref,
  })  : _streamService = streamService,
        _destinations = destinationRegistry,
        _matchRepository = matchRepository,
        _ref = ref;

  final StreamService _streamService;
  final StreamDestinationRegistry _destinations;
  final MatchRepository _matchRepository;
  final Ref _ref;

  /// Resolves RTMP credentials via OAuth/API or manual entry.
  Future<BroadcastSessionResult> resolveCredentials(
    StreamStudioConfig config, {
    required String matchId,
  }) async {
    final normalized = _normalizeConfig(config).copyWith(goLiveImmediately: true);
    final provider = _destinations.forPlatform(normalized.platform);

    if (normalized.platform == StreamPlatform.youtube) {
      return _resolveYouTubeCredentials(normalized, provider, matchId);
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

  Future<BroadcastSessionResult> _resolveYouTubeCredentials(
    StreamStudioConfig config,
    StreamDestinationProvider provider,
    String matchId,
  ) async {
    if (config.broadcastSetupMode == StreamBroadcastSetupMode.manual) {
      if (config.streamKey.trim().isEmpty) {
        return BroadcastSessionResult(
          config: config,
          errorMessage: 'Enter your YouTube stream key from Studio',
        );
      }
      final manual = await provider.resolveManualCredentials(config);
      if (manual == null) {
        return BroadcastSessionResult(
          config: config,
          errorMessage: 'Enter a valid YouTube stream key',
        );
      }
      return BroadcastSessionResult(
        config: _applyCredentials(config, manual),
        credentials: manual,
      );
    }

    if (config.youtubeChannelId.isEmpty) {
      return BroadcastSessionResult(
        config: config,
        errorMessage: 'Link your YouTube account in Broadcast setup first',
      );
    }

    try {
      final thumbnail = await _ref
          .read(streamYouTubeThumbnailServiceProvider)
          .resolvePayload(ref: _ref, matchId: matchId, config: config);
      final creds = await provider.createLiveBroadcast(
        config,
        thumbnailPayload: thumbnail,
      );
      if (creds != null) {
        return BroadcastSessionResult(
          config: _applyCredentials(config, creds),
          credentials: creds,
        );
      }
      return BroadcastSessionResult(
        config: config,
        errorMessage:
            'Could not create a YouTube live event. Check your linked account '
            'and try again.',
      );
    } on StreamPlatformException catch (e) {
      return BroadcastSessionResult(
        config: config,
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
    final workingConfig = _normalizeConfig(config);
    final actor = _streamActor();

    // External encoder (OBS / vMix): the encoder owns the RTMP connection and
    // stream key. The app only marks the match live and serves the overlay
    // browser source — no stream key or credential resolution needed here.
    if (workingConfig.streamingMode == StreamingMode.externalEncoder) {
      await _persistStreamMeta(
        matchId: matchId,
        match: match,
        config: workingConfig,
        status: StreamStatus.live,
        addedByUserId: actor.uid,
        addedByName: actor.name,
      );
      return BroadcastSessionResult(config: workingConfig);
    }

    final credsResult = await resolveCredentials(workingConfig, matchId: matchId);
    if (!credsResult.isSuccess) return credsResult;
    var resolved = credsResult.config;

    // 1080p only works on YouTube automatic; manual RTMP keys stall at 1080p.
    final allowedResolutions = supportedStreamResolutionsFor(
      platform: resolved.platform,
      setupMode: resolved.broadcastSetupMode,
    );
    if (!allowedResolutions.contains(resolved.resolution)) {
      resolved = resolved.copyWith(resolution: kRecommendedStreamResolution);
    }

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

    var rtmpConnected = false;
    try {
      // Local recording is hidden/disabled for now — never record until the
      // feature is completed, regardless of any persisted recordLocally flag.
      const String? recordPath = null;
      await _streamService.startStream(
        rtmpUrl: resolved.rtmpUrl,
        streamKey: resolved.streamKey,
        bitrate: resolved.effectiveBitrateKbps * 1024,
        resolution: resolved.resolution,
        localRecordingPath: recordPath,
        platform: resolved.platform,
      );
      rtmpConnected = true;

      final streamTitle = resolved.title.trim().isNotEmpty
          ? resolved.title.trim()
          : 'CrickFlow Live';
      try {
        await _streamService.beginLiveSession(title: streamTitle);
      } catch (e) {
        debugPrint('[CrickFlowBroadcast] beginLiveSession failed (keeping stream live): $e');
      }
      try {
        await _streamService.setMicEnabled(resolved.micEnabled);
      } catch (e) {
        debugPrint('[CrickFlowBroadcast] setMicEnabled failed (keeping stream live): $e');
      }

      try {
        await _persistStreamMeta(
          matchId: matchId,
          match: match,
          config: resolved,
          status: StreamStatus.live,
          addedByUserId: actor.uid,
          addedByName: actor.name,
        );
      } catch (e) {
        // RTMP is already live — never tear down the encoder for a Firestore hiccup.
        debugPrint('[CrickFlowBroadcast] stream metadata persist failed: $e');
      }

      return BroadcastSessionResult(
        config: resolved.copyWith(orientationLocked: true),
        credentials: credsResult.credentials,
      );
    } catch (e) {
      if (!rtmpConnected) {
        if (_streamService.status != StreamStatus.idle) {
          await _streamService.stopStream();
        }
        await _streamService.resumePreviewAfterStreamEnd();
        final message = _streamService.lastError ??
            (e is StateError ? e.message : null) ??
            'Stream failed';
        return BroadcastSessionResult(
          config: resolved,
          errorMessage: message,
        );
      }
      debugPrint('[CrickFlowBroadcast] post-RTMP error (keeping stream live): $e');
      try {
        await _persistStreamMeta(
          matchId: matchId,
          match: match,
          config: resolved,
          status: StreamStatus.live,
          addedByUserId: actor.uid,
          addedByName: actor.name,
        );
      } catch (_) {}
      return BroadcastSessionResult(
        config: resolved.copyWith(orientationLocked: true),
        credentials: credsResult.credentials,
      );
    }
  }

  Future<void> endBroadcast({
    required String matchId,
    required StreamStudioConfig config,
    required MatchModel match,
    required bool wasNativeStream,
  }) async {
    final actor = _streamActor();

    if (wasNativeStream) {
      await _streamService.stopStream();
      await _streamService.endLiveSession();
      await _streamService.resumePreviewAfterStreamEnd();
    }
    if (config.platform == StreamPlatform.youtube &&
        config.broadcastSetupMode == StreamBroadcastSetupMode.automatic &&
        config.youtubeBroadcastId.isNotEmpty) {
      try {
        await StreamPlatformService().endYouTubeLive(
          broadcastId: config.youtubeBroadcastId,
        );
      } catch (_) {
        // RTMP stop may already trigger YouTube auto-stop; best-effort API end.
      }
    }
    try {
      await _persistStreamMeta(
        matchId: matchId,
        match: match,
        config: config,
        status: StreamStatus.ended,
        addedByUserId: actor.uid,
        addedByName: actor.name,
      );
    } catch (e) {
      debugPrint('[CrickFlowBroadcast] end metadata persist failed: $e');
    }
  }

  StreamLiveCredentials? credentialsFromConfig(StreamStudioConfig config) {
    if (config.streamKey.trim().isEmpty) return null;
    return StreamLiveCredentials(
      rtmpUrl: config.rtmpUrl,
      streamKey: config.streamKey,
      watchUrl: config.youtubeWatchUrl,
      broadcastId: config.youtubeBroadcastId,
      streamId: config.youtubeStreamId,
    );
  }

  /// Public overlay browser source for OBS — transparent, realtime scorebug page.
  static String overlayBrowserSourceUrl(String matchId) {
    return 'https://${DeepLinkUtils.firebaseHostingHost}/overlay/$matchId';
  }

  StreamStudioConfig _applyCredentials(
    StreamStudioConfig config,
    StreamLiveCredentials creds,
  ) {
    return config.copyWith(
      rtmpUrl: creds.rtmpUrl,
      streamKey: creds.streamKey,
      youtubeWatchUrl: creds.watchUrl.isNotEmpty ? creds.watchUrl : '',
      youtubeBroadcastId: creds.broadcastId,
      youtubeStreamId: creds.streamId,
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

  ({String? uid, String? name}) _streamActor() {
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    final uid = _ref.read(authStateProvider).value?.uid;
    return (uid: uid, name: profile?.effectiveName);
  }

  Future<void> _persistStreamMeta({
    required String matchId,
    required MatchModel match,
    required StreamStudioConfig config,
    required StreamStatus status,
    String? addedByUserId,
    String? addedByName,
  }) async {
    final destination = switch (config.platform) {
      StreamPlatform.customRtmp => StreamDestination.customRtmp,
      StreamPlatform.youtube => StreamDestination.youtube,
      StreamPlatform.facebook => StreamDestination.youtube,
      StreamPlatform.twitch => StreamDestination.youtube,
    };

    final watchUrl = config.youtubeWatchUrl.trim().isNotEmpty
        ? config.youtubeWatchUrl.trim()
        : match.stream.youtubeWatchUrl;
    final isGoingLive = status == StreamStatus.live;
    final isEnding = status == StreamStatus.ended;

    var playbackEntries = match.stream.playbackEntries;
    if (watchUrl != null &&
        watchUrl.isNotEmpty &&
        (isGoingLive || isEnding)) {
      playbackEntries = StreamPlaybackMerger.appendSession(
        existing: playbackEntries,
        url: watchUrl,
        isLive: isGoingLive,
        addedAt: isGoingLive ? DateTime.now() : null,
        addedByUserId: addedByUserId,
        addedByName: addedByName,
        forceNewSession: isGoingLive,
      );
    }

    final anyLive = playbackEntries.any((e) => e.isLive);
    final resolvedStatus = isEnding && anyLive ? StreamStatus.live : status;

    final stream = match.stream.copyWith(
      status: resolvedStatus,
      destination: destination,
      rtmpUrl: config.rtmpUrl,
      streamKey: config.streamKey,
      startedAt: isGoingLive ? DateTime.now() : match.stream.startedAt,
      youtubeWatchUrl: StreamPlaybackMerger.latestWatchUrl(playbackEntries) ??
          watchUrl ??
          match.stream.youtubeWatchUrl,
      playbackEntries: playbackEntries,
    );

    await _matchRepository.updateStreamMetadata(matchId, stream);
  }
}
