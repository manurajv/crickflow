import 'package:flutter/material.dart';

import '../../../../../../data/models/overlay_state_model.dart';
import '../../../../data/models/opening_bowler_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../../../../domain/streaming_enums.dart';
import '../broadcast_overlay_host.dart';
import '../scorebug/landscape/landscape_scorebug_context.dart';

/// Five-second opening bowler intro with the live scorebug visible underneath.
class OpeningBowlerOverlay extends StatelessWidget {
  const OpeningBowlerOverlay({
    super.key,
    required this.matchId,
    required this.snapshot,
    required this.overlay,
    required this.theme,
    required this.landscape,
    required this.landscapeContext,
    this.forBurnInCapture = false,
    this.onFinished,
  });

  final String matchId;
  final OpeningBowlerSnapshot snapshot;
  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final bool landscape;
  final LandscapeScorebugContext landscapeContext;
  final bool forBurnInCapture;
  final VoidCallback? onFinished;

  static const holdDuration = Duration(seconds: 5);

  @override
  Widget build(BuildContext context) {
    final bowlerEvent = StreamEventOverlay(
      type: StreamEventOverlayType.newBowler,
      title: StreamEventOverlayType.newBowler.title,
      subtitle: snapshot.fallbackName,
      playerName: snapshot.fallbackName,
      playerId: snapshot.playerId,
      duration: holdDuration,
    );

    return BroadcastOverlayHost(
      matchId: matchId,
      landscape: landscape,
      overlay: overlay,
      theme: theme,
      landscapeContext: landscapeContext,
      eventOverlay: bowlerEvent,
      forBurnInCapture: forBurnInCapture,
      onEventFinished: onFinished,
    );
  }
}
