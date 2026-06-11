import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_rules_model.dart';
import '../../domain/services/dismissal_formatter.dart';
import '../../features/scoring/presentation/utils/scoring_display_utils.dart';

/// Read-only helpers for scorecard presentation (no scoring changes).
class ScorecardDisplayService {
  ScorecardDisplayService._();

  static InningsExtrasBreakdown extrasBreakdown({
    required InningsModel innings,
    required List<BallEventModel> events,
    required MatchRulesModel rules,
  }) {
    var wides = 0;
    var byes = 0;
    var legByes = 0;
    var noBalls = 0;
    var penalties = 0;

    for (final e in events) {
      if (e.inningsNumber != innings.inningsNumber) continue;
      switch (e.eventType) {
        case BallEventType.wide:
          wides += e.runs;
        case BallEventType.bye:
          byes += e.runs;
        case BallEventType.legBye:
          legByes += e.runs;
        case BallEventType.noBall:
          noBalls += e.extraRuns;
          if (e.noBallRunsMode == NoBallRunsMode.bye) {
            byes += e.noBallByeRuns;
          } else if (e.noBallRunsMode == NoBallRunsMode.legBye) {
            legByes += e.noBallLegByeRuns;
          }
        case BallEventType.penalty:
          penalties += e.runs;
        case BallEventType.wicket:
          if (e.wicketType == WicketType.runOut &&
              e.runOutDeliveryKind != null &&
              e.runOutDeliveryKind != RunOutDeliveryKind.normal) {
            switch (e.runOutDeliveryKind!) {
              case RunOutDeliveryKind.wide:
                wides += e.runs - e.batsmanRuns;
              case RunOutDeliveryKind.noBall:
                noBalls += e.noBallRuns;
                byes += e.noBallByeRuns;
                legByes += e.noBallLegByeRuns;
              case RunOutDeliveryKind.bye:
                byes += e.byeRuns;
              case RunOutDeliveryKind.legBye:
                legByes += e.legByeRuns;
              case RunOutDeliveryKind.normal:
                break;
            }
          }
        default:
          break;
      }
    }

    return InningsExtrasBreakdown(
      total: innings.extras,
      wides: wides,
      byes: byes,
      legByes: legByes,
      noBalls: noBalls,
      penalties: penalties,
    );
  }

  static String extrasDetailLabel(InningsExtrasBreakdown breakdown) {
    final parts = <String>[];
    if (breakdown.wides > 0) parts.add('wd ${breakdown.wides}');
    if (breakdown.noBalls > 0) parts.add('nb ${breakdown.noBalls}');
    if (breakdown.byes > 0) parts.add('b ${breakdown.byes}');
    if (breakdown.legByes > 0) parts.add('lb ${breakdown.legByes}');
    if (breakdown.penalties > 0) parts.add('p ${breakdown.penalties}');
    if (parts.isEmpty) return '';
    return '(${parts.join(', ')})';
  }

  static List<String> toBatNames(
    MatchModel match,
    InningsModel innings, {
    Map<String, String> extraNames = const {},
    List<BallEventModel> events = const [],
  }) {
    final setup = match.setup;
    if (setup == null) return [];

    final isTeamA = innings.battingTeamId == match.teamAId;
    final ids = setup.squadIdsForTeam(isTeamA);
    final names = Map<String, String>.from(
      playerNamesForInnings(match, innings),
    );
    names.addAll(extraNames);
    for (final e in events) {
      if (e.inningsNumber != innings.inningsNumber) continue;
      _putName(names, e.strikerId, e.lineupStrikerName);
      _putName(names, e.nonStrikerId, e.lineupNonStrikerName);
      _putName(names, e.nextStrikerId, e.nextStrikerName);
      _putName(names, e.dismissedPlayerId, e.dismissedPlayerName);
    }

    final onCrease = {
      if (innings.strikerId != null) innings.strikerId!,
      if (innings.nonStrikerId != null) innings.nonStrikerId!,
    };
    final entered = innings.batsmen.map((b) => b.playerId).toSet();

    return ids
        .where(
          (id) =>
              !entered.contains(id) &&
              !onCrease.contains(id) &&
              !ScoringDisplayUtils.isPlayerOut(innings, id),
        )
        .map((id) => resolvePlayerDisplayName(id, names))
        .toList();
  }

  static void _putName(Map<String, String> names, String? id, String? name) {
    if (id == null || id.isEmpty) return;
    if (name == null || name.trim().isEmpty) return;
    names[id] = name.trim();
  }

  static String resolvePlayerDisplayName(
    String playerId,
    Map<String, String> names,
  ) {
    final resolved = names[playerId]?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return playerId;
  }

  /// Resolve display names for wicket events (batters, bowlers, fielders).
  static Map<String, String> playerNamesForInnings(
    MatchModel match,
    InningsModel innings,
  ) {
    final names = DismissalFormatter.playerNamesFromInnings(innings);
    final setup = match.setup;
    if (setup == null) return names;

    for (final entry in setup.teamASquadNames.entries) {
      names.putIfAbsent(entry.key, () => entry.value);
    }
    for (final entry in setup.teamBSquadNames.entries) {
      names.putIfAbsent(entry.key, () => entry.value);
    }
    return names;
  }

  /// Wicket ball events keyed by dismissed batter id.
  static Map<String, BallEventModel> wicketEventsByBatsman({
    required InningsModel innings,
    required List<BallEventModel> events,
  }) {
    final map = <String, BallEventModel>{};
    for (final e in events) {
      if (e.inningsNumber != innings.inningsNumber) continue;
      if (e.eventType != BallEventType.wicket) continue;
      final id = e.dismissedPlayerId;
      if (id != null && id.isNotEmpty) map[id] = e;
    }
    return map;
  }

  /// Professional dismissal line using Firestore wicket metadata first.
  static String batsmanDismissalText(
    BatsmanInningsModel batsman, {
    required bool onCrease,
    BallEventModel? wicketEvent,
    Map<String, String>? playerNames,
  }) {
    if (batsman.retiredHurt && !batsman.isOut) {
      return onCrease ? 'not out' : 'retired hurt';
    }

    if (!batsman.isOut) {
      return onCrease ? 'not out' : '';
    }

    final stored = batsman.dismissalInfo.trim();

    if (wicketEvent != null) {
      final fromEvent = DismissalFormatter.fromWicketEvent(
        wicketEvent,
        playerNames: playerNames,
        fallbackDismissalText: stored,
      );
      if (fromEvent.isNotEmpty && !DismissalFormatter.isGenericLabel(fromEvent)) {
        return DismissalFormatter.normalizeScorecardDismissal(fromEvent);
      }
      return DismissalFormatter.fromWicketEvent(
        wicketEvent,
        playerNames: playerNames,
        fallbackDismissalText: stored,
      );
    }

    if (stored.isNotEmpty && !DismissalFormatter.isGenericLabel(stored)) {
      return DismissalFormatter.normalizeScorecardDismissal(stored);
    }

    return DismissalFormatter.normalizeScorecardDismissal(_legacyFallback(stored));
  }

  static String _legacyFallback(String raw) {
    if (raw.isEmpty) return '';
    return switch (raw.toLowerCase().replaceAll(' ', '')) {
      'bowled' => 'bowled',
      'lbw' => 'lbw',
      'caught' => 'caught',
      'caughtbehind' => 'caught behind',
      'caughtandbowled' => 'c & b',
      'runout' => 'run out',
      'stumped' => 'stumped',
      'hitwicket' => 'hit wicket',
      'retiredhurt' || 'retired' => 'retired hurt',
      'retiredout' => 'retired out',
      _ => raw,
    };
  }
}

class InningsExtrasBreakdown {
  const InningsExtrasBreakdown({
    required this.total,
    this.wides = 0,
    this.byes = 0,
    this.legByes = 0,
    this.noBalls = 0,
    this.penalties = 0,
  });

  final int total;
  final int wides;
  final int byes;
  final int legByes;
  final int noBalls;
  final int penalties;
}
