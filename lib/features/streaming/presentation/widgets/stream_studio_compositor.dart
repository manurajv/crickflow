import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/overlay_state_model.dart';
import '../../../../data/models/tournament/tournament_sponsor_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../data/models/stream_studio_config.dart';
import '../../data/models/stream_overlay_theme.dart';
import '../../data/services/stream_overlay_burn_in_service.dart';
import '../../domain/stream_sponsor_rotation.dart';
import '../../domain/streaming_enums.dart';
import '../providers/streaming_studio_providers.dart';
import 'overlay/broadcast_overlay_host.dart';
import 'overlay/stream_score_ticker.dart';
import 'studio/studio_landscape_rotation.dart';

/// Composites camera preview + broadcast overlays for Stream Studio.
///
/// Pre-live: Flutter overlays on the preview for setup.
/// Live: native [SafeOpenGlView] burns PNG overlays into preview + RTMP — visible
/// Flutter layers are hidden to avoid duplication. An off-screen painted capture
/// tree keeps pushing overlay PNGs to the native compositor.
class StreamStudioCompositor extends ConsumerStatefulWidget {
  const StreamStudioCompositor({
    super.key,
    required this.matchId,
    required this.cameraPreview,
    required this.overlay,
    this.theme = const StreamOverlayTheme(),
  });

  final String matchId;
  final Widget cameraPreview;
  final OverlayStateModel? overlay;
  final StreamOverlayTheme theme;

  @override
  ConsumerState<StreamStudioCompositor> createState() =>
      _StreamStudioCompositorState();
}

class _StreamStudioCompositorState extends ConsumerState<StreamStudioCompositor> {
  StreamSponsorRotation? _sponsorRotation;
  String? _rotatingSponsorName;
  String? _rotatingSponsorLogo;
  int? _lastOverlayVersion;
  Size _encoderSize = const Size(1280, 720);
  bool _captureSizeLocked = false;
  StreamOrientationMode? _lockedLiveOrientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stream = ref.read(streamServiceProvider);
      if (stream.isStreaming || stream.liveSessionActive) {
        _lockCaptureSizeForLive();
        return;
      }
      if (_captureSizeLocked) return;
      final config = ref.read(streamStudioConfigProvider(widget.matchId));
      setState(() => _encoderSize = encoderFrameSizeFor(config));
    });
  }

  @override
  void dispose() {
    _sponsorRotation?.dispose();
    super.dispose();
  }

  StreamOrientationMode _broadcastOrientation(StreamStudioConfig config) {
    if (_lockedLiveOrientation != null) return _lockedLiveOrientation!;
    final stream = ref.read(streamServiceProvider);
    if (stream.liveSessionActive || stream.isStreaming) {
      return stream.orientation;
    }
    return config.orientation;
  }

  bool _landscapeUiForSession(StreamStudioConfig config) {
    return _broadcastOrientation(config) == StreamOrientationMode.landscape;
  }

  Size _encoderSizeForSession(StreamStudioConfig config) {
    return encoderFrameSizeFor(
      config.copyWith(orientation: _broadcastOrientation(config)),
    );
  }

  void _lockCaptureSizeForLive() {
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    _lockedLiveOrientation ??= _broadcastOrientation(config);
    final size = _encoderSizeForSession(config);
    _captureSizeLocked = true;
    if (size != _encoderSize && mounted) {
      setState(() => _encoderSize = size);
    }
  }

  void _unlockCaptureSize() {
    final stream = ref.read(streamServiceProvider);
    if (stream.liveSessionActive || stream.isStreaming) return;
    _captureSizeLocked = false;
    _lockedLiveOrientation = null;
  }

  @override
  void didUpdateWidget(covariant StreamStudioCompositor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final version = widget.overlay?.version;
    if (version != null && version != _lastOverlayVersion) {
      _lastOverlayVersion = version;
      _scheduleBurnIn();
    }
  }

  void _scheduleBurnIn() {
    final stream = ref.read(streamServiceProvider);
    if (!stream.isStreaming && !stream.liveSessionActive) return;
    ref.read(streamOverlayBurnInServiceProvider).schedulePush();
  }

  void _bindSponsors(List<TournamentSponsorModel> sponsors) {
    _sponsorRotation?.dispose();
    _sponsorRotation = null;
    if (sponsors.isEmpty) {
      setState(() {
        _rotatingSponsorName = null;
        _rotatingSponsorLogo = null;
      });
      _scheduleBurnIn();
      return;
    }
    _sponsorRotation = StreamSponsorRotation(
      sponsors: sponsors,
      onChanged: (name, logo) {
        if (!mounted) return;
        setState(() {
          _rotatingSponsorName = name;
          _rotatingSponsorLogo = logo;
        });
        _scheduleBurnIn();
      },
    );
  }

  List<Widget> _overlayLayers({
    required OverlayStateModel? overlay,
    required StreamOverlayTheme overlayTheme,
    required String? sponsorLine,
    required StreamEventOverlay? eventOverlay,
    required bool landscapeUi,
    bool forBurnInCapture = false,
  }) {
    return [
      if (overlay != null && overlayTheme.showTicker)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: StreamScoreTicker(
            overlay: overlay,
            sponsorLine: sponsorLine,
          ),
        ),
      if (overlay != null)
        Positioned.fill(
          child: BroadcastOverlayHost(
            landscape: landscapeUi,
            overlay: _overlayWithSponsor(overlay, sponsorLine),
            theme: overlayTheme,
            sponsorLogoUrl: _rotatingSponsorLogo,
            eventOverlay: eventOverlay,
            forBurnInCapture: forBurnInCapture,
            onEventFinished: forBurnInCapture
                ? null
                : () {
                    ref
                        .read(activeEventOverlayProvider(widget.matchId).notifier)
                        .state = null;
                    _scheduleBurnIn();
                  },
          ),
        ),
    ];
  }

  Widget _buildCaptureTree({
    required List<Widget> burnInLayers,
    required GlobalKey repaintKey,
  }) {
    return Positioned(
      left: -_encoderSize.width - 32,
      top: 0,
      child: IgnorePointer(
        child: SizedBox(
          width: _encoderSize.width,
          height: _encoderSize.height,
          child: RepaintBoundary(
            key: repaintKey,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              fit: StackFit.expand,
              children: burnInLayers,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeEventOverlayProvider(widget.matchId), (prev, next) {
      _scheduleBurnIn();
    });
    ref.listen(overlayProvider(widget.matchId), (prev, next) {
      if (next.valueOrNull != null) {
        _scheduleBurnIn();
      }
    });
    ref.listen(
      streamServiceProvider.select((s) => (s.isStreaming, s.liveSessionActive)),
      (prev, next) {
        if (next.$1 || next.$2) {
          _lockCaptureSizeForLive();
          _scheduleBurnIn();
        } else if (prev != null && (prev.$1 || prev.$2)) {
          _unlockCaptureSize();
        }
      },
    );
    ref.listen(
      streamStudioConfigProvider(widget.matchId).select((c) => c.orientation),
      (prev, next) {
        if (prev != next && !_captureSizeLocked && mounted) {
          setState(
            () => _encoderSize = encoderFrameSizeFor(
              ref.read(streamStudioConfigProvider(widget.matchId)),
            ),
          );
        }
      },
    );
    ref.listen(
      streamStudioConfigProvider(widget.matchId).select(
        (c) => (
          c.overlayLayout,
          c.overlayPrimaryColor,
          c.overlaySecondaryColor,
          c.overlayOpacity,
          c.overlayRoundedCorners,
          c.overlayCompactMode,
          c.showSponsorBanner,
          c.showTicker,
          c.orientation,
        ),
      ),
      (prev, next) {
        if (prev != next) _scheduleBurnIn();
      },
    );

    final eventOverlay = ref.watch(activeEventOverlayProvider(widget.matchId));
    final overlayTheme = ref
        .watch(streamStudioConfigProvider(widget.matchId).notifier)
        .overlayTheme;
    // studioConfig read above for locked orientation during live.
    final match = ref.watch(matchProvider(widget.matchId)).valueOrNull;
    final tournamentId = match?.tournamentId;
    final burnIn = ref.watch(streamOverlayBurnInServiceProvider);
    final burnInActive = ref.watch(streamOverlayBurnInActiveProvider);
    final stream = ref.watch(streamServiceProvider);
    final isStreaming = stream.isStreaming;
    final hideFlutterOverlays = isStreaming && burnInActive;
    final studioConfig = ref.watch(streamStudioConfigProvider(widget.matchId));
    final landscapeUi = _landscapeUiForSession(studioConfig);

    if (tournamentId != null &&
        tournamentId.isNotEmpty &&
        overlayTheme.showSponsorBanner) {
      ref.listen(tournamentSponsorsProvider(tournamentId), (prev, next) {
        _bindSponsors(next.valueOrNull ?? const []);
      });
      final sponsors =
          ref.watch(tournamentSponsorsProvider(tournamentId)).valueOrNull;
      if (sponsors != null &&
          sponsors.isNotEmpty &&
          _sponsorRotation == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _bindSponsors(sponsors);
        });
      }
    }

    final overlay = widget.overlay;
    final sponsorLine = _resolveSponsorText(overlay);
    final burnInLayers = _overlayLayers(
      overlay: overlay,
      overlayTheme: overlayTheme,
      sponsorLine: sponsorLine,
      eventOverlay: eventOverlay,
      landscapeUi: landscapeUi,
      forBurnInCapture: true,
    );
    final Widget previewLayers = hideFlutterOverlays
        ? const SizedBox.shrink()
        : Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: _overlayLayers(
              overlay: overlay,
              overlayTheme: overlayTheme,
              sponsorLine: sponsorLine,
              eventOverlay: eventOverlay,
              landscapeUi: landscapeUi,
            ),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: widget.cameraPreview),
        Positioned.fill(
          child: StudioLandscapeRotation(
            landscape: landscapeUi,
            child: previewLayers,
          ),
        ),
        if ((isStreaming || stream.liveSessionActive) &&
            _encoderSize.width > 0 &&
            _encoderSize.height > 0)
          _buildCaptureTree(
            burnInLayers: burnInLayers,
            repaintKey: burnIn.repaintKey,
          ),
      ],
    );
  }

  String? _resolveSponsorText(OverlayStateModel? overlay) {
    if (_rotatingSponsorName != null && _rotatingSponsorName!.isNotEmpty) {
      return _rotatingSponsorName;
    }
    if (overlay != null && overlay.sponsorText.isNotEmpty) {
      return overlay.sponsorText;
    }
    return null;
  }

  OverlayStateModel _overlayWithSponsor(
    OverlayStateModel overlay,
    String? sponsorLine,
  ) {
    if (sponsorLine == null || sponsorLine.isEmpty) return overlay;
    return OverlayStateModel(
      matchId: overlay.matchId,
      teamAName: overlay.teamAName,
      teamBName: overlay.teamBName,
      battingTeamName: overlay.battingTeamName,
      totalRuns: overlay.totalRuns,
      totalWickets: overlay.totalWickets,
      legalBalls: overlay.legalBalls,
      ballsPerOver: overlay.ballsPerOver,
      runRate: overlay.runRate,
      requiredRunRate: overlay.requiredRunRate,
      target: overlay.target,
      strikerName: overlay.strikerName,
      strikerRuns: overlay.strikerRuns,
      strikerBalls: overlay.strikerBalls,
      nonStrikerName: overlay.nonStrikerName,
      nonStrikerRuns: overlay.nonStrikerRuns,
      nonStrikerBalls: overlay.nonStrikerBalls,
      bowlerName: overlay.bowlerName,
      bowlerWickets: overlay.bowlerWickets,
      bowlerRuns: overlay.bowlerRuns,
      bowlerBalls: overlay.bowlerBalls,
      matchStatus: overlay.matchStatus,
      sponsorText: sponsorLine,
      locationLabel: overlay.locationLabel,
      version: overlay.version,
    );
  }
}
