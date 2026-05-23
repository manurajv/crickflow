import '../constants/enums.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_rules_model.dart';
import '../../domain/scoring/match_completion_policy.dart';
import 'cricket_math.dart';

/// First innings totals shown during the break / chase.
class FirstInningsSummary {
  const FirstInningsSummary({
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.runRate,
    required this.target,
    required this.battingTeamName,
  });

  final int runs;
  final int wickets;
  final String overs;
  final double runRate;
  final int target;
  final String battingTeamName;
}

/// Shared score / target / RR labels for cards and tabs.
class MatchScoreDisplay {
  MatchScoreDisplay._();

  static InningsModel? firstInnings(MatchModel match) {
    for (final inn in match.innings) {
      if (inn.inningsNumber == 1) return inn;
    }
    return match.innings.isNotEmpty ? match.innings.first : null;
  }

  static InningsModel? inningsByNumber(MatchModel match, int number) {
    for (final inn in match.innings) {
      if (inn.inningsNumber == number) return inn;
    }
    return null;
  }

  static String teamName(MatchModel match, String? teamId) {
    if (teamId == null || teamId.isEmpty) return '';
    if (teamId == match.teamAId) return match.teamAName;
    if (teamId == match.teamBId) return match.teamBName;
    return '';
  }

  static String battingTeamName(MatchModel match, InningsModel inn) =>
      teamName(match, inn.battingTeamId);

  static String bowlingTeamName(MatchModel match, InningsModel inn) =>
      teamName(match, inn.bowlingTeamId);

  /// Score string for a team from whichever innings they batted (latest).
  static String? scoreForTeam(MatchModel match, String? teamId) {
    final inn = inningsBattingTeam(match, teamId);
    if (inn == null) return null;
    return '${inn.totalRuns}/${inn.totalWickets}';
  }

  static InningsModel? inningsBattingTeam(MatchModel match, String? teamId) {
    if (teamId == null) return null;
    InningsModel? latest;
    for (final inn in match.innings) {
      if (inn.battingTeamId == teamId) latest = inn;
    }
    return latest;
  }

  static bool isTeamBattingNow(MatchModel match, String? teamId) {
    final cur = match.currentInnings;
    if (cur == null || cur.status != InningsStatus.inProgress) return false;
    return cur.battingTeamId == teamId;
  }

  static bool isTeamWinner(MatchModel match, String? teamId) {
    if (match.status != MatchStatus.completed || teamId == null) return false;
    final winnerId =
        match.winnerTeamId ?? MatchCompletionPolicy.compute(match).winnerTeamId;
    return winnerId == teamId;
  }

  /// e.g. "Team A won by 12 runs" — for completed match cards.
  static String? completedResultLine(MatchModel match) {
    if (match.status != MatchStatus.completed) return null;
    return MatchCompletionPolicy.compute(match).summary;
  }

  static bool isFirstInningsComplete(MatchModel match) {
    final first = firstInnings(match);
    return first?.status == InningsStatus.completed;
  }

  static FirstInningsSummary? completedFirstInnings(MatchModel match) {
    final first = firstInnings(match);
    if (first == null || first.status != InningsStatus.completed) return null;
    final rules = match.rules;
    return FirstInningsSummary(
      runs: first.totalRuns,
      wickets: first.totalWickets,
      overs: CricketMath.formatOvers(first.legalBalls, rules.ballsPerOver),
      runRate: CricketMath.runRate(
        first.totalRuns,
        first.legalBalls,
        rules.ballsPerOver,
      ),
      target: first.totalRuns + 1,
      battingTeamName: battingTeamName(match, first),
    );
  }

  static double runRateFor(InningsModel inn, MatchRulesModel rules) =>
      CricketMath.runRate(inn.totalRuns, inn.legalBalls, rules.ballsPerOver);

  /// Chase line for 2nd innings in progress, e.g. "Need 42 off 54 balls · RRR 4.67".
  static String? chaseLine(MatchModel match) {
    final cur = match.currentInnings;
    final first = completedFirstInnings(match);
    if (cur == null ||
        first == null ||
        cur.inningsNumber < 2 ||
        cur.status != InningsStatus.inProgress) {
      return null;
    }
    final rules = match.rules;
    final target = first.target;
    final runsNeeded = (target - cur.totalRuns).clamp(0, 9999);
    final ballsRemaining =
        (rules.totalBalls - cur.legalBalls).clamp(0, rules.totalBalls);
    if (runsNeeded <= 0) return 'Target reached';
    if (ballsRemaining <= 0) return 'Need $runsNeeded runs';
    final rrr = CricketMath.requiredRunRate(
      runsNeeded: runsNeeded,
      ballsRemaining: ballsRemaining,
      ballsPerOver: rules.ballsPerOver,
    );
    return 'Need $runsNeeded off $ballsRemaining balls · RRR ${rrr.toStringAsFixed(2)}';
  }

  /// Compact line for list cards during break or chase.
  static String? liveScoreSubtitle(MatchModel match) {
    final first = completedFirstInnings(match);
    final cur = match.currentInnings;
    if (first == null) {
      if (cur == null) return null;
      return '${battingTeamName(match, cur)} ${cur.totalRuns}/${cur.totalWickets}';
    }

    final parts = <String>[
      '1st inn ${first.runs}/${first.wickets}',
      'RR ${first.runRate.toStringAsFixed(2)}',
      'Target ${first.target}',
    ];

    if (cur != null &&
        cur.status == InningsStatus.inProgress &&
        cur.inningsNumber >= 2) {
      parts.add(
        '${battingTeamName(match, cur)} ${cur.totalRuns}/${cur.totalWickets}',
      );
      final chase = chaseLine(match);
      if (chase != null) parts.add(chase);
    }

    return parts.join(' · ');
  }
}
