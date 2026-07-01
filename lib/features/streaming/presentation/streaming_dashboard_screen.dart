import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../data/models/ball_event_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/stream_service.dart';
import '../../../shared/providers/providers.dart';
import '../data/models/stream_overlay_theme.dart';
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
import 'widgets/stream_studio_compositor.dart';

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
  Timer? _heartbeatTimer;
  String? _lastEventId;
  int _previewSession = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
      _resumeIfLive();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    if (config.streamingMode == StreamingMode.externalEncoder) return;
    if (!StreamService.isPlatformSupported) return;

    setState(() => _previewSession++);
    unawaited(_recoverCameraAfterResume());
  }

  Future<void> _recoverCameraAfterResume() async {
    if (!mounted) return;
    final service = ref.read(streamServiceProvider);
    if (_isLive && service.isStreaming) return;

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
      if (service.isInitialized) {
        await service.refreshDeviceZoomSteps();
        if (mounted) setState(() {});
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
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    final service = ref.read(streamServiceProvider);
    if (match?.stream.status == StreamStatus.live ||
        service.status == StreamStatus.live) {
      setState(() => _isLive = true);
      _startHeartbeat();
      unawaited(ActiveStreamSession.setActive(widget.matchId));
    }
  }

  void _processBallEvents(List<BallEventModel> events) {
    if (events.isEmpty) return;
    final latest = events.last;
    if (latest.id == _lastEventId) return;
    _lastEventId = latest.id;
    final detector = ref.read(streamEventDetectorProvider);
    final graphic = detector.detect(latest);
    if (graphic != null) {
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
          _previewSession++;
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
    final canStart = ref.read(streamCanStartProvider(widget.matchId));
    if (!canStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not authorized to start this stream'),
        ),
      );
      return;
    }

    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null) return;

    var config = ref.read(streamStudioConfigProvider(widget.matchId));
    setState(() => _cameraError = null);

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

    _startHeartbeat();
    await ActiveStreamSession.setActive(widget.matchId);
    if (mounted) {
      setState(() => _isLive = true);
      if (config.platform == StreamPlatform.youtube) {
        final message = config.goLiveImmediately
            ? 'Stream is live on YouTube.'
            : 'Sending to YouTube. Open YouTube Studio, check the preview, '
                'then click Go live when you are ready.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 7)),
        );
      }
    }
    if (config.streamingMode == StreamingMode.nativeCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(streamOverlayBurnInServiceProvider).schedulePush();
      });
    }
  }

  Future<void> _endStream() async {
    _stopHeartbeat();
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    if (match != null) {
      final wasNative =
          config.streamingMode == StreamingMode.nativeCamera;
      await ref.read(broadcastSessionControllerProvider).endBroadcast(
            matchId: widget.matchId,
            config: config,
            match: match,
            wasNativeStream: wasNative && ref.read(streamServiceProvider).isStreaming,
          );
    } else {
      await ref.read(streamServiceProvider).stopStream();
    }
    await ref.read(streamOverlayBurnInServiceProvider).clear();
    await ActiveStreamSession.clear();
    if (mounted) {
      final service = ref.read(streamServiceProvider);
      setState(() {
        _isLive = false;
        _cameraLoading = !service.isInitialized;
        _cameraError = service.lastError;
      });
      // endBroadcast already reopened the camera — avoid tearing down the preview again.
      if (!service.isInitialized &&
          config.streamingMode == StreamingMode.nativeCamera) {
        setState(() => _previewSession++);
        await _recoverCameraAfterResume();
        if (mounted) {
          setState(() {
            _cameraLoading = !ref.read(streamServiceProvider).isInitialized;
            _cameraError = ref.read(streamServiceProvider).lastError;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    if (!_isLive) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(matchProvider(widget.matchId), (prev, next) {
      final match = next.valueOrNull;
      if (match == null) return;
      if (match.stream.status == StreamStatus.live && !_isLive) {
        setState(() => _isLive = true);
        _startHeartbeat();
        unawaited(ActiveStreamSession.setActive(widget.matchId));
      } else if (match.stream.status != StreamStatus.live &&
          _isLive &&
          !ref.read(streamServiceProvider).isStreaming) {
        setState(() => _isLive = false);
        _stopHeartbeat();
        unawaited(ActiveStreamSession.clear());
      }
    });

    ref.listen(ballEventsProvider(widget.matchId), (prev, next) {
      final events = next.valueOrNull;
      if (events != null) _processBallEvents(events);
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

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            fit: StackFit.expand,
            children: [
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
                  key: ValueKey('studio_$_previewSession'),
                  matchId: widget.matchId,
                  overlay: overlayAsync.valueOrNull,
                  cameraPreview: StreamCameraPreview(
                    key: ValueKey('cam_$_previewSession'),
                    matchId: widget.matchId,
                    loading: _isLive ? false : _cameraLoading,
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
                isObsMode: isObs,
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
