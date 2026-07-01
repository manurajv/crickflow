import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/overlay_state_model.dart';
import '../../../../data/models/tournament/tournament_sponsor_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../data/models/stream_overlay_theme.dart';
import '../../data/services/stream_overlay_burn_in_service.dart';
import '../../domain/stream_sponsor_rotation.dart';
import '../../domain/streaming_enums.dart';
import '../providers/streaming_studio_providers.dart';
import 'overlay/broadcast_scoreboard_overlay.dart';
import 'overlay/stream_event_overlay_widget.dart';
import 'overlay/stream_score_ticker.dart';

/// Composites camera preview + broadcast overlays for the outgoing preview.
///
/// Parent must provide bounded constraints (e.g. [AspectRatio] or full-screen).
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

  @override
  void dispose() {
    _sponsorRotation?.dispose();
    super.dispose();
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
    if (!ref.read(streamServiceProvider).isStreaming) return;
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
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: BroadcastScoreboardOverlay(
            overlay: _overlayWithSponsor(overlay, sponsorLine),
            theme: overlayTheme,
            sponsorLogoUrl: _rotatingSponsorLogo,
          ),
        ),
      if (eventOverlay != null)
        StreamEventOverlayWidget(
          overlay: eventOverlay,
          forBurnInCapture: forBurnInCapture,
          onFinished: forBurnInCapture
              ? null
              : () {
                  ref
                      .read(activeEventOverlayProvider(widget.matchId).notifier)
                      .state = null;
                  _scheduleBurnIn();
                },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeEventOverlayProvider(widget.matchId), (prev, next) {
      _scheduleBurnIn();
    });

    final eventOverlay = ref.watch(activeEventOverlayProvider(widget.matchId));
    final config = ref.watch(streamStudioConfigProvider(widget.matchId));
    final overlayTheme = ref
        .watch(streamStudioConfigProvider(widget.matchId).notifier)
        .overlayTheme;
    final match = ref.watch(matchProvider(widget.matchId)).valueOrNull;
    final tournamentId = match?.tournamentId;
    final burnIn = ref.watch(streamOverlayBurnInServiceProvider);
    final encoderSize = encoderFrameSizeFor(config);

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
    final layers = _overlayLayers(
      overlay: overlay,
      overlayTheme: overlayTheme,
      sponsorLine: sponsorLine,
      eventOverlay: eventOverlay,
    );
    final burnInLayers = _overlayLayers(
      overlay: overlay,
      overlayTheme: overlayTheme,
      sponsorLine: sponsorLine,
      eventOverlay: eventOverlay,
      forBurnInCapture: true,
    );

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(child: widget.cameraPreview),
        ...layers,
        Offstage(
          offstage: true,
          child: SizedBox(
            width: encoderSize.width,
            height: encoderSize.height,
            child: RepaintBoundary(
              key: burnIn.repaintKey,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: burnInLayers,
              ),
            ),
          ),
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
