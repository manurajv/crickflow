import 'package:flutter/material.dart';

import '../../../../../../../data/models/overlay_state_model.dart';
import '../../../../data/models/innings_break_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../../../../domain/streaming_enums.dart';
import '../broadcast_overlay_host.dart';
import '../scorebug/landscape/landscape_scorebug_context.dart';

/// Chase opening bowler intro with scorebug visible.
class ChaseOpeningBowlerIntro extends StatelessWidget {
  const ChaseOpeningBowlerIntro({
    super.key,
    required this.matchId,
    required this.snapshot,
    required this.overlay,
    required this.theme,
    required this.landscape,
    required this.landscapeContext,
    this.onFinished,
  });

  final String matchId;
  final ChaseOpeningBowlerSnapshot snapshot;
  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final bool landscape;
  final LandscapeScorebugContext landscapeContext;
  final VoidCallback? onFinished;

  static const holdDuration = Duration(seconds: 7);

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
      onEventFinished: onFinished,
    );
  }
}
