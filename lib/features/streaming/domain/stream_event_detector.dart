import '../../../core/constants/enums.dart';
import '../../../data/models/ball_event_model.dart';
import '../domain/streaming_enums.dart';
import '../data/models/stream_overlay_theme.dart';

/// Maps ball events to broadcast overlay graphics.
class StreamEventDetector {
  const StreamEventDetector();

  StreamEventOverlay? detect(BallEventModel event, {BallEventModel? previous}) {
    if (event.eventType == BallEventType.wicket || event.isWicket) {
      final name = event.dismissedPlayerName ?? 'Batter';
      return StreamEventOverlay(
        type: StreamEventOverlayType.wicket,
        title: StreamEventOverlayType.wicket.title,
        subtitle: name,
        playerName: name,
        duration: StreamEventOverlayType.wicket.defaultDuration,
        createdAt: event.timestamp,
      );
    }

    if (event.eventType == BallEventType.runs) {
      if (event.runs >= 6 || event.boundaryType == 'six') {
        return StreamEventOverlay(
          type: StreamEventOverlayType.hugeSix,
          title: StreamEventOverlayType.hugeSix.title,
          subtitle: '${event.runs} runs',
          duration: StreamEventOverlayType.hugeSix.defaultDuration,
          createdAt: event.timestamp,
        );
      }
      if (event.runs == 4 || event.boundaryType == 'four') {
        return StreamEventOverlay(
          type: StreamEventOverlayType.boundaryFour,
          title: StreamEventOverlayType.boundaryFour.title,
          duration: StreamEventOverlayType.boundaryFour.defaultDuration,
          createdAt: event.timestamp,
        );
      }
    }

    if (event.eventType == BallEventType.lineupChange) {
      if (event.isBowlerChange &&
          event.bowlerName != null &&
          event.bowlerName!.isNotEmpty) {
        return StreamEventOverlay(
          type: StreamEventOverlayType.newBowler,
          title: StreamEventOverlayType.newBowler.title,
          subtitle: event.bowlerName!,
          playerName: event.bowlerName!,
          createdAt: event.timestamp,
        );
      }
      if (event.nextStrikerName != null && event.nextStrikerName!.isNotEmpty) {
        return StreamEventOverlay(
          type: StreamEventOverlayType.newBatter,
          title: StreamEventOverlayType.newBatter.title,
          subtitle: event.nextStrikerName!,
          playerName: event.nextStrikerName!,
          createdAt: event.timestamp,
        );
      }
    }

    return null;
  }

  StreamEventOverlay? detectMilestone({
    required String playerName,
    required int runs,
  }) {
    if (runs == 100) {
      return StreamEventOverlay(
        type: StreamEventOverlayType.century,
        title: StreamEventOverlayType.century.title,
        subtitle: playerName,
        playerName: playerName,
        duration: StreamEventOverlayType.century.defaultDuration,
        createdAt: DateTime.now(),
      );
    }
    if (runs == 50) {
      return StreamEventOverlay(
        type: StreamEventOverlayType.fiftyRuns,
        title: StreamEventOverlayType.fiftyRuns.title,
        subtitle: playerName,
        playerName: playerName,
        duration: StreamEventOverlayType.fiftyRuns.defaultDuration,
        createdAt: DateTime.now(),
      );
    }
    return null;
  }
}
