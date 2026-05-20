import '../../../../core/constants/enums.dart';
import '../../../../core/utils/cricket_math.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/match_rules_model.dart';

/// Chase target stats for 2nd (or later) innings.
class InningsChaseDisplay {
  const InningsChaseDisplay({
    required this.target,
    required this.runsNeeded,
    required this.ballsRemaining,
    required this.currentRunRate,
    required this.requiredRunRate,
  });

  final int target;
  final int runsNeeded;
  final int ballsRemaining;
  final double currentRunRate;
  final double requiredRunRate;

  bool get isChasing => runsNeeded > 0;
}

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
    final coin = setup.coinResult;
    if (coin != null && coin.isNotEmpty) {
      return '$winnerName won the toss and elected to $elected · $coin';
    }
    return '$winnerName won the toss and elected to $elected';
  }

  /// True once this batter has faced at least one legal delivery (not a bye).
  static bool batsmanHasFacedBall(InningsModel inn, String? playerId) {
    if (playerId == null) return false;
    final b = batsman(inn, playerId);
    return b != null && b.balls > 0;
  }

  /// True once this bowler has bowled at least one legal delivery.
  static bool bowlerHasBowledBall(InningsModel inn, String? playerId) {
    if (playerId == null) return false;
    final b = bowler(inn, playerId);
    return b != null && b.oversBowledBalls > 0;
  }

  static bool isPlayerOut(InningsModel inn, String playerId) {
    for (final b in inn.batsmen) {
      if (b.playerId == playerId) return b.isOut;
    }
    return false;
  }

  /// Batting squad members who may still bat this innings.
  static List<T> eligibleBatters<T>(
    InningsModel inn,
    List<T> squad, {
    required String Function(T) idOf,
    String? excludePlayerId,
  }) {
    return squad.where((p) {
      final id = idOf(p);
      if (id == excludePlayerId) return false;
      return !isPlayerOut(inn, id);
    }).toList();
  }

  /// Bowler who completed the last over (from ball events, not [currentBowlerId]).
  static String? bowlerWhoFinishedLastOver({
    required InningsModel inn,
    required List<BallEventModel> events,
    required int ballsPerOver,
  }) {
    if (inn.legalBalls == 0 || inn.legalBalls % ballsPerOver != 0) {
      return null;
    }
    final overIndex = (inn.legalBalls ~/ ballsPerOver) - 1;
    final overEvents = events
        .where(
          (e) =>
              e.inningsNumber == inn.inningsNumber &&
              e.overNumber == overIndex,
        )
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (overEvents.isNotEmpty) {
      return overEvents.last.bowlerId;
    }
    return inn.currentBowlerId;
  }

  /// After an over ends, scorer must pick a different bowler before the next ball.
  static bool needsNextOverBowler(
    InningsModel inn,
    int ballsPerOver,
    List<BallEventModel> events,
  ) {
    final lastOverBowler = bowlerWhoFinishedLastOver(
      inn: inn,
      events: events,
      ballsPerOver: ballsPerOver,
    );
    if (lastOverBowler == null) return false;
    final current = inn.currentBowlerId;
    return current == null || current == lastOverBowler;
  }

  static int currentOverExtras(List<BallEventModel> overEvents) =>
      overExtras(overEvents);

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

  static InningsModel? _firstInnings(MatchModel match) {
    for (final i in match.innings) {
      if (i.inningsNumber == 1) return i;
    }
    if (match.innings.isNotEmpty && match.innings.first.inningsNumber == 1) {
      return match.innings.first;
    }
    return null;
  }

  static InningsChaseDisplay? chaseDisplay(
    MatchModel match,
    InningsModel inn,
    MatchRulesModel rules,
  ) {
    if (inn.inningsNumber < 2) return null;
    final first = _firstInnings(match);
    if (first == null) return null;

    final target = first.totalRuns + 1;
    final runsNeeded = target - inn.totalRuns;
    final ballsRemaining =
        (rules.totalBalls - inn.legalBalls).clamp(0, rules.totalBalls);
    final crr = CricketMath.runRate(
      inn.totalRuns,
      inn.legalBalls,
      rules.ballsPerOver,
    );
    final rrr = runsNeeded > 0 && ballsRemaining > 0
        ? CricketMath.requiredRunRate(
            runsNeeded: runsNeeded,
            ballsRemaining: ballsRemaining,
            ballsPerOver: rules.ballsPerOver,
          )
        : 0.0;

    return InningsChaseDisplay(
      target: target,
      runsNeeded: runsNeeded,
      ballsRemaining: ballsRemaining,
      currentRunRate: crr,
      requiredRunRate: rrr,
    );
  }

  static double currentRunRate(InningsModel inn, MatchRulesModel rules) {
    return CricketMath.runRate(
      inn.totalRuns,
      inn.legalBalls,
      rules.ballsPerOver,
    );
  }

  static String oversLabel(InningsModel inn, MatchRulesModel rules) {
    final overs = CricketMath.formatOvers(inn.legalBalls, rules.ballsPerOver);
    return '($overs/${rules.totalOvers})';
  }

  /// Overs.balls for scoreboard header, e.g. `0.2` of `20` overs.
  static String inningsOversDisplay(InningsModel inn, MatchRulesModel rules) {
    return CricketMath.formatOvers(inn.legalBalls, rules.ballsPerOver);
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
      final add = e.runs - e.extraRuns;
      if (add <= 0) return 'Nb';
      if (e.noBallRunsMode == NoBallRunsMode.bye) return 'Nb B$add';
      if (e.noBallRunsMode == NoBallRunsMode.legBye) return 'Nb Lb$add';
      return 'Nb+${e.batsmanRuns}';
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
