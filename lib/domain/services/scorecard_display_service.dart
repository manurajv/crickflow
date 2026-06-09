import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_rules_model.dart';
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

  static List<String> toBatNames(MatchModel match, InningsModel innings) {
    final setup = match.setup;
    if (setup == null) return [];

    final isTeamA = innings.battingTeamId == match.teamAId;
    final ids = setup.squadIdsForTeam(isTeamA);
    final names =
        isTeamA ? setup.teamASquadNames : setup.teamBSquadNames;
    final batted = innings.batsmen.map((b) => b.playerId).toSet();

    return ids
        .where(
          (id) =>
              !batted.contains(id) &&
              !ScoringDisplayUtils.isPlayerOut(innings, id),
        )
        .map((id) => names[id]?.trim().isNotEmpty == true ? names[id]! : id)
        .toList();
  }

  /// Professional dismissal line for scorecard rows.
  static String batsmanDismissalText(
    BatsmanInningsModel batsman, {
    required bool onCrease,
  }) {
    if (!batsman.isOut) {
      return onCrease ? 'not out' : '';
    }
    return normalizeDismissalText(batsman.dismissalInfo);
  }

  /// Maps legacy enum labels to cricket notation where possible.
  static String normalizeDismissalText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    if (_isProfessionalNotation(trimmed)) return trimmed;

    return switch (trimmed.toLowerCase().replaceAll(' ', '')) {
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
      'obstructingfield' => 'obstructing the field',
      'timedout' => 'timed out',
      'handledball' => 'handled the ball',
      'hitballtwice' => 'hit the ball twice',
      _ => trimmed,
    };
  }

  static bool _isProfessionalNotation(String text) {
    final lower = text.toLowerCase();
    const prefixes = [
      'c ',
      'c &',
      'lbw ',
      'lbw b',
      'b ',
      'run out',
      'st ',
      'hit wicket',
      'retired hurt',
      'retired out',
      'not out',
      'obstructing',
      'timed out',
      'handled the',
      'hit the ball',
    ];
    for (final p in prefixes) {
      if (lower.startsWith(p)) return true;
    }
    return lower == 'lbw' || lower == 'bowled';
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
