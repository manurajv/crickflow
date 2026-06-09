import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/dismissal_fielder.dart';

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
      WicketType.runOut => formatRunOut(fielder),
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

  /// Broadcast-style run out: `run out Kasun / Himanshu` (no parentheses).
  static String formatRunOut(String fielderNames) {
    if (fielderNames.trim().isEmpty) return 'run out';
    final parts = fielderNames
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    return 'run out ${parts.join(' / ')}';
  }

  /// Normalizes legacy/stored text for scorecard display.
  static String normalizeScorecardDismissal(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('run out (')) {
      final start = trimmed.indexOf('(');
      final end = trimmed.lastIndexOf(')');
      if (start >= 0 && end > start) {
        return formatRunOut(trimmed.substring(start + 1, end));
      }
    }
    if (lower.startsWith('run out ') && trimmed.contains('/')) {
      return formatRunOut(trimmed.substring(8));
    }
    return trimmed;
  }

  /// Builds scorecard dismissal from Firestore wicket metadata.
  static String fromWicketEvent(BallEventModel event) {
    final fielderLabel = fielderNamesFromEvent(event);
    final bowler = event.bowlerName ?? '';
    final built = normalizeScorecardDismissal(
      format(
        type: event.wicketType,
        bowlerName: bowler,
        fielderName: fielderLabel,
      ),
    );

    final stored = normalizeScorecardDismissal(
      event.dismissalText?.trim() ?? '',
    );
    if (!isGenericLabel(built) && built.isNotEmpty) return built;
    if (stored.isNotEmpty && !isGenericLabel(stored)) return stored;
    return built.isNotEmpty ? built : stored;
  }

  static String fielderNamesFromEvent(BallEventModel event) {
    return fielderNames(
      primaryName: event.fielderName ?? '',
      fielders: event.fielders,
    );
  }

  static String fielderNames({
    String primaryName = '',
    List<DismissalFielder> fielders = const [],
  }) {
    final names = <String>[];
    for (final f in fielders) {
      final n = f.playerName.trim();
      if (n.isNotEmpty) names.add(n);
    }
    if (names.isEmpty) {
      final single = primaryName.trim();
      if (single.isNotEmpty) names.add(single);
    }
    return names.join('/');
  }

  /// True when text is an enum label or empty notation without player names.
  static bool isGenericLabel(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return true;
    const generic = {
      'caught',
      'caught out',
      'caught behind',
      'runout',
      'run out',
      'bowled',
      'lbw',
      'stumped',
      'hit wicket',
      'hitwicket',
      'out',
      'other',
      'c -',
      'c & b',
      'c & b -',
    };
    if (generic.contains(t)) return true;
    if (t == 'run out ()') return true;
    return RegExp(r'^c\s*[-–]?\s*b?\s*[-–]?\s*$').hasMatch(t);
  }
}
