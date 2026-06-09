import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';

/// Auto commentary for ball events (template-based).
class CommentaryService {
  CommentaryService._();

  static String forBall({
    required BallEventType type,
    required int runs,
    WicketType? wicketType,
    String? fielderName,
    String? bowlerName,
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
        return forWicket(
          wicketType: wicketType,
          fielderName: fielderName,
          bowlerName: bowlerName,
        );
      case BallEventType.penalty:
        return 'Penalty runs awarded.';
    }
  }

  static String forWicket({
    WicketType? wicketType,
    String? fielderName,
    String? bowlerName,
  }) {
    final fielder = fielderName?.trim() ?? '';
    final bowler = bowlerName?.trim() ?? '';

    return switch (wicketType) {
      WicketType.caught ||
      WicketType.caughtBehind ||
      WicketType.caughtAndBowled when fielder.isNotEmpty && bowler.isNotEmpty =>
        'Caught by $fielder! $bowler gets the wicket.',
      WicketType.caught ||
      WicketType.caughtBehind ||
      WicketType.caughtAndBowled when fielder.isNotEmpty =>
        'Caught by $fielder!',
      WicketType.runOut when fielder.isNotEmpty =>
        'Excellent run out by $fielder.',
      WicketType.stumped when fielder.isNotEmpty =>
        'Sharp work behind the stumps from $fielder.',
      WicketType.bowled when bowler.isNotEmpty => 'Bowled! $bowler strikes.',
      WicketType.lbw when bowler.isNotEmpty => 'LBW! $bowler gets the decision.',
      WicketType.hitWicket => 'Hit wicket — gone!',
      WicketType.retiredHurt => 'Retired hurt.',
      WicketType.retiredOut => 'Retired out.',
      _ => 'WICKET! Huge moment in the match.',
    };
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
    if (event.eventType == BallEventType.wicket &&
        event.commentary.trim().isNotEmpty) {
      return event.commentary;
    }
    return forBall(
      type: event.eventType,
      runs: event.runs,
      wicketType: event.wicketType,
      fielderName: event.fielderName,
      bowlerName: event.bowlerName,
    );
  }
}
