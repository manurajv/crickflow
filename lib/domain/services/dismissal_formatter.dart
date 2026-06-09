import '../../core/constants/enums.dart';

/// Professional dismissal text for scorecards and fall-of-wickets.
class DismissalFormatter {
  DismissalFormatter._();

  /// Caught / stumped — striker is always out; only fielder is chosen.
  static bool needsFielderPicker(WicketType type) {
    return switch (type) {
      WicketType.caught ||
      WicketType.caughtBehind ||
      WicketType.stumped =>
        true,
      _ => false,
    };
  }

  static bool needsDismissedBatterPicker(WicketType type) =>
      type == WicketType.runOut;

  static String fielderPickerTitle(WicketType type) {
    return switch (type) {
      WicketType.stumped => 'Select wicketkeeper',
      WicketType.runOut => 'Who assisted the run out?',
      WicketType.caughtBehind => 'Who took the catch?',
      WicketType.caught => 'Who took the catch?',
      _ => 'Select fielder',
    };
  }

  /// Default dismissed batter when not explicitly chosen (non run-out).
  static String? defaultDismissedPlayerId({
    required WicketType type,
    String? strikerId,
  }) {
    if (type == WicketType.runOut) return null;
    return strikerId;
  }

  static bool creditsBowlerWicket(WicketType? type) =>
      type != null && type != WicketType.runOut;

  static String format({
    required WicketType? type,
    String bowlerName = '',
    String fielderName = '',
  }) {
    final bowler = _shortName(bowlerName);
    final fielder = _shortName(fielderName);

    return switch (type) {
      WicketType.bowled => bowler.isEmpty ? 'bowled' : 'b $bowler',
      WicketType.caught =>
        fielder.isEmpty && bowler.isEmpty
            ? 'caught'
            : fielder.isEmpty
                ? 'c & b $bowler'
                : bowler.isEmpty
                    ? 'c $fielder'
                    : 'c $fielder b $bowler',
      WicketType.caughtBehind =>
        fielder.isEmpty && bowler.isEmpty
            ? 'caught behind'
            : fielder.isEmpty
                ? 'c † b $bowler'
                : bowler.isEmpty
                    ? 'c $fielder'
                    : 'c $fielder b $bowler',
      WicketType.caughtAndBowled =>
        bowler.isEmpty ? 'c & b' : 'c & b $bowler',
      WicketType.lbw => bowler.isEmpty ? 'lbw' : 'lbw b $bowler',
      WicketType.runOut =>
        fielder.isEmpty ? 'run out' : 'run out ($fielder)',
      WicketType.stumped => bowler.isEmpty
          ? (fielder.isEmpty ? 'stumped' : 'st $fielder')
          : (fielder.isEmpty ? 'st b $bowler' : 'st $fielder b $bowler'),
      WicketType.hitWicket =>
        bowler.isEmpty ? 'hit wicket' : 'hit wicket b $bowler',
      WicketType.retiredHurt => 'retired hurt',
      WicketType.retiredOut => 'retired out',
      WicketType.obstructingField => 'obstructing the field',
      WicketType.timedOut => 'timed out',
      WicketType.handledBall => 'handled the ball',
      WicketType.hitBallTwice => 'hit the ball twice',
      WicketType.other || null => 'out',
    };
  }

  static String _shortName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed;
  }
}
