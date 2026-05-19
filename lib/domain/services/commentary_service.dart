import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';

/// Auto commentary for ball events (Phase 3.1 — template-based).
class CommentaryService {
  CommentaryService._();

  static String forBall({
    required BallEventType type,
    required int runs,
    WicketType? wicketType,
  }) {
    switch (type) {
      case BallEventType.runs:
        if (runs >= 6) {
          return 'SIX! Maximum — crowd on their feet!';
        }
        if (runs == 4) {
          return 'FOUR! Cracked to the boundary.';
        }
        if (runs == 0) return 'Dot ball — good pressure from the bowler.';
        return '$runs run${runs == 1 ? '' : 's'}';
      case BallEventType.wide:
        return 'Wide — extra run to the batting side.';
      case BallEventType.noBall:
        return 'No ball — free hit may apply.';
      case BallEventType.bye:
        return 'Bye — $runs run${runs == 1 ? '' : 's'}.';
      case BallEventType.legBye:
        return 'Leg bye — $runs run${runs == 1 ? '' : 's'}.';
      case BallEventType.wicket:
        final how = wicketType != null
            ? ' ${wicketType.name.replaceAll(RegExp(r'([A-Z])'), r' $1').trim()}'
            : '';
        return 'WICKET! Gone$how — huge moment in the match.';
      case BallEventType.penalty:
        return 'Penalty runs awarded.';
    }
  }

  static String forEvent(BallEventModel event) => forBall(
        type: event.eventType,
        runs: event.runs,
        wicketType: event.wicketType,
      );
}
