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
        return 'No ball';
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

  static String forEvent(BallEventModel event) {
    if (event.eventType == BallEventType.noBall) {
      final add = event.runs - event.extraRuns;
      final mode = event.noBallRunsMode ?? NoBallRunsMode.bat;
      if (add == 0) return 'No ball';
      return switch (mode) {
        NoBallRunsMode.bat when add >= 6 => 'No ball — SIX! ($add off the bat)',
        NoBallRunsMode.bat when add == 4 => 'No ball — FOUR!',
        NoBallRunsMode.bat => 'No ball — $add off the bat',
        NoBallRunsMode.bye => 'No ball — $add bye${add == 1 ? '' : 's'}',
        NoBallRunsMode.legBye => 'No ball — $add leg bye${add == 1 ? '' : 's'}',
      };
    }
    return forBall(
      type: event.eventType,
      runs: event.runs,
      wicketType: event.wicketType,
    );
  }
}
