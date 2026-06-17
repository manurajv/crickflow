import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import 'dismissal_formatter.dart';

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
      case BallEventType.lineupChange:
        return 'Lineup updated.';
      case BallEventType.wicketKeeperChange:
        return 'Wicketkeeper changed.';
      case BallEventType.endOver:
        return 'Over ended.';
      case BallEventType.batterSwap:
        return 'Batters changed.';
    }
  }

  static String forWicket({
    WicketType? wicketType,
    String? fielderName,
    String? bowlerName,
    bool isMankad = false,
    bool isWicketKeeper = false,
  }) {
    final fielder = fielderName?.trim() ?? '';
    final keeperFielder = isWicketKeeper
        ? DismissalFormatter.formatKeeperDisplayName(fielder)
        : fielder;
    final bowler = bowlerName?.trim() ?? '';

    if (isMankad || wicketType == WicketType.mankad) {
      return bowler.isNotEmpty
          ? 'Mankad! $bowler removes the non-striker.'
          : 'Mankad — non-striker run out.';
    }

    return switch (wicketType) {
      WicketType.caughtAndBowled when bowler.isNotEmpty =>
        'Caught & bowled! $bowler gets the wicket.',
      WicketType.caught ||
      WicketType.caughtBehind when keeperFielder.isNotEmpty && bowler.isNotEmpty =>
        wicketType == WicketType.caughtBehind
            ? 'Caught behind by $keeperFielder! $bowler gets the wicket.'
            : 'Caught by $keeperFielder! $bowler gets the wicket.',
      WicketType.caught ||
      WicketType.caughtBehind when keeperFielder.isNotEmpty =>
        wicketType == WicketType.caughtBehind
            ? 'Caught behind by $keeperFielder!'
            : 'Caught by $keeperFielder!',
      WicketType.runOut when fielder.isNotEmpty =>
        'Excellent run out by $fielder.',
      WicketType.stumped when fielder.isNotEmpty =>
        'Sharp work behind the stumps from '
            '${DismissalFormatter.formatKeeperDisplayName(fielder)}.',
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
    if ((event.eventType == BallEventType.wicket ||
            event.eventType == BallEventType.batterSwap) &&
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
