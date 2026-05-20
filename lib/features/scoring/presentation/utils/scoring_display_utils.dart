import '../../../../core/constants/enums.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/match_rules_model.dart';

/// Labels and over grouping for live scoring UI.
class ScoringDisplayUtils {
  ScoringDisplayUtils._();

  static String? tossSummaryLine(MatchModel match) {
    final setup = match.setup;
    if (setup == null ||
        setup.tossWinnerIsTeamA == null ||
        setup.tossWinnerBatsFirst == null) {
      return null;
    }
    final winnerName =
        setup.tossWinnerIsTeamA! ? match.teamAName : match.teamBName;
    final elected = setup.tossWinnerBatsFirst! ? 'bat' : 'bowl';
    return '$winnerName won the toss and elected to $elected';
  }

  static String? activePowerplayLabel(MatchModel match, InningsModel inn) {
    final slots = match.rules.powerplaySlots;
    if (slots.isEmpty) return null;
    final overIndex = inn.legalBalls ~/ match.rules.ballsPerOver;
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (slot.isEmpty) continue;
      final start = slot.first;
      final end = slot.length > 1 ? slot.last : start;
      if (overIndex >= start - 1 && overIndex < end) {
        return 'P${i + 1}';
      }
    }
    return null;
  }

  static String battingTeamName(MatchModel match, InningsModel inn) {
    if (inn.battingTeamId == match.teamAId) return match.teamAName;
    if (inn.battingTeamId == match.teamBId) return match.teamBName;
    return match.teamAName;
  }

  static String oversLabel(InningsModel inn, MatchRulesModel rules) {
    final overs = inn.legalBalls / rules.ballsPerOver;
    final total = rules.totalOvers;
    return '(${overs.toStringAsFixed(1)}/$total)';
  }

  static BatsmanInningsModel? batsman(InningsModel inn, String? id) {
    if (id == null) return null;
    for (final b in inn.batsmen) {
      if (b.playerId == id) return b;
    }
    return null;
  }

  static BowlerInningsModel? bowler(InningsModel inn, String? id) {
    if (id == null) return null;
    for (final b in inn.bowlers) {
      if (b.playerId == id) return b;
    }
    return null;
  }

  static String batsmanScoreLine(BatsmanInningsModel? b) {
    if (b == null) return '0(0)';
    return '${b.runs}(${b.balls})';
  }

  static String bowlerFigures(BowlerInningsModel? b, int ballsPerOver) {
    if (b == null) return '0-0-0-0';
    final overs = b.oversBowledBalls ~/ ballsPerOver;
    final rem = b.oversBowledBalls % ballsPerOver;
    return '$overs.$rem-0-${b.runsConceded}-${b.wickets}';
  }

  /// Events in the active (incomplete) over.
  static List<BallEventModel> currentOverEvents({
    required List<BallEventModel> events,
    required InningsModel inn,
    required int ballsPerOver,
  }) {
    final overIndex = inn.legalBalls ~/ ballsPerOver;
    return events
        .where(
          (e) =>
              e.inningsNumber == inn.inningsNumber && e.overNumber == overIndex,
        )
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  /// Events in the over that just finished (when legalBalls % bpo == 0).
  static List<BallEventModel> completedOverEvents({
    required List<BallEventModel> events,
    required InningsModel inn,
    required int ballsPerOver,
  }) {
    if (inn.legalBalls == 0 || inn.legalBalls % ballsPerOver != 0) {
      return [];
    }
    final overIndex = (inn.legalBalls ~/ ballsPerOver) - 1;
    return events
        .where(
          (e) =>
              e.inningsNumber == inn.inningsNumber && e.overNumber == overIndex,
        )
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  static String ballBubbleLabel(BallEventModel e) {
    if (e.eventType == BallEventType.wicket) return 'W';
    if (e.eventType == BallEventType.wide) {
      return e.runs > 1 ? 'Wd+${e.runs - e.extraRuns}' : 'Wd';
    }
    if (e.eventType == BallEventType.noBall) {
      return e.batsmanRuns > 0 ? 'Nb+${e.batsmanRuns}' : 'Nb';
    }
    if (e.eventType == BallEventType.bye) return e.runs > 0 ? 'B${e.runs}' : 'B';
    if (e.eventType == BallEventType.legBye) return e.runs > 0 ? 'Lb${e.runs}' : 'Lb';
    if (e.runs == 0) return '0';
    return '${e.runs}';
  }

  static int overRuns(List<BallEventModel> overEvents) =>
      overEvents.fold(0, (s, e) => s + e.runs);

  static int overWickets(List<BallEventModel> overEvents) =>
      overEvents.where((e) => e.eventType == BallEventType.wicket).length;

  static int overExtras(List<BallEventModel> overEvents) => overEvents
      .where(
        (e) =>
            e.eventType == BallEventType.wide ||
            e.eventType == BallEventType.noBall ||
            e.eventType == BallEventType.bye ||
            e.eventType == BallEventType.legBye,
      )
      .fold(0, (s, e) => s + e.runs);
}
