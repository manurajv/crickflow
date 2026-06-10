import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/dismissal_fielder.dart';
import '../../data/models/innings_model.dart';
import 'dismissal_sub_type.dart';

/// Professional dismissal text for scorecards and fall-of-wickets.
class DismissalFormatter {
  DismissalFormatter._();

  /// Wicketkeeper mark for scorecards and fielding displays.
  static const String keeperMark = '†';

  /// Prefixes keeper name with [keeperMark] when not already present.
  static String formatKeeperDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith(keeperMark)) return trimmed;
    return '$keeperMark$trimmed';
  }

  /// True when event is a keeper catch (new sub-type or legacy wicket type).
  static bool isCaughtBehindEvent(BallEventModel event) {
    return event.dismissalSubType == DismissalSubType.caughtBehind ||
        event.wicketType == WicketType.caughtBehind;
  }

  /// When scorer picks "Caught", resolve wicket type and optional sub-type.
  /// Priority: bowler → caught & bowled; wicketkeeper → caught + caught_behind.
  static ({WicketType wicketType, String? dismissalSubType}) resolveCaughtDismissal({
    required String fielderId,
    String? bowlerId,
    String? wicketKeeperId,
  }) {
    if (bowlerId != null &&
        bowlerId.isNotEmpty &&
        fielderId == bowlerId) {
      return (wicketType: WicketType.caughtAndBowled, dismissalSubType: null);
    }
    if (wicketKeeperId != null &&
        wicketKeeperId.isNotEmpty &&
        fielderId == wicketKeeperId) {
      return (
        wicketType: WicketType.caught,
        dismissalSubType: DismissalSubType.caughtBehind,
      );
    }
    return (wicketType: WicketType.caught, dismissalSubType: null);
  }

  @Deprecated('Use resolveCaughtDismissal')
  static WicketType resolveCaughtWicketType({
    required String fielderId,
    String? bowlerId,
    String? wicketKeeperId,
  }) =>
      resolveCaughtDismissal(
        fielderId: fielderId,
        bowlerId: bowlerId,
        wicketKeeperId: wicketKeeperId,
      ).wicketType;

  /// Standard catch — scorer must pick the fielder.
  static bool needsFielderPicker(WicketType type) => type == WicketType.caught;

  /// Stumped auto-assigns the active wicketkeeper.
  static bool usesWicketKeeper(WicketType type) => type == WicketType.stumped;

  /// Counts toward wickets fallen, FOW, and bowling figures wicket column.
  static bool countsAsWicket(WicketType? type, {bool isMankad = false}) {
    if (type == null) return false;
    if (type == WicketType.retiredHurt) return false;
    return creditsBowlerWicket(type, isMankad: isMankad) ||
        type == WicketType.runOut ||
        type == WicketType.mankad ||
        type == WicketType.retiredOut ||
        type == WicketType.obstructingField ||
        type == WicketType.timedOut ||
        type == WicketType.handledBall ||
        type == WicketType.hitBallTwice ||
        type == WicketType.other;
  }

  static bool needsDismissedBatterPicker(WicketType type) =>
      type == WicketType.runOut;

  static bool isMankadType(WicketType? type) => type == WicketType.mankad;

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
    String? nonStrikerId,
  }) {
    if (type == WicketType.runOut) return null;
    if (type == WicketType.mankad) return nonStrikerId;
    return strikerId;
  }

  /// Whether the bowler receives a wicket on the bowling figures.
  static bool creditsBowlerWicket(WicketType? type, {bool isMankad = false}) {
    if (type == null || isMankad || type == WicketType.mankad) return false;
    return switch (type) {
      WicketType.bowled ||
      WicketType.caught ||
      WicketType.caughtBehind ||
      WicketType.caughtAndBowled ||
      WicketType.lbw ||
      WicketType.stumped ||
      WicketType.hitWicket =>
        true,
      WicketType.runOut ||
      WicketType.mankad ||
      WicketType.retiredHurt ||
      WicketType.retiredOut ||
      WicketType.obstructingField ||
      WicketType.timedOut ||
      WicketType.handledBall ||
      WicketType.hitBallTwice ||
      WicketType.other =>
        false,
    };
  }

  /// Persisted dismissal type (mankad stored as run_out).
  static String dismissalTypeFor(WicketType? type, {bool isMankad = false}) {
    if (isMankad || type == WicketType.mankad) return 'run_out';
    if (type == null) return '';
    return type.name;
  }

  /// Canonical scorecard line from persisted [BallEventModel] metadata.
  static String scorecardText(
    BallEventModel event, {
    Map<String, String>? playerNames,
    String? fallbackDismissalText,
  }) =>
      fromWicketEvent(
        event,
        playerNames: playerNames,
        fallbackDismissalText: fallbackDismissalText,
      );

  /// Build scorecard dismissal from persisted [BallEventModel] metadata.
  static String buildDismissalText(BallEventModel event) {
    return format(
      type: event.wicketType,
      bowlerName: _name(event.bowlerName, event.bowlerId),
      fielderName: _primaryFielderName(event),
      secondaryFielderName: _secondaryFielderName(event),
      isMankad: event.isMankad,
      fielders: event.fielders,
      dismissalSubType: event.dismissalSubType,
    );
  }

  static String format({
    required WicketType? type,
    String bowlerName = '',
    String fielderName = '',
    String? secondaryFielderName,
    bool isMankad = false,
    List<DismissalFielder> fielders = const [],
    String? dismissalSubType,
  }) {
    if (type == null) return 'out';

    final bowler = _shortName(bowlerName);
    final fielder = _shortName(fielderName);
    final secondary = _shortName(secondaryFielderName ?? '');

    if (isMankad || type == WicketType.mankad) {
      return formatRunOutDisplay(primaryFielderName: bowler);
    }

    if (type == WicketType.caught &&
        dismissalSubType == DismissalSubType.caughtBehind) {
      return _formatCaughtBehind(keeper: fielder, bowler: bowler);
    }
    if (type == WicketType.caughtBehind) {
      return _formatCaughtBehind(keeper: fielder, bowler: bowler);
    }

    return switch (type) {
      WicketType.bowled => bowler.isEmpty ? 'bowled' : 'b $bowler',
      WicketType.caught => _formatCaught(fielder: fielder, bowler: bowler),
      WicketType.caughtBehind =>
        _formatCaughtBehind(keeper: fielder, bowler: bowler),
      WicketType.caughtAndBowled =>
        bowler.isEmpty ? 'c & b' : 'c & b $bowler',
      WicketType.lbw => bowler.isEmpty ? 'lbw' : 'lbw b $bowler',
      WicketType.runOut => formatRunOutDisplay(
          primaryFielderName: fielder,
          secondaryFielderName: secondary,
          fielders: fielders,
        ),
      WicketType.stumped => _formatStumped(bowler: bowler),
      WicketType.hitWicket =>
        bowler.isEmpty ? 'hit wicket' : 'hit wicket b $bowler',
      WicketType.retiredHurt => 'retired hurt',
      WicketType.retiredOut => 'retired out',
      WicketType.obstructingField => 'obstructing the field',
      WicketType.timedOut => 'timed out',
      WicketType.handledBall => 'handled the ball',
      WicketType.hitBallTwice => 'hit the ball twice',
      WicketType.other => 'out',
      WicketType.mankad => formatRunOutDisplay(primaryFielderName: bowler),
    };
  }

  static String _shortName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed;
  }

  static String _name(String? name, String? id) {
    final n = name?.trim() ?? '';
    if (n.isNotEmpty) return n;
    return id?.trim() ?? '';
  }

  static String _primaryFielderName(BallEventModel event) {
    final primary = event.primaryFielderName?.trim() ?? '';
    if (primary.isNotEmpty) return primary;
    final legacy = event.fielderName?.trim() ?? '';
    if (legacy.isNotEmpty) return legacy;
    if (event.fielders.isNotEmpty) {
      return event.fielders.first.playerName.trim();
    }
    if (event.fielderNames.isNotEmpty) {
      return event.fielderNames.first.trim();
    }
    if (event.wicketType == WicketType.caughtBehind ||
        isCaughtBehindEvent(event)) {
      return event.wicketKeeperName?.trim() ?? '';
    }
    return '';
  }

  /// Resolves fielder display name from stored ids when legacy events lack names.
  static String _resolvedPrimaryFielderName(
    BallEventModel event, {
    Map<String, String>? playerNames,
  }) {
    final direct = _primaryFielderName(event);
    if (direct.isNotEmpty || playerNames == null) return direct;

    final id = event.primaryFielderId ??
        event.fielderId ??
        ((isCaughtBehindEvent(event) || event.wicketType == WicketType.stumped)
            ? event.wicketKeeperId
            : null);
    if (id != null && id.isNotEmpty) {
      return playerNames[id]?.trim() ?? '';
    }
    return '';
  }

  static String _resolvedBowlerName(
    BallEventModel event, {
    Map<String, String>? playerNames,
  }) {
    var bowler = _name(event.bowlerName, event.bowlerId);
    if (bowler.isEmpty &&
        event.bowlerId != null &&
        playerNames != null) {
      bowler = playerNames[event.bowlerId!]?.trim() ?? '';
    }
    return bowler;
  }

  static String _secondaryFielderName(BallEventModel event) {
    final secondary = event.secondaryFielderName?.trim() ?? '';
    if (secondary.isNotEmpty) return secondary;
    if (event.fielders.length >= 2) {
      return event.fielders[1].playerName.trim();
    }
    return '';
  }

  /// Scorecard: `st b Bowler` — keeper name is stored but not shown.
  static String _formatStumped({required String bowler}) {
    if (bowler.isEmpty) return 'stumped';
    return 'st b $bowler';
  }

  /// Standard scorecard: `c Fielder b Bowler`.
  static String _formatCaught({
    required String fielder,
    required String bowler,
  }) {
    if (fielder.isNotEmpty && bowler.isNotEmpty) {
      return 'c $fielder b $bowler';
    }
    if (fielder.isNotEmpty) return 'c $fielder';
    if (bowler.isNotEmpty) return 'b $bowler';
    return 'caught';
  }

  /// Caught behind: `c †Keeper b Bowler`.
  static String _formatCaughtBehind({
    required String keeper,
    required String bowler,
  }) {
    final keeperDisplay = formatKeeperDisplayName(keeper);
    if (keeperDisplay.isNotEmpty && bowler.isNotEmpty) {
      return 'c $keeperDisplay b $bowler';
    }
    if (keeperDisplay.isNotEmpty) return 'c $keeperDisplay';
    if (bowler.isNotEmpty) return 'b $bowler';
    return 'caught behind';
  }

  /// `run out Rahul Sharma` or `run out Rahul Sharma / Virat Singh`.
  static String formatRunOutDisplay({
    String? primaryFielderName,
    String? secondaryFielderName,
    List<DismissalFielder> fielders = const [],
  }) {
    final names = <String>[];
    final primary = _shortName(primaryFielderName ?? '');
    final secondary = _shortName(secondaryFielderName ?? '');

    if (primary.isNotEmpty && !_isInvalidRunOutFielderName(primary)) {
      names.add(primary);
    } else if (fielders.isNotEmpty) {
      final n = fielders.first.playerName.trim();
      if (n.isNotEmpty) names.add(n);
    }

    if (secondary.isNotEmpty && !_isInvalidRunOutFielderName(secondary)) {
      names.add(secondary);
    } else if (fielders.length >= 2) {
      final n = fielders[1].playerName.trim();
      if (n.isNotEmpty) names.add(n);
    }

    if (names.isEmpty) return 'run out';
    if (names.length == 1) return 'run out ${names.single}';
    return 'run out ${names.join(' / ')}';
  }

  static Map<String, String> playerNamesFromInnings(InningsModel innings) {
    final names = <String, String>{};
    for (final b in innings.batsmen) {
      if (b.playerId.isNotEmpty) {
        names[b.playerId] = b.playerName;
      }
    }
    for (final b in innings.bowlers) {
      if (b.playerId.isNotEmpty) {
        names[b.playerId] = b.playerName;
      }
    }
    return names;
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
        return formatRunOutDisplay(
          primaryFielderName: trimmed.substring(start + 1, end).trim(),
        );
      }
    }
    if (lower.startsWith('run out ')) {
      final rest = trimmed.substring(8).trim();
      if (rest.toLowerCase() == 'run out' || rest.isEmpty) return 'run out';
      if (rest.contains(' / ')) return trimmed;
      if (rest.contains('/')) {
        final fielderOnly = rest.split('/').first.trim();
        return formatRunOutDisplay(primaryFielderName: fielderOnly);
      }
      if (rest.toLowerCase().startsWith('b ') ||
          _isInvalidRunOutFielderName(rest)) {
        return 'run out';
      }
      return formatRunOutDisplay(primaryFielderName: rest);
    }
    final stumped = _normalizeStumpedDisplay(trimmed);
    if (stumped != null) return stumped;
    return trimmed;
  }

  /// Builds scorecard dismissal from Firestore wicket metadata.
  static String fromWicketEvent(
    BallEventModel event, {
    Map<String, String>? playerNames,
    String? fallbackDismissalText,
  }) {
    if (event.isMankad) {
      var bowler = _name(event.bowlerName, event.bowlerId);
      if (bowler.isEmpty &&
          event.bowlerId != null &&
          playerNames != null) {
        bowler = playerNames[event.bowlerId!]?.trim() ?? '';
      }
      final built = formatRunOutDisplay(primaryFielderName: bowler);
      if (built != 'run out') return built;
      final parsed = _parseLegacyRunOut(fallbackDismissalText ?? event.dismissalText);
      if (parsed.primary.isNotEmpty) {
        return formatRunOutDisplay(primaryFielderName: parsed.primary);
      }
      return built;
    }

    if (event.wicketType == WicketType.runOut) {
      var primary = _primaryFielderName(event);
      var secondary = _secondaryFielderName(event);

      if (primary.isEmpty &&
          event.primaryFielderId != null &&
          playerNames != null) {
        primary = playerNames[event.primaryFielderId!]?.trim() ?? '';
      }
      if (primary.isEmpty &&
          event.fielderId != null &&
          playerNames != null) {
        primary = playerNames[event.fielderId!]?.trim() ?? '';
      }
      final bowlerName = _name(event.bowlerName, event.bowlerId);
      if (!event.isMankad &&
          primary.isNotEmpty &&
          bowlerName.isNotEmpty &&
          primary == bowlerName) {
        primary = '';
      }
      if (secondary.isEmpty &&
          event.secondaryFielderId != null &&
          playerNames != null) {
        secondary = playerNames[event.secondaryFielderId!]?.trim() ?? '';
      }

      final built = formatRunOutDisplay(
        primaryFielderName: primary,
        secondaryFielderName: secondary,
        fielders: event.fielders,
      );
      if (built != 'run out') return built;

      final parsed = _parseLegacyRunOut(fallbackDismissalText ?? event.dismissalText);
      if (parsed.primary.isNotEmpty || parsed.secondary.isNotEmpty) {
        return formatRunOutDisplay(
          primaryFielderName: parsed.primary,
          secondaryFielderName: parsed.secondary,
        );
      }
      return built;
    }

    if (event.wicketType == WicketType.stumped) {
      return normalizeScorecardDismissal(
        format(
          type: event.wicketType,
          bowlerName: _resolvedBowlerName(event, playerNames: playerNames),
          fielderName: _resolvedPrimaryFielderName(
            event,
            playerNames: playerNames,
          ),
          fielders: event.fielders,
        ),
      );
    }

    if (event.wicketType == WicketType.caughtAndBowled) {
      return normalizeScorecardDismissal(
        format(
          type: event.wicketType,
          bowlerName: _resolvedBowlerName(event, playerNames: playerNames),
        ),
      );
    }

    if (event.wicketType == WicketType.caught ||
        event.wicketType == WicketType.caughtBehind ||
        isCaughtBehindEvent(event)) {
      final built = normalizeScorecardDismissal(
        format(
          type: event.wicketType == WicketType.caughtBehind
              ? WicketType.caughtBehind
              : WicketType.caught,
          bowlerName: _resolvedBowlerName(event, playerNames: playerNames),
          fielderName: _resolvedPrimaryFielderName(
            event,
            playerNames: playerNames,
          ),
          fielders: event.fielders,
          dismissalSubType: event.dismissalSubType,
        ),
      );
      final stored = normalizeScorecardDismissal(
        event.dismissalText?.trim() ?? '',
      );
      if (built.startsWith('c ') && built.contains(' b ')) {
        if (isCaughtBehindEvent(event) &&
            built.contains(keeperMark)) {
          return built;
        }
        if (stored.startsWith('c ') &&
            stored.contains(' b ') &&
            stored.contains(keeperMark) &&
            !_storedDismissalConflicts(event, stored)) {
          return stored;
        }
        if (built.contains(' b ')) return built;
      }
      if (stored.startsWith('c ') &&
          stored.contains(' b ') &&
          !_storedDismissalConflicts(event, stored)) {
        if (isCaughtBehindEvent(event) &&
            !stored.contains(keeperMark)) {
          return built;
        }
        if (event.wicketType == WicketType.caughtBehind &&
            !stored.contains(keeperMark)) {
          return built;
        }
        return stored;
      }
      return built;
    }

    final built = normalizeScorecardDismissal(
      format(
        type: event.wicketType,
        bowlerName: _resolvedBowlerName(event, playerNames: playerNames),
        fielderName: _resolvedPrimaryFielderName(
          event,
          playerNames: playerNames,
        ),
        secondaryFielderName: _secondaryFielderName(event),
        isMankad: event.isMankad,
        fielders: event.fielders,
      ),
    );
    final stored = normalizeScorecardDismissal(
      event.dismissalText?.trim() ?? '',
    );

    if (!isGenericLabel(built) && built.isNotEmpty) return built;
    if (stored.isNotEmpty &&
        !isGenericLabel(stored) &&
        !_storedDismissalConflicts(event, stored)) {
      return stored;
    }
    return built.isNotEmpty ? built : stored;
  }

  static ({String primary, String secondary}) _parseLegacyRunOut(String? text) {
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) return (primary: '', secondary: '');

    var rest = trimmed;
    if (rest.toLowerCase().startsWith('run out ')) {
      rest = rest.substring(8).trim();
    }
    if (rest.startsWith('(') && rest.endsWith(')')) {
      rest = rest.substring(1, rest.length - 1).trim();
    }
    if (rest.toLowerCase().startsWith('b ')) {
      return (primary: '', secondary: '');
    }
    if (rest.contains(' / ')) {
      final parts = rest.split(' / ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      return (
        primary: parts.isNotEmpty ? parts.first : '',
        secondary: parts.length >= 2 ? parts[1] : '',
      );
    }
    if (rest.contains('/')) {
      return (primary: rest.split('/').first.trim(), secondary: '');
    }
    if (_isInvalidRunOutFielderName(rest)) {
      return (primary: '', secondary: '');
    }
    return (primary: rest, secondary: '');
  }

  static bool _isInvalidRunOutFielderName(String name) {
    final t = name.trim().toLowerCase();
    if (t.isEmpty) return true;
    if (t == 'run out' || t == 'runout') return true;
    if (t.startsWith('b ')) return true;
    return false;
  }

  /// Converts stored stumped lines to `st b Bowler` (drops keeper name).
  static String? _normalizeStumpedDisplay(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();

    if (lower.startsWith('st ') && lower.contains(' b ')) {
      final idx = lower.lastIndexOf(' b ');
      final bowler = trimmed.substring(idx + 3).trim();
      return _formatStumped(bowler: bowler);
    }
    if (lower.startsWith('stumped b ')) {
      return _formatStumped(bowler: trimmed.substring(10).trim());
    }
    if (lower == 'stumped') return 'stumped';
    return null;
  }

  static bool _storedDismissalConflicts(BallEventModel event, String stored) {
    final t = stored.toLowerCase();
    if (event.wicketType == WicketType.caught ||
        isCaughtBehindEvent(event)) {
      return t.contains('c & b') || t.startsWith('caught b ');
    }
    return false;
  }

  static String fielderNamesFromEvent(BallEventModel event) {
    final primary = _primaryFielderName(event);
    final secondary = _secondaryFielderName(event);
    if (primary.isEmpty) return '';
    if (secondary.isEmpty) return primary;
    return '$primary / $secondary';
  }

  static String fielderNames({
    String primaryName = '',
    List<DismissalFielder> fielders = const [],
  }) {
    return formatRunOutDisplay(
      primaryFielderName: primaryName,
      fielders: fielders,
      secondaryFielderName: fielders.length >= 2 ? fielders[1].playerName : '',
    ).replaceFirst('run out ', '');
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
