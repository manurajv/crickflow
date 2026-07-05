import '../../../core/constants/enums.dart';
import '../../../data/models/ball_event_model.dart';
import '../data/models/stream_overlay_theme.dart';
import '../domain/streaming_enums.dart';

/// Maps ball events to broadcast overlay graphics.
class StreamEventDetector {
  const StreamEventDetector();

  StreamEventOverlay? detect(
    BallEventModel event, {
    BallEventModel? previous,
  }) {
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

    final boundary = _detectBoundary(event);
    if (boundary != null) return boundary;

    if (event.eventType == BallEventType.lineupChange) {
      if (event.isBowlerChange &&
          event.bowlerName != null &&
          event.bowlerName!.isNotEmpty) {
        return StreamEventOverlay(
          type: StreamEventOverlayType.newBowler,
          title: StreamEventOverlayType.newBowler.title,
          subtitle: event.bowlerName!,
          playerName: event.bowlerName!,
          playerId: event.bowlerId ?? '',
          duration: StreamEventOverlayType.newBowler.defaultDuration,
          createdAt: event.timestamp,
        );
      }

      final incoming = _resolveIncomingBatter(event, previous);
      if (incoming != null) {
        return StreamEventOverlay(
          type: StreamEventOverlayType.newBatter,
          title: StreamEventOverlayType.newBatter.title,
          subtitle: incoming.name,
          playerName: incoming.name,
          playerId: incoming.id,
          duration: StreamEventOverlayType.newBatter.defaultDuration,
          createdAt: event.timestamp,
        );
      }
    }

    return null;
  }

  /// Finds the batter walking in on [lineupChange] (post-wicket picker, run-out flow).
  ({String id, String name})? _resolveIncomingBatter(
    BallEventModel event,
    BallEventModel? previous,
  ) {
    if (previous == null) return null;

    if (event.nextStrikerId != null &&
        event.nextStrikerId!.isNotEmpty &&
        event.nextStrikerName != null &&
        event.nextStrikerName!.isNotEmpty) {
      return (id: event.nextStrikerId!, name: event.nextStrikerName!);
    }

    final prevStriker = previous.strikerId;
    final prevNon = previous.nonStrikerId;
    final currStriker = event.strikerId;
    final currNon = event.nonStrikerId;

    if (currStriker != null &&
        currStriker.isNotEmpty &&
        currStriker != prevStriker &&
        currStriker != prevNon) {
      final name = event.lineupStrikerName?.trim();
      return (
        id: currStriker,
        name: name != null && name.isNotEmpty ? name : currStriker,
      );
    }

    if (currNon != null &&
        currNon.isNotEmpty &&
        currNon != prevStriker &&
        currNon != prevNon) {
      final name = event.lineupNonStrikerName?.trim();
      return (
        id: currNon,
        name: name != null && name.isNotEmpty ? name : currNon,
      );
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

  StreamEventOverlay? _detectBoundary(BallEventModel event) {
    if (_isSix(event)) {
      return StreamEventOverlay(
        type: StreamEventOverlayType.hugeSix,
        title: StreamEventOverlayType.hugeSix.title,
        subtitle: '${_boundaryRunLabel(event)} runs',
        duration: StreamEventOverlayType.hugeSix.defaultDuration,
        createdAt: event.timestamp,
      );
    }
    if (_isFour(event)) {
      return StreamEventOverlay(
        type: StreamEventOverlayType.boundaryFour,
        title: StreamEventOverlayType.boundaryFour.title,
        duration: StreamEventOverlayType.boundaryFour.defaultDuration,
        createdAt: event.timestamp,
      );
    }
    return null;
  }

  bool _isSix(BallEventModel event) {
    if (event.boundaryType == 'six') return true;
    return switch (event.eventType) {
      BallEventType.runs => event.batsmanRuns >= 6,
      BallEventType.noBall => event.batsmanRuns >= 6,
      BallEventType.bye || BallEventType.legBye => event.runs >= 6,
      _ => false,
    };
  }

  bool _isFour(BallEventModel event) {
    if (_isSix(event)) return false;
    if (event.boundaryType == 'four') return true;
    return switch (event.eventType) {
      BallEventType.runs => event.batsmanRuns == 4,
      BallEventType.noBall => event.batsmanRuns == 4,
      BallEventType.bye || BallEventType.legBye => event.runs == 4,
      _ => false,
    };
  }

  int _boundaryRunLabel(BallEventModel event) {
    return switch (event.eventType) {
      BallEventType.bye || BallEventType.legBye => event.runs,
      BallEventType.noBall => event.batsmanRuns,
      _ => event.batsmanRuns > 0 ? event.batsmanRuns : event.runs,
    };
  }
}
