import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/ball_event_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/stream_service.dart';
import '../../../shared/providers/providers.dart';
import '../data/models/stream_overlay_theme.dart';
import '../data/models/stream_studio_config.dart';
import '../data/active_stream_session.dart';
import '../data/services/stream_overlay_burn_in_service.dart';
import '../obs/presentation/obs_setup_section.dart';
import '../domain/streaming_enums.dart';
import '../domain/streaming_mode.dart';
import 'providers/streaming_studio_providers.dart';
import 'widgets/studio/stream_go_live_sheet.dart';
import 'widgets/studio/stream_studio_overlay.dart';
import 'widgets/health/stream_live_chat_panel.dart';
import 'widgets/camera/stream_camera_preview.dart';
import 'widgets/health/stream_health_panel.dart';
import 'widgets/end_live_stream_dialog.dart';
import 'widgets/leave_stream_studio_dialog.dart';
import 'widgets/stream_reconnecting_banner.dart';
import 'widgets/stream_connection_lost_banner.dart';
import 'widgets/stream_studio_compositor.dart';
import '../services/stream_lifecycle_log.dart';
import '../services/stream_platform_service.dart';
import 'providers/post_match_controller.dart';

/// Pre-live streaming dashboard + live broadcast studio for a match.
class StreamingDashboardScreen extends ConsumerStatefulWidget {
  const StreamingDashboardScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<StreamingDashboardScreen> createState() =>
      _StreamingDashboardScreenState();
}

class _StreamingDashboardScreenState
    extends ConsumerState<StreamingDashboardScreen> with WidgetsBindingObserver {
  bool _cameraLoading = true;
  String? _cameraError;
  bool _isLive = false;
  bool _startingLive = false;
  bool _endingStream = false;
  Timer? _heartbeatTimer;
  Timer? _youtubeStatusTimer;
  String? _lastEventId;
  int _lastEventCount = 0;
  int _lastEventSequence = -1;
  int _previewSession = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyStudioSystemUi();
    // Camera preview is portrait-native — never rotate the Activity in studio.
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapStudio());
    });
  }

  Future<void> _bootstrapStudio() async {
    await _applySavedStudioPreferences();
    if (!mounted) return;
    await _initCamera();
    if (!mounted) return;
    _resumeIfLive();
  }

  bool _nativeSessionActive(StreamService service) =>
      service.liveSessionActive ||
      service.isStreaming ||
      service.isRtmpLive ||
      (service.isReconnecting && !service.reconnectExhausted);

  /// Restores scorebug burn-in after RTMP (re)connect — all native manual/auto modes.
  void _wireNativeOverlayHandlers() {
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    if (config.streamingMode != StreamingMode.nativeCamera) return;

    final burnIn = ref.read(streamOverlayBurnInServiceProvider);
    final stream = ref.read(streamServiceProvider);
    stream.onRtmpConnected = () {
      burnIn.schedulePush();
      unawaited(burnIn.recoverAfterLifecycle());
      unawaited(stream.reconnectPreview(retries: 6));
      final cfg = ref.read(streamStudioConfigProvider(widget.matchId));
      if (cfg.platform == StreamPlatform.youtube &&
          cfg.broadcastSetupMode == StreamBroadcastSetupMode.automatic &&
          cfg.youtubeBroadcastId.isNotEmpty) {
        unawaited(_publishYouTubeBroadcast(cfg));
      }
    };
  }

  void _onRtmpReconnectCompleted() {
    final service = ref.read(streamServiceProvider);
    if (!_nativeSessionActive(service)) return;
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    if (config.streamingMode != StreamingMode.nativeCamera) return;
    final burnIn = ref.read(streamOverlayBurnInServiceProvider);
    burnIn.schedulePush();
    unawaited(burnIn.recoverAfterLifecycle());
  }

  void _ensureLiveUiForNativeSession() {
    if (_isLive) return;
    final service = ref.read(streamServiceProvider);
    if (!_nativeSessionActive(service)) return;
    setState(() => _isLive = true);
    _startHeartbeat();
    unawaited(ActiveStreamSession.setActive(widget.matchId));
    _wireNativeOverlayHandlers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isLive) return;
      ref.read(streamOverlayBurnInServiceProvider).startLiveRefresh();
    });
  }

  Future<void> _applySavedStudioPreferences() async {
    if (_isLive) return;
    final repo = ref.read(streamStudioRepositoryProvider);
    final saved = await repo.loadLastStudioPreferences();
    ref.read(streamStudioConfigProvider(widget.matchId).notifier).update(
          (c) => applySavedStudioPreferences(c, saved),
        );
    try {
      final channels = await ref
          .read(streamPlatformServiceProvider)
          .fetchYouTubeChannels();
      if (!mounted || channels.isEmpty) return;
      syncYouTubeChannelToStudioConfig(
        ref,
        widget.matchId,
        channels: channels,
      );
      await persistStudioConfigPreferences(ref, widget.matchId);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    if (config.streamingMode == StreamingMode.externalEncoder) return;
    if (!StreamService.isPlatformSupported) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Never tear down camera/encoder while live — foreground service holds process.
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = ref.read(streamServiceProvider);
      final sessionLive = _nativeSessionActive(service);
      if (sessionLive) {
        unawaited(_resumeLiveSessionUi());
        return;
      }

      if (service.isInitialized) {
        unawaited(_recoverCameraAfterOAuthReturn());
        return;
      }
      if (_cameraLoading) return;

      setState(() => _previewSession++);
      unawaited(_recoverCameraAfterResume());
    });
  }

  /// After Google Sign-In / system overlays tear down the GL surface.
  Future<void> _recoverCameraAfterOAuthReturn() async {
    if (!mounted) return;
    final service = ref.read(streamServiceProvider);
    try {
      await service.recoverPreview();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _cameraLoading = false;
        _cameraError = service.lastError;
      });
    }
  }

  Future<void> _resumeLiveSessionUi() async {
    if (!mounted) return;
    final service = ref.read(streamServiceProvider);
    final burnIn = ref.read(streamOverlayBurnInServiceProvider);

    burnIn.startLiveRefresh();

    try {
      await service.reconnectPreview(retries: 8);
      StreamLifecycleLog.cameraReconnected();
    } catch (_) {}

    if (!mounted) return;
    await burnIn.recoverAfterLifecycle();
    if (mounted) setState(() {});
  }

  Future<void> _recoverCameraAfterResume() async {
    if (!mounted) return;
    final service = ref.read(streamServiceProvider);
    if (_isLive && service.isStreaming) {
      await service.reconnectPreview(retries: 8);
      if (mounted) {
        await ref.read(streamOverlayBurnInServiceProvider).recoverAfterLifecycle();
      }
      return;
    }

    if (service.isInitialized) {
      await service.recoverPreview();
      if (mounted) {
        setState(() {
          _cameraLoading = false;
          _cameraError = service.lastError;
        });
      }
      return;
    }

    setState(() {
      _cameraLoading = true;
      _cameraError = null;
    });

    try {
      await service.resumePreviewAfterBackground();
      if (!mounted) return;
      setState(() {
        _cameraLoading = !service.isInitialized;
        _cameraError = service.lastError;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraLoading = false;
          _cameraError = '$e';
        });
      }
    }
  }

  Future<void> _initCamera() async {
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    if (config.streamingMode == StreamingMode.externalEncoder) {
      setState(() {
        _cameraLoading = false;
        _cameraError = null;
      });
      return;
    }

    if (!StreamService.isPlatformSupported) {
      setState(() {
        _cameraLoading = false;
        _cameraError = 'Use an Android or iOS device to stream.';
      });
      return;
    }
    try {
      await ref.read(streamServiceProvider).initCamera(
            lensIndex: config.selectedLensIndex,
            resolution: config.resolution,
            orientation: config.orientation,
            lockOrientation: config.orientationLocked,
            enableAudio: config.micEnabled,
          );
      if (mounted) {
        final service = ref.read(streamServiceProvider);
        setState(() {
          _cameraLoading = !service.isInitialized;
          _cameraError = service.lastError;
        });
        if (service.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(streamServiceProvider).refreshDeviceZoomSteps().then((_) {
              if (mounted) setState(() {});
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraLoading = false;
          _cameraError = '$e';
        });
      }
    }
  }

  void _resumeIfLive() {
    final service = ref.read(streamServiceProvider);
    if (!_nativeSessionActive(service)) return;

    setState(() => _isLive = true);
    _startHeartbeat();
    _startYouTubeStatusMonitor();
    unawaited(ActiveStreamSession.setActive(widget.matchId));
    if (service.isRtmpLive && !service.liveSessionActive) {
      final config = ref.read(streamStudioConfigProvider(widget.matchId));
      final title = config.title.trim().isNotEmpty
          ? config.title.trim()
          : 'CrickFlow Live';
      unawaited(service.beginLiveSession(title: title));
    }
    _wireNativeOverlayHandlers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isLive) return;
      ref.read(streamOverlayBurnInServiceProvider).startLiveRefresh();
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    if (config.streamingMode == StreamingMode.externalEncoder) return;
    if (!StreamService.isPlatformSupported) return;

    final service = ref.read(streamServiceProvider);
    if (!service.isInitialized && !_isLive) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isLive && (service.isStreaming || service.liveSessionActive)) {
        // Insets/keyboard changes only — do not rebuild the GL pipeline while live.
        ref.read(streamOverlayBurnInServiceProvider).schedulePush();
      }
    });
  }

  void _processBallEvents(List<BallEventModel> events) {
    if (events.isEmpty) {
      _lastEventCount = 0;
      _lastEventId = null;
      _lastEventSequence = -1;
      ref.read(activeEventOverlayProvider(widget.matchId).notifier).state = null;
      ref.read(pendingSidePanelOverlayProvider(widget.matchId).notifier).state =
          null;
      return;
    }

    final latest = events.last;
    final isUndo = _lastEventCount > 0 &&
        (events.length < _lastEventCount ||
            latest.sequence < _lastEventSequence);

    if (isUndo) {
      _lastEventId = latest.id;
      _lastEventCount = events.length;
      _lastEventSequence = latest.sequence;
      ref.read(activeEventOverlayProvider(widget.matchId).notifier).state = null;
      ref.read(pendingSidePanelOverlayProvider(widget.matchId).notifier).state =
          null;
      return;
    }

    if (latest.id == _lastEventId) return;

    _lastEventId = latest.id;
    _lastEventCount = events.length;
    _lastEventSequence = latest.sequence;

    final previous = events.length >= 2 ? events[events.length - 2] : null;
    final detector = ref.read(streamEventDetectorProvider);
    final graphic = detector.detect(latest, previous: previous);
    if (graphic != null) {
      final active =
          ref.read(activeEventOverlayProvider(widget.matchId));
      if (active != null) {
        if (graphic.isSidePanelEvent && !active.isSidePanelEvent) {
          ref
              .read(pendingSidePanelOverlayProvider(widget.matchId).notifier)
              .state = graphic;
        }
        return;
      }
      ref.read(activeEventOverlayProvider(widget.matchId).notifier).state =
          graphic;
      if (_isLive) {
        _maybeSaveAutoReplayMarker(graphic, latest);
      }
    }
  }

  Future<void> _maybeSaveAutoReplayMarker(
    StreamEventOverlay graphic,
    BallEventModel event,
  ) async {
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    if (!config.autoReplayMarkers) return;

    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    final started = match?.stream.startedAt;
    final offsetMs = started == null
        ? 0
        : DateTime.now().difference(started).inMilliseconds;

    final kind = switch (graphic.type) {
      StreamEventOverlayType.wicket => ReplayMarkerKind.wicket,
      StreamEventOverlayType.hugeSix => ReplayMarkerKind.six,
      StreamEventOverlayType.boundaryFour => ReplayMarkerKind.four,
      StreamEventOverlayType.century => ReplayMarkerKind.century,
      StreamEventOverlayType.fiftyRuns => ReplayMarkerKind.milestone,
      _ => ReplayMarkerKind.milestone,
    };

    await saveReplayMarker(
      ref: ref,
      matchId: widget.matchId,
      kind: kind,
      label: graphic.subtitle.isNotEmpty ? graphic.subtitle : graphic.title,
      streamOffsetMs: offsetMs,
      ballEventId: event.id,
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(matchRepositoryProvider).touchStreamHeartbeat(widget.matchId);
    });
  }

  void _startYouTubeStatusMonitor() {
    _youtubeStatusTimer?.cancel();
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    if (config.platform != StreamPlatform.youtube) return;
    if (config.broadcastSetupMode != StreamBroadcastSetupMode.automatic) return;
    if (config.youtubeBroadcastId.isEmpty) return;

    _youtubeStatusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_pollYouTubeBroadcastEnded());
    });
    unawaited(_pollYouTubeBroadcastEnded());
  }

  void _stopYouTubeStatusMonitor() {
    _youtubeStatusTimer?.cancel();
    _youtubeStatusTimer = null;
  }

  Future<void> _pollYouTubeBroadcastEnded() async {
    if (!mounted || !_isLive) return;
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    final broadcastId = config.youtubeBroadcastId;
    if (broadcastId.isEmpty) return;

    final status = await ref
        .read(streamPlatformServiceProvider)
        .fetchYouTubeBroadcastStatus(broadcastId: broadcastId);
    if (!mounted || !_isLive || status == null) return;
    if (status.isEnded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('YouTube live stream ended — stopping broadcast'),
          ),
        );
      }
      await _endStream();
    }
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Removes the Android platform view before native camera dispose/reopen.
  Future<void> _switchLens(int lensIndex) async {
    if (_cameraLoading) return;
    ref
        .read(streamStudioConfigProvider(widget.matchId).notifier)
        .update((c) => c.copyWith(selectedLensIndex: lensIndex));

    try {
      await ref.read(streamServiceProvider).switchLens(lensIndex);
      if (mounted) {
        final service = ref.read(streamServiceProvider);
        ref
            .read(streamStudioConfigProvider(widget.matchId).notifier)
            .update((c) => c.copyWith(selectedLensIndex: service.selectedLensIndex));
        setState(() {
          _cameraError = service.lastError;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!_isLive) _previewSession++;
          _cameraError = '$e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera switch failed: $e')),
        );
      }
    }
  }

  void _openBroadcastSetup(MatchModel match) {
    showStreamBroadcastSetupSheet(
      context,
      matchId: widget.matchId,
      match: match,
      canStart: ref.read(streamCanStartProvider(widget.matchId)),
      onStartLive: _goLive,
    );
  }

  Future<void> _goLive() async {
    if (_startingLive || _isLive) return;

    final canStart = ref.read(streamCanStartProvider(widget.matchId));
    if (!canStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not authorized to start this stream'),
        ),
      );
      return;
    }

    var config = ref.read(streamStudioConfigProvider(widget.matchId));

    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null) return;

    setState(() {
      _cameraError = null;
      _startingLive = true;
    });

    try {
      final controller = ref.read(broadcastSessionControllerProvider);
      final result = await controller.startBroadcast(
        matchId: widget.matchId,
        config: config,
        match: match,
      );

      if (!result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage ?? 'Stream failed')),
          );
        }
        return;
      }

      config = result.config;
      ref.read(streamStudioConfigProvider(widget.matchId).notifier).update(
            (c) => config,
          );

      if (config.usesManualBroadcastSetup) {
        await rememberStreamKeyForConfig(
          ref.read(streamStudioRepositoryProvider),
          config,
        );
        ref.invalidate(streamKeyHistoryProvider);
      }

      await rememberLastStudioPreferencesForConfig(
        ref.read(streamStudioRepositoryProvider),
        config,
      );

      _startHeartbeat();
      _startYouTubeStatusMonitor();
      await ActiveStreamSession.setActive(widget.matchId);
      final streamTitle = config.title.trim().isNotEmpty
          ? config.title.trim()
          : 'CrickFlow Live';
      await ref.read(streamServiceProvider).beginLiveSession(title: streamTitle);
      if (mounted) {
        setState(() => _isLive = true);
        if (config.platform == StreamPlatform.youtube &&
            config.broadcastSetupMode == StreamBroadcastSetupMode.automatic) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Starting broadcast — connecting to YouTube…'),
              duration: Duration(seconds: 4),
            ),
          );
          unawaited(_publishYouTubeBroadcast(config));
        }
      }
      if (config.streamingMode == StreamingMode.nativeCamera) {
        _wireNativeOverlayHandlers();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_isLive) return;
          final burnIn = ref.read(streamOverlayBurnInServiceProvider);
          burnIn.startLiveRefresh();
          burnIn.schedulePush();
        });
      }
    } finally {
      if (mounted) setState(() => _startingLive = false);
    }
  }

  Future<void> _publishYouTubeBroadcast(StreamStudioConfig config) async {
    if (config.youtubeBroadcastId.isEmpty) return;
    try {
      await ref.read(streamPlatformServiceProvider).startYouTubeLiveBroadcast(
            broadcastId: config.youtubeBroadcastId,
            streamId: config.youtubeStreamId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stream is live on YouTube'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on StreamPlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('YouTube go-live: ${e.message}'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _endStream() async {
    if (_endingStream) return;
    _endingStream = true;
    _stopHeartbeat();
    _stopYouTubeStatusMonitor();
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    if (match != null) {
      final wasNative =
          config.streamingMode == StreamingMode.nativeCamera;
      await ref.read(broadcastSessionControllerProvider).endBroadcast(
            matchId: widget.matchId,
            config: config,
            match: match,
            wasNativeStream: wasNative && _isLive,
          );
    } else {
      await ref.read(streamServiceProvider).stopStream();
    }
    await ref.read(streamOverlayBurnInServiceProvider).clear();
    ref.read(streamServiceProvider).onRtmpConnected = null;
    await ref.read(streamServiceProvider).endLiveSession();
    await ActiveStreamSession.clear();
    await ref.read(streamServiceProvider).resetToPortraitUi();
    if (mounted) {
      final service = ref.read(streamServiceProvider);
      setState(() {
        _isLive = false;
        _cameraLoading = false;
        _cameraError = service.lastError;
      });
      // Brief delay so portrait rotation completes before leaving stream studio.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      context.go('/match/${widget.matchId}?tab=live');
    }
  }

  void _applyStudioSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  Future<void> _handleBackWhileLive() async {
    final end = await showEndLiveStreamDialog(context);
    if (end == true && mounted) {
      await _endStream();
    }
  }

  Future<void> _handleBackFromStudio() async {
    final leave = await showLeaveStreamStudioDialog(context);
    if (leave != true || !mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/match/${widget.matchId}?tab=live');
    }
  }

  Future<void> _handleNavigateBack() async {
    if (_isLive) {
      await _handleBackWhileLive();
    } else {
      await _handleBackFromStudio();
    }
  }

  Future<void> _retryConnection() async {
    final stream = ref.read(streamServiceProvider);

    // Always republish the same RTMP URL/key from go-live — never mint a new
    // YouTube broadcast on retry (viewers stay on the same event).
    await stream.retryConnection();

    if (!mounted) return;
    await ref.read(streamOverlayBurnInServiceProvider).recoverAfterLifecycle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _stopYouTubeStatusMonitor();
    if (!_isLive) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      _restoreSystemUi();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(matchProvider(widget.matchId), (prev, next) {
      final match = next.valueOrNull;
      if (match == null) return;
      final service = ref.read(streamServiceProvider);
      final nativeLive = _nativeSessionActive(service);
      if (nativeLive && !_isLive) {
        _ensureLiveUiForNativeSession();
      } else if (_isLive && !nativeLive && !service.isReconnecting) {
        setState(() => _isLive = false);
        _stopHeartbeat();
        unawaited(ActiveStreamSession.clear());
      }
    });

    ref.listen(
      streamServiceProvider.select((s) => (s.isReconnecting, s.isRtmpLive)),
      (prev, next) {
        if (prev == null) return;
        final service = ref.read(streamServiceProvider);
        if (service.isReconnecting && _nativeSessionActive(service)) {
          _ensureLiveUiForNativeSession();
        }
        if (prev.$1 && !next.$1 && next.$2) {
          _ensureLiveUiForNativeSession();
          _onRtmpReconnectCompleted();
        }
      },
    );

    ref.listen(ballEventsProvider(widget.matchId), (prev, next) {
      final events = next.valueOrNull;
      if (events != null) _processBallEvents(events);
    });

    ref.listen(postMatchControllerProvider(widget.matchId), (prev, next) {
      if (next != PostMatchPhase.complete ||
          prev == PostMatchPhase.complete ||
          !_isLive) {
        return;
      }
      unawaited(_endStream());
    });

    ref.listen(
      streamStudioConfigProvider(widget.matchId).select((c) => c.streamingMode),
      (prev, next) {
        if (prev == next || _isLive) return;
        if (next == StreamingMode.nativeCamera &&
            prev == StreamingMode.externalEncoder) {
          setState(() {
            _cameraLoading = true;
            _cameraError = null;
          });
          _initCamera();
        } else if (next == StreamingMode.externalEncoder) {
          setState(() {
            _cameraLoading = false;
            _cameraError = null;
          });
        }
      },
    );

    final matchAsync = ref.watch(matchProvider(widget.matchId));
    final overlayAsync = ref.watch(overlayProvider(widget.matchId));
    final canStart = ref.watch(streamCanStartProvider(widget.matchId));
    final config = ref.watch(streamStudioConfigProvider(widget.matchId));
    final service = ref.watch(streamServiceProvider);
    final broadcastController = ref.watch(broadcastSessionControllerProvider);
    final obsCredentials = broadcastController.credentialsFromConfig(config);
    final isObs = config.streamingMode == StreamingMode.externalEncoder;
    final cameraReady = isObs || (!_cameraLoading && service.isInitialized);

    return matchAsync.when(
      data: (match) {
        if (match == null) {
          return const Scaffold(body: Center(child: Text('Match not found')));
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _handleNavigateBack();
          },
          child: Scaffold(
          backgroundColor: Colors.black,
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_isLive && service.isReconnecting && !service.reconnectExhausted && !isObs)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: StreamReconnectingBanner(),
                ),
              if (_isLive && service.reconnectExhausted && !isObs)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: StreamConnectionLostBanner(
                    onRetry: _retryConnection,
                    onEndStream: _endStream,
                  ),
                ),
              if (isObs)
                SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      72,
                      16,
                      _isLive ? 16 : 120,
                    ),
                    child: Column(
                      children: [
                        ObsSetupSection(
                          matchId: widget.matchId,
                          credentials: obsCredentials,
                        ),
                        if (_isLive) ...[
                          const SizedBox(height: 12),
                          const StreamHealthPanel(),
                        ],
                      ],
                    ),
                  ),
                )
              else
                StreamStudioCompositor(
                  key: ValueKey('stream_studio_$_previewSession'),
                  matchId: widget.matchId,
                  overlay: overlayAsync.valueOrNull,
                  onPostMatchAutoEnd: () {
                    if (_isLive) unawaited(_endStream());
                  },
                  cameraPreview: StreamCameraPreview(
                    key: ValueKey('stream_camera_$_previewSession'),
                    matchId: widget.matchId,
                    loading: _cameraLoading,
                    error: _cameraError,
                    fill: true,
                  ),
                ),
              StreamStudioOverlay(
                matchId: widget.matchId,
                match: match,
                canStart: _isLive ? true : canStart,
                onLensSelected: _switchLens,
                onGoLive: _goLive,
                onOpenBroadcastSetup: () => _openBroadcastSetup(match),
                cameraReady: _isLive ? true : cameraReady,
                isLive: _isLive,
                isStartingLive: _startingLive,
                isObsMode: isObs,
                onNavigateBack: _handleNavigateBack,
                onEndStream: _isLive ? _endStream : null,
                onMarkReplay: _isLive ? () => _markReplay(match) : null,
              ),
              if (_isLive && !isObs)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamLiveChatPanel(matchId: widget.matchId),
                    ],
                  ),
                ),
            ],
          ),
        ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }

  Future<void> _markReplay(MatchModel match) async {
    final started = match.stream.startedAt;
    final offsetMs = started == null
        ? 0
        : DateTime.now().difference(started).inMilliseconds;
    await saveReplayMarker(
      ref: ref,
      matchId: widget.matchId,
      kind: ReplayMarkerKind.custom,
      label: 'Manual marker',
      streamOffsetMs: offsetMs,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Replay marker saved')),
      );
    }
  }
}
