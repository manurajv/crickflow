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

  /// Broadcast-style headline: `Bowler to Batter, FOUR`.
  static String headlineForEvent(
    BallEventModel event, {
    required String strikerName,
    required String bowlerName,
  }) {
    final bowler = bowlerName.trim().isNotEmpty ? bowlerName.trim() : 'Bowler';
    final batter = strikerName.trim().isNotEmpty ? strikerName.trim() : 'Batter';
    final action = actionLabel(event);
    return '$bowler to $batter,\n$action';
  }

  /// Template-based descriptive commentary for the Comms feed.
  static String descriptiveForEvent(
    BallEventModel event, {
    String? strikerName,
    String? bowlerName,
  }) {
    if (event.commentary.trim().isNotEmpty &&
        event.eventType != BallEventType.runs) {
      return event.commentary.trim();
    }

  final idx = event.sequence;
    return switch (event.eventType) {
      BallEventType.runs => _runsDescription(event, idx),
      BallEventType.wicket => _wicketDescription(event, idx),
      BallEventType.wide => _pick(_wideDescriptions, idx),
      BallEventType.noBall => _noBallDescription(event, idx),
      BallEventType.bye => 'They sneak ${_runsWord(event.runs)} as a bye.',
      BallEventType.legBye => 'Leg bye — ${_runsWord(event.runs)} added.',
      BallEventType.penalty => 'Penalty runs awarded to the batting side.',
      _ => forEvent(event),
    };
  }

  static String actionLabel(BallEventModel event) {
    if (event.eventType == BallEventType.wicket && event.isWicket) {
      return wicketActionLabel(event);
    }
    return switch (event.eventType) {
      BallEventType.runs when event.runs >= 6 => 'SIX',
      BallEventType.runs when event.runs == 4 => 'FOUR',
      BallEventType.runs when event.runs == 0 => 'DOT BALL',
      BallEventType.runs => '${event.runs}',
      BallEventType.wide => 'WIDE',
      BallEventType.noBall => 'NO BALL',
      BallEventType.bye => 'BYE',
      BallEventType.legBye => 'LEG BYE',
      BallEventType.penalty => 'PENALTY',
      BallEventType.wicket => wicketActionLabel(event),
      _ => event.eventType.name.toUpperCase(),
    };
  }

  static String wicketActionLabel(BallEventModel event) {
    if (event.isMankad || event.wicketType == WicketType.mankad) {
      return 'OUT Run Out (Mankad)';
    }
    return switch (event.wicketType) {
      WicketType.caught ||
      WicketType.caughtBehind ||
      WicketType.caughtAndBowled =>
        'OUT Caught',
      WicketType.bowled => 'OUT Bowled',
      WicketType.lbw => 'OUT LBW',
      WicketType.stumped => 'OUT Stumped',
      WicketType.runOut => 'OUT Run Out',
      WicketType.hitWicket => 'OUT Hit Wicket',
      WicketType.retiredHurt => 'Retired Hurt',
      WicketType.retiredOut => 'Retired Out',
      _ => 'OUT',
    };
  }

  static String _runsDescription(BallEventModel event, int idx) {
    if (event.runs >= 6) return _pick(_sixDescriptions, idx);
    if (event.runs == 4) return _pick(_fourDescriptions, idx);
    if (event.runs == 0) return _pick(_dotDescriptions, idx);
    if (event.runs == 1) return 'Quick single to the fielder.';
    if (event.runs == 2) return 'Well placed — they pick up two.';
    if (event.runs == 3) return 'Good running — three runs.';
    return '${event.runs} run${event.runs == 1 ? '' : 's'} added.';
  }

  static String _wicketDescription(BallEventModel event, int idx) {
    if (event.wicketType == WicketType.runOut || event.isMankad) {
      return _pick(_runOutDescriptions, idx);
    }
    return _pick(_wicketDescriptions, idx);
  }

  static String _noBallDescription(BallEventModel event, int idx) {
    final add = event.runs - event.extraRuns;
    if (add >= 6) return 'No ball — massive six off the free hit delivery!';
    if (add == 4) return 'No ball — boundary off the bat!';
    return _pick(_noBallDescriptions, idx);
  }

  static String _runsWord(int runs) => runs == 1 ? 'a run' : '$runs runs';

  static String _pick(List<String> options, int idx) {
    if (options.isEmpty) return '';
    return options[idx % options.length];
  }

  static const _fourDescriptions = [
    'Beautiful cover drive for four.',
    'Cracked through the covers — four runs.',
    'Finds the gap and races away to the boundary.',
    'Elegant shot — four to the batting side.',
  ];

  static const _sixDescriptions = [
    'Massive hit over deep midwicket.',
    'Into the crowd — maximum!',
    'Huge six — what a shot.',
    'Clean strike — sails over the rope.',
  ];

  static const _dotDescriptions = [
    'Good tight bowling.',
    'Dot ball — pressure building.',
    'Defended solidly — no run.',
    'Beat the bat — excellent delivery.',
  ];

  static const _wicketDescriptions = [
    'Huge breakthrough for the bowling side.',
    'WICKET! The batter has to go.',
    'That changes the complexion of the game.',
    'The bowler strikes — wicket fallen.',
  ];

  static const _runOutDescriptions = [
    'Excellent fielding effort results in a run out.',
    'Sharp work in the field — run out!',
    'Direct hit — batter short of the crease.',
  ];

  static const _wideDescriptions = [
    'Wide down the leg side.',
    'Too wide — extra run to the batting side.',
    'Bowler strays — wide called.',
  ];

  static const _noBallDescriptions = [
    'No ball — overstepped the crease.',
    'No ball called by the umpire.',
    'Front foot no ball — free hit coming.',
  ];
}
