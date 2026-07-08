import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/ball_event_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/overlay_state_model.dart';
import '../../../../data/services/stream_service.dart';
import '../../../../domain/services/scoring_engine.dart';
import '../../../../data/models/tournament/tournament_sponsor_model.dart';
import '../../../../shared/providers/match_squads_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../data/models/stream_studio_config.dart';
import '../../data/models/stream_overlay_theme.dart';
import '../../data/models/opening_batsmen_snapshot.dart';
import '../../data/models/opening_bowler_snapshot.dart';
import '../../data/models/innings_break_snapshot.dart';
import '../../data/models/post_match_snapshot.dart';
import '../../data/models/match_introduction_snapshot.dart';
import '../../data/services/stream_overlay_burn_in_service.dart';
import '../../domain/stream_sponsor_rotation.dart';
import '../../domain/streaming_enums.dart';
import '../providers/innings_break_controller.dart';
import '../providers/match_introduction_controller.dart';
import '../providers/post_match_controller.dart';
import 'overlay/post_match/post_match_overlay_host.dart';
import '../providers/streaming_studio_providers.dart';
import 'overlay/broadcast_overlay_host.dart';
import 'overlay/innings_break/innings_break_overlay_host.dart';
import 'overlay/match_introduction/match_introduction_overlay.dart';
import 'overlay/opening_batsmen/opening_batsmen_overlay.dart';
import 'overlay/opening_bowler/opening_bowler_overlay.dart';
import 'overlay/events/broadcast_event_anim.dart';
import 'overlay/scorebug/landscape/landscape_scorebug_context_builder.dart';
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
    this.onPostMatchAutoEnd,
  });

  final String matchId;
  final Widget cameraPreview;
  final OverlayStateModel? overlay;
  final StreamOverlayTheme theme;
  final VoidCallback? onPostMatchAutoEnd;

  @override
  ConsumerState<StreamStudioCompositor> createState() =>
      _StreamStudioCompositorState();
}

class _StreamStudioCompositorState extends ConsumerState<StreamStudioCompositor> {
  StreamSponsorRotation? _sponsorRotation;
  String? _rotatingSponsorName;
  String? _rotatingSponsorLogo;
  Size _encoderSize = const Size(1280, 720);
  bool _captureSizeLocked = false;
  StreamOrientationMode? _lockedLiveOrientation;
  Timer? _eventDismissTimer;

  @override
  void initState() {
    super.initState();
    final stream = ref.read(streamServiceProvider);
    if (stream.isStreaming || stream.liveSessionActive || stream.isRtmpLive) {
      _lockCaptureSizeForLive();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final liveStream = ref.read(streamServiceProvider);
      if (_isLiveSession(liveStream)) {
        _lockCaptureSizeForLive();
        if (liveStream.isRtmpLive) {
          ref
              .read(matchIntroductionControllerProvider(widget.matchId).notifier)
              .onRtmpConnected();
        }
        return;
      }
      if (_captureSizeLocked) return;
      final config = ref.read(streamStudioConfigProvider(widget.matchId));
      setState(() => _encoderSize = overlayCaptureSizeFor(config));
    });
  }

  @override
  void dispose() {
    _eventDismissTimer?.cancel();
    _sponsorRotation?.dispose();
    super.dispose();
  }

  static final _scoringEngine = ScoringEngine();

  bool _isLiveSession(StreamService stream) =>
      stream.liveSessionActive ||
      stream.isStreaming ||
      stream.isRtmpLive ||
      (stream.isReconnecting && !stream.reconnectExhausted);

  /// While live, match state is authoritative — overlay Firestore stream can lag.
  OverlayStateModel? _effectiveOverlay({
    required MatchModel? match,
    required OverlayStateModel? streamOverlay,
    required StreamService stream,
  }) {
    if (!_isLiveSession(stream) || match == null) return streamOverlay;
    final built = _scoringEngine.buildOverlayForMatch(match);
    if (streamOverlay == null || built.version >= streamOverlay.version) {
      return built;
    }
    return streamOverlay;
  }

  StreamOrientationMode _broadcastOrientation(StreamStudioConfig config) {
    if (_lockedLiveOrientation != null) return _lockedLiveOrientation!;
    if (config.orientationLocked) return config.orientation;
    final stream = ref.read(streamServiceProvider);
    if (_isLiveSession(stream)) {
      return stream.orientation;
    }
    return config.orientation;
  }

  bool _landscapeUiForSession(StreamStudioConfig config) {
    return _broadcastOrientation(config) == StreamOrientationMode.landscape;
  }

  Size _encoderSizeForSession(StreamStudioConfig config) {
    return overlayCaptureSizeFor(
      config.copyWith(orientation: _broadcastOrientation(config)),
    );
  }

  void _lockCaptureSizeForLive() {
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    final stream = ref.read(streamServiceProvider);
    _lockedLiveOrientation ??= config.orientationLocked
        ? config.orientation
        : (_isLiveSession(stream) ? stream.orientation : config.orientation);
    final size = _encoderSizeForSession(config);
    _captureSizeLocked = true;
    if (size != _encoderSize && mounted) {
      setState(() => _encoderSize = size);
    }
  }

  void _unlockCaptureSize() {
    final stream = ref.read(streamServiceProvider);
    if (_isLiveSession(stream)) return;
    _captureSizeLocked = false;
    _lockedLiveOrientation = null;
    if (mounted) {
      final config = ref.read(streamStudioConfigProvider(widget.matchId));
      setState(() => _encoderSize = overlayCaptureSizeFor(config));
    }
  }

  @override
  void didUpdateWidget(covariant StreamStudioCompositor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prev = oldWidget.overlay;
    final next = widget.overlay;
    final overlayChanged = next != null &&
        (prev?.version != next.version ||
            prev?.totalRuns != next.totalRuns ||
            prev?.totalWickets != next.totalWickets ||
            prev?.legalBalls != next.legalBalls ||
            prev?.strikerRuns != next.strikerRuns ||
            prev?.strikerName != next.strikerName ||
            prev?.nonStrikerRuns != next.nonStrikerRuns ||
            prev?.bowlerRuns != next.bowlerRuns ||
            prev?.bowlerWickets != next.bowlerWickets);
    if (overlayChanged) {
      final stream = ref.read(streamServiceProvider);
      if (_isLiveSession(stream)) {
        _lockCaptureSizeForLive();
      }
      _scheduleBurnIn();
    }
  }

  void _scheduleBurnIn() {
    final stream = ref.read(streamServiceProvider);
    if (!_isLiveSession(stream)) return;
    ref.read(streamOverlayBurnInServiceProvider).schedulePush();
  }

  void _clearActiveEventOverlay() {
    ref.read(activeEventOverlayProvider(widget.matchId).notifier).state = null;
    _eventDismissTimer?.cancel();
    _eventDismissTimer = null;
    _scheduleBurnIn();
  }

  void _flushPendingSidePanelOverlay() {
    final pending =
        ref.read(pendingSidePanelOverlayProvider(widget.matchId));
    if (pending == null) return;
    ref.read(pendingSidePanelOverlayProvider(widget.matchId).notifier).state =
        null;
    ref.read(activeEventOverlayProvider(widget.matchId).notifier).state =
        pending;
    _scheduleEventDismissSafety(pending);
    _scheduleBurnIn();
  }

  void _onEventOverlayFinished() {
    if (!mounted) return;
    final active = ref.read(activeEventOverlayProvider(widget.matchId));
    if (active == null) return;
    _clearActiveEventOverlay();
    _flushPendingSidePanelOverlay();
  }

  void _scheduleEventDismissSafety(StreamEventOverlay event) {
    _eventDismissTimer?.cancel();
    _eventDismissTimer = Timer(
      BroadcastEventAnim.totalSequenceDuration(event.duration),
      () {
        if (!mounted) return;
        final active = ref.read(activeEventOverlayProvider(widget.matchId));
        if (active == event) {
          _clearActiveEventOverlay();
          _flushPendingSidePanelOverlay();
        }
      },
    );
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
    MatchModel? match,
    List<BallEventModel> ballEvents = const [],
    String? tournamentTitle,
    String? battingTeamLogoUrl,
    String? bowlingTeamLogoUrl,
    bool forBurnInCapture = false,
    bool showMatchIntroduction = false,
    MatchIntroductionSnapshot? matchIntroSnapshot,
    VoidCallback? onMatchIntroFinished,
    VoidCallback? onMatchIntroVisualChange,
    bool showOpeningBatsmen = false,
    OpeningBatsmenSnapshot? openingBatsmenSnapshot,
    VoidCallback? onOpeningBatsmenFinished,
    VoidCallback? onOpeningBatsmenVisualChange,
    bool showOpeningBowler = false,
    OpeningBowlerSnapshot? openingBowlerSnapshot,
    VoidCallback? onOpeningBowlerFinished,
    VoidCallback? onOpeningBowlerVisualChange,
    bool showInningsBreakSlideshow = false,
    InningsBreakSnapshot? inningsBreakSnapshot,
    VoidCallback? onInningsBreakVisualChange,
    bool showChaseOpeningBatsmen = false,
    OpeningBatsmenSnapshot? chaseOpeningBatsmenSnapshot,
    VoidCallback? onChaseOpeningBatsmenFinished,
    VoidCallback? onChaseOpeningBatsmenVisualChange,
    bool showChaseOpeningBowler = false,
    OpeningBowlerSnapshot? chaseOpeningBowlerSnapshot,
    VoidCallback? onChaseOpeningBowlerFinished,
    bool showPostMatch = false,
    PostMatchPhase postMatchPhase = PostMatchPhase.idle,
    PostMatchSnapshot? postMatchSnapshot,
    VoidCallback? onPostMatchVisualChange,
  }) {
    if (showMatchIntroduction && matchIntroSnapshot != null) {
      return [
        Positioned.fill(
          child: MatchIntroductionOverlay(
            snapshot: matchIntroSnapshot,
            theme: overlayTheme,
            landscape: landscapeUi,
            onFinished: onMatchIntroFinished,
            onVisualChange: onMatchIntroVisualChange,
          ),
        ),
      ];
    }

    if (showOpeningBatsmen && openingBatsmenSnapshot != null) {
      return [
        Positioned.fill(
          child: OpeningBatsmenOverlay(
            matchId: widget.matchId,
            snapshot: openingBatsmenSnapshot,
            theme: overlayTheme,
            landscape: landscapeUi,
            onFinished: onOpeningBatsmenFinished,
            onVisualChange: onOpeningBatsmenVisualChange,
          ),
        ),
      ];
    }

    final scorebugContext = overlay != null
        ? LandscapeScorebugContextBuilder.build(
            overlay: overlay,
            match: match,
            tournamentTitle: tournamentTitle,
            battingTeamLogoUrl: battingTeamLogoUrl,
            bowlingTeamLogoUrl: bowlingTeamLogoUrl,
            events: ballEvents,
          )
        : null;

    if (showOpeningBowler &&
        openingBowlerSnapshot != null &&
        overlay != null &&
        scorebugContext != null) {
      return [
        if (overlayTheme.showTicker)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: StreamScoreTicker(
              overlay: overlay,
              sponsorLine: sponsorLine,
            ),
          ),
        Positioned.fill(
          child: OpeningBowlerOverlay(
            matchId: widget.matchId,
            snapshot: openingBowlerSnapshot,
            overlay: _overlayWithSponsor(overlay, sponsorLine),
            theme: overlayTheme,
            landscape: landscapeUi,
            landscapeContext: scorebugContext,
            forBurnInCapture: forBurnInCapture,
            onFinished: onOpeningBowlerFinished,
          ),
        ),
      ];
    }

    if (showPostMatch &&
        postMatchSnapshot != null &&
        postMatchSnapshot.isValid &&
        (postMatchPhase == PostMatchPhase.matchSummary ||
            postMatchPhase == PostMatchPhase.thankYou)) {
      final matchTitle = scorebugContext?.matchTitle.isNotEmpty == true
          ? scorebugContext!.matchTitle
          : (overlay != null &&
                  overlay.teamAName.isNotEmpty &&
                  overlay.teamBName.isNotEmpty
              ? '${overlay.teamAName} vs ${overlay.teamBName}'
              : postMatchSnapshot.matchTitle);
      return [
        if (overlayTheme.showTicker && overlay != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: StreamScoreTicker(
              overlay: overlay,
              sponsorLine: sponsorLine,
            ),
          ),
        Positioned.fill(
          child: PostMatchOverlayHost(
            snapshot: postMatchSnapshot,
            phase: postMatchPhase,
            theme: overlayTheme,
            landscape: landscapeUi,
            matchTitle: matchTitle,
            onVisualChange: onPostMatchVisualChange,
          ),
        ),
      ];
    }

    if (showInningsBreakSlideshow &&
        inningsBreakSnapshot != null &&
        inningsBreakSnapshot.isValid) {
      final matchTitle = scorebugContext?.matchTitle.isNotEmpty == true
          ? scorebugContext!.matchTitle
          : (overlay != null &&
                  overlay.teamAName.isNotEmpty &&
                  overlay.teamBName.isNotEmpty
              ? '${overlay.teamAName} vs ${overlay.teamBName}'
              : inningsBreakSnapshot.matchTitle);
      return [
        if (overlayTheme.showTicker && overlay != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: StreamScoreTicker(
              overlay: overlay,
              sponsorLine: sponsorLine,
            ),
          ),
        Positioned.fill(
          child: InningsBreakOverlayHost(
            snapshot: inningsBreakSnapshot,
            theme: overlayTheme,
            landscape: landscapeUi,
            matchTitle: matchTitle,
            onVisualChange: onInningsBreakVisualChange,
          ),
        ),
      ];
    }

    if (showChaseOpeningBatsmen && chaseOpeningBatsmenSnapshot != null) {
      return [
        Positioned.fill(
          child: OpeningBatsmenOverlay(
            matchId: widget.matchId,
            snapshot: chaseOpeningBatsmenSnapshot,
            theme: overlayTheme,
            landscape: landscapeUi,
            onFinished: onChaseOpeningBatsmenFinished,
            onVisualChange: onChaseOpeningBatsmenVisualChange,
          ),
        ),
      ];
    }

    if (showChaseOpeningBowler &&
        chaseOpeningBowlerSnapshot != null &&
        overlay != null &&
        scorebugContext != null) {
      return [
        if (overlayTheme.showTicker)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: StreamScoreTicker(
              overlay: overlay,
              sponsorLine: sponsorLine,
            ),
          ),
        Positioned.fill(
          child: OpeningBowlerOverlay(
            matchId: widget.matchId,
            snapshot: chaseOpeningBowlerSnapshot,
            overlay: _overlayWithSponsor(overlay, sponsorLine),
            theme: overlayTheme,
            landscape: landscapeUi,
            landscapeContext: scorebugContext,
            forBurnInCapture: forBurnInCapture,
            onFinished: onChaseOpeningBowlerFinished,
          ),
        ),
      ];
    }

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
            matchId: widget.matchId,
            landscape: landscapeUi,
            overlay: _overlayWithSponsor(overlay, sponsorLine),
            theme: overlayTheme,
            sponsorLogoUrl: _rotatingSponsorLogo,
            landscapeContext: scorebugContext,
            eventOverlay: eventOverlay,
            forBurnInCapture: forBurnInCapture,
            onEventFinished: _onEventOverlayFinished,
          ),
        ),
    ];
  }

  Widget _buildCaptureTree({
    required List<Widget> burnInLayers,
    required GlobalKey repaintKey,
    required int recoveryGeneration,
  }) {
    return Positioned(
      key: ValueKey<int>(recoveryGeneration),
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
    ref.listen(overlayLifecycleRecoveryProvider, (prev, next) {
      if (prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scheduleBurnIn();
        });
      }
    });
    ref.listen(activeEventOverlayProvider(widget.matchId), (prev, next) {
      _scheduleBurnIn();
      if (next != null) {
        _scheduleEventDismissSafety(next);
      } else {
        _eventDismissTimer?.cancel();
        _eventDismissTimer = null;
      }
    });
    ref.listen(overlayProvider(widget.matchId), (prev, next) {
      if (next.valueOrNull != null) {
        _scheduleBurnIn();
      }
    });
    ref.listen(matchProvider(widget.matchId), (prev, next) {
      final match = next.valueOrNull;
      if (match != null) {
        _scheduleBurnIn();
        final stream = ref.read(streamServiceProvider);
        if (stream.isRtmpLive || stream.isStreaming || stream.liveSessionActive) {
          ref
              .read(inningsBreakControllerProvider(widget.matchId).notifier)
              .onMatchUpdated(
                match,
                isStreamLive: stream.isRtmpLive ||
                    stream.isStreaming ||
                    stream.liveSessionActive,
              );
          ref
              .read(postMatchControllerProvider(widget.matchId).notifier)
              .onMatchUpdated(
                match,
                isStreamLive: stream.isRtmpLive ||
                    stream.isStreaming ||
                    stream.liveSessionActive,
              );
        }
      }
    });
    ref.listen(ballEventsProvider(widget.matchId), (prev, next) {
      if (next.valueOrNull != null) {
        _scheduleBurnIn();
      }
    });
    ref.listen(matchIntroductionControllerProvider(widget.matchId), (prev, next) {
      if (prev != next) _scheduleBurnIn();
    });
    ref.listen(inningsBreakControllerProvider(widget.matchId), (prev, next) {
      if (prev != next) _scheduleBurnIn();
    });
    ref.listen(postMatchControllerProvider(widget.matchId), (prev, next) {
      if (prev != next) _scheduleBurnIn();
      if (next == PostMatchPhase.complete && prev != PostMatchPhase.complete) {
        widget.onPostMatchAutoEnd?.call();
      }
    });
    ref.listen(
      streamServiceProvider.select(
        (s) => (s.isStreaming, s.liveSessionActive, s.isRtmpLive),
      ),
      (prev, next) {
        final live = next.$1 || next.$2 || next.$3;
        if (live) {
          _lockCaptureSizeForLive();
          _scheduleBurnIn();
        } else if (prev != null && (prev.$1 || prev.$2 || prev.$3)) {
          _unlockCaptureSize();
          ref
              .read(matchIntroductionControllerProvider(widget.matchId).notifier)
              .reset();
          ref
              .read(inningsBreakControllerProvider(widget.matchId).notifier)
              .reset();
          ref.read(postMatchControllerProvider(widget.matchId).notifier).reset();
        }
        if (next.$3 && prev?.$3 != true) {
          ref
              .read(matchIntroductionControllerProvider(widget.matchId).notifier)
              .onRtmpConnected();
        }
      },
    );
    ref.listen(
      streamStudioConfigProvider(widget.matchId).select((c) => c.orientation),
      (prev, next) {
        if (prev != next && !_captureSizeLocked && mounted) {
          setState(
            () => _encoderSize = overlayCaptureSizeFor(
              ref.read(streamStudioConfigProvider(widget.matchId)),
            ),
          );
        }
      },
    );
    ref.listen(
      streamStudioConfigProvider(widget.matchId).select((c) => c.resolution),
      (prev, next) {
        if (prev != next && !_captureSizeLocked && mounted) {
          setState(
            () => _encoderSize = overlayCaptureSizeFor(
              ref.read(streamStudioConfigProvider(widget.matchId)),
            ),
          );
          _scheduleBurnIn();
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
    final ballEvents =
        ref.watch(ballEventsProvider(widget.matchId)).valueOrNull ?? const [];
    final squads =
        ref.watch(matchDualSquadsProvider(widget.matchId)).valueOrNull;
    final tournamentId = match?.tournamentId;
    final tournament = tournamentId != null && tournamentId.isNotEmpty
        ? ref.watch(tournamentProvider(tournamentId)).valueOrNull
        : null;
    final burnIn = ref.watch(streamOverlayBurnInServiceProvider);
    final overlayRecoveryGen = ref.watch(overlayLifecycleRecoveryProvider);
    final stream = ref.watch(streamServiceProvider);
    // While live or publishing, preview overlays are native burn-in only.
    final hideFlutterOverlays = _isLiveSession(stream);
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

    final introPhase =
        ref.watch(matchIntroductionControllerProvider(widget.matchId));
    final showMatchIntroduction =
        introPhase == MatchIntroductionPhase.showing;
    final showOpeningBatsmen =
        introPhase == MatchIntroductionPhase.openingBatsmen;
    final showOpeningBowler =
        introPhase == MatchIntroductionPhase.openingBowler;
    final matchIntroSnapshot = showMatchIntroduction
        ? ref.watch(matchIntroductionSnapshotProvider(widget.matchId)).valueOrNull
        : null;
    final openingBatsmenSnapshot = showOpeningBatsmen
        ? ref.watch(openingBatsmenSnapshotProvider(widget.matchId))
        : null;
    final openingBowlerSnapshot = showOpeningBowler
        ? ref.watch(openingBowlerSnapshotProvider(widget.matchId))
        : null;

    void onMatchIntroFinished() {
      final hasOpeningBatsmen =
          ref.read(openingBatsmenSnapshotProvider(widget.matchId)) != null;
      final hasOpeningBowler =
          ref.read(openingBowlerSnapshotProvider(widget.matchId)) != null;
      ref
          .read(matchIntroductionControllerProvider(widget.matchId).notifier)
          .onMatchIntroductionFinished(
            hasOpeningBatsmen: hasOpeningBatsmen,
            hasOpeningBowler: hasOpeningBowler,
          );
      _scheduleBurnIn();
    }

    void onOpeningBatsmenFinished() {
      final hasOpeningBowler =
          ref.read(openingBowlerSnapshotProvider(widget.matchId)) != null;
      ref
          .read(matchIntroductionControllerProvider(widget.matchId).notifier)
          .onOpeningBatsmenFinished(hasOpeningBowler: hasOpeningBowler);
      _scheduleBurnIn();
    }

    void onOpeningBowlerFinished() {
      ref
          .read(matchIntroductionControllerProvider(widget.matchId).notifier)
          .onOpeningBowlerFinished();
      _scheduleBurnIn();
    }

    final inningsBreakPhase =
        ref.watch(inningsBreakControllerProvider(widget.matchId));
    final showInningsBreakSlideshow =
        inningsBreakPhase == InningsBreakPhase.slideshow;
    final showChaseOpeningBatsmen =
        inningsBreakPhase == InningsBreakPhase.chaseOpeningBatsmen;
    final showChaseOpeningBowler =
        inningsBreakPhase == InningsBreakPhase.chaseOpeningBowler;
    final inningsBreakSnapshot = showInningsBreakSlideshow
        ? ref.watch(inningsBreakSnapshotProvider(widget.matchId))
        : null;
    final chaseOpeningBatsmenSnapshot = showChaseOpeningBatsmen
        ? ref.watch(chaseAsOpeningBatsmenProvider(widget.matchId))
        : null;
    final chaseOpeningBowlerSnapshot = showChaseOpeningBowler
        ? ref.watch(chaseAsOpeningBowlerProvider(widget.matchId))
        : null;

    final postMatchPhase =
        ref.watch(postMatchControllerProvider(widget.matchId));
    final showPostMatch =
        postMatchPhase == PostMatchPhase.matchSummary ||
            postMatchPhase == PostMatchPhase.thankYou;
    final postMatchSnapshot = showPostMatch
        ? ref.watch(postMatchSnapshotProvider(widget.matchId))
        : null;

    void onChaseOpeningBatsmenFinished() {
      final hasBowler =
          ref.read(chaseOpeningBowlerSnapshotProvider(widget.matchId)) != null;
      ref
          .read(inningsBreakControllerProvider(widget.matchId).notifier)
          .onChaseOpeningBatsmenFinished(hasOpeningBowler: hasBowler);
      _scheduleBurnIn();
    }

    void onChaseOpeningBowlerFinished() {
      ref
          .read(inningsBreakControllerProvider(widget.matchId).notifier)
          .onChaseOpeningBowlerFinished();
      _scheduleBurnIn();
    }

    final overlay = _effectiveOverlay(
      match: match,
      streamOverlay: widget.overlay,
      stream: stream,
    );
    final sponsorLine = _resolveSponsorText(overlay);
    final landscapeLogos = _resolveLandscapeLogos(match, squads, overlay);
    final burnInLayers = _overlayLayers(
      overlay: overlay,
      overlayTheme: overlayTheme,
      sponsorLine: sponsorLine,
      eventOverlay: eventOverlay,
      landscapeUi: landscapeUi,
      match: match,
      ballEvents: ballEvents,
      tournamentTitle: tournament?.name,
      battingTeamLogoUrl: landscapeLogos.$1,
      bowlingTeamLogoUrl: landscapeLogos.$2,
      forBurnInCapture: true,
      showMatchIntroduction:
          showMatchIntroduction && matchIntroSnapshot != null,
      matchIntroSnapshot: matchIntroSnapshot,
      onMatchIntroFinished: onMatchIntroFinished,
      onMatchIntroVisualChange: _scheduleBurnIn,
      showOpeningBatsmen:
          showOpeningBatsmen && openingBatsmenSnapshot != null,
      openingBatsmenSnapshot: openingBatsmenSnapshot,
      onOpeningBatsmenFinished: onOpeningBatsmenFinished,
      onOpeningBatsmenVisualChange: _scheduleBurnIn,
      showOpeningBowler:
          showOpeningBowler && openingBowlerSnapshot != null,
      openingBowlerSnapshot: openingBowlerSnapshot,
      onOpeningBowlerFinished: onOpeningBowlerFinished,
      onOpeningBowlerVisualChange: _scheduleBurnIn,
      showInningsBreakSlideshow:
          showInningsBreakSlideshow && inningsBreakSnapshot != null,
      inningsBreakSnapshot: inningsBreakSnapshot,
      onInningsBreakVisualChange: _scheduleBurnIn,
      showChaseOpeningBatsmen:
          showChaseOpeningBatsmen && chaseOpeningBatsmenSnapshot != null,
      chaseOpeningBatsmenSnapshot: chaseOpeningBatsmenSnapshot,
      onChaseOpeningBatsmenFinished: onChaseOpeningBatsmenFinished,
      onChaseOpeningBatsmenVisualChange: _scheduleBurnIn,
      showChaseOpeningBowler:
          showChaseOpeningBowler && chaseOpeningBowlerSnapshot != null,
      chaseOpeningBowlerSnapshot: chaseOpeningBowlerSnapshot,
      onChaseOpeningBowlerFinished: onChaseOpeningBowlerFinished,
      showPostMatch: showPostMatch && postMatchSnapshot != null,
      postMatchPhase: postMatchPhase,
      postMatchSnapshot: postMatchSnapshot,
      onPostMatchVisualChange: _scheduleBurnIn,
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
              match: match,
              ballEvents: ballEvents,
              tournamentTitle: tournament?.name,
              battingTeamLogoUrl: landscapeLogos.$1,
              bowlingTeamLogoUrl: landscapeLogos.$2,
              showMatchIntroduction:
                  showMatchIntroduction && matchIntroSnapshot != null,
              matchIntroSnapshot: matchIntroSnapshot,
              onMatchIntroFinished: onMatchIntroFinished,
              onMatchIntroVisualChange: _scheduleBurnIn,
              showOpeningBatsmen:
                  showOpeningBatsmen && openingBatsmenSnapshot != null,
              openingBatsmenSnapshot: openingBatsmenSnapshot,
              onOpeningBatsmenFinished: onOpeningBatsmenFinished,
              onOpeningBatsmenVisualChange: _scheduleBurnIn,
              showOpeningBowler:
                  showOpeningBowler && openingBowlerSnapshot != null,
              openingBowlerSnapshot: openingBowlerSnapshot,
              onOpeningBowlerFinished: onOpeningBowlerFinished,
              onOpeningBowlerVisualChange: _scheduleBurnIn,
              showInningsBreakSlideshow:
                  showInningsBreakSlideshow && inningsBreakSnapshot != null,
              inningsBreakSnapshot: inningsBreakSnapshot,
              onInningsBreakVisualChange: _scheduleBurnIn,
              showChaseOpeningBatsmen:
                  showChaseOpeningBatsmen && chaseOpeningBatsmenSnapshot != null,
              chaseOpeningBatsmenSnapshot: chaseOpeningBatsmenSnapshot,
              onChaseOpeningBatsmenFinished: onChaseOpeningBatsmenFinished,
              onChaseOpeningBatsmenVisualChange: _scheduleBurnIn,
              showChaseOpeningBowler:
                  showChaseOpeningBowler && chaseOpeningBowlerSnapshot != null,
              chaseOpeningBowlerSnapshot: chaseOpeningBowlerSnapshot,
              onChaseOpeningBowlerFinished: onChaseOpeningBowlerFinished,
              showPostMatch: showPostMatch && postMatchSnapshot != null,
              postMatchPhase: postMatchPhase,
              postMatchSnapshot: postMatchSnapshot,
              onPostMatchVisualChange: _scheduleBurnIn,
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
        if (_isLiveSession(stream) &&
            _encoderSize.width > 0 &&
            _encoderSize.height > 0)
          _buildCaptureTree(
            burnInLayers: burnInLayers,
            repaintKey: burnIn.repaintKey,
            recoveryGeneration: overlayRecoveryGen,
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

  (String?, String?) _resolveLandscapeLogos(
    MatchModel? match,
    MatchDualSquads? squads,
    OverlayStateModel? overlay,
  ) {
    if (match == null || overlay == null || squads == null) {
      return (null, null);
    }
    final innings = match.currentInnings;
    if (innings == null) return (null, null);

    final battingIsA = innings.battingTeamId == match.teamAId;
    final battingLogo =
        battingIsA ? squads.teamA.teamLogoUrl : squads.teamB.teamLogoUrl;
    final bowlingLogo =
        battingIsA ? squads.teamB.teamLogoUrl : squads.teamA.teamLogoUrl;
    return (battingLogo, bowlingLogo);
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
