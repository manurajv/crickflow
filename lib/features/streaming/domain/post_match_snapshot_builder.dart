import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../data/models/innings_model.dart';
import '../../../data/models/match_model.dart';
import '../../../shared/providers/match_squads_provider.dart';
import '../data/models/post_match_snapshot.dart';

class PostMatchSnapshotBuilder {
  PostMatchSnapshotBuilder._();

  static PostMatchSnapshot build({
    required MatchModel match,
    required MatchDualSquads squads,
    String? tournamentName,
    String? tournamentLogoUrl,
    List<String> sponsorLogoUrls = const [],
  }) {
    final bpo = match.rules.ballsPerOver;
    final tossWinnerTeamId = _tossWinnerTeamId(match);
    final innings = match.innings
        .where(
          (inn) =>
              !inn.isSuperOver && inn.status == InningsStatus.completed,
        )
        .toList()
      ..sort((a, b) => a.inningsNumber.compareTo(b.inningsNumber));

    final teams = innings
        .map(
          (inn) => _teamSummary(
            innings: inn,
            match: match,
            squads: squads,
            bpo: bpo,
            wonToss: inn.battingTeamId == tossWinnerTeamId,
          ),
        )
        .toList();

    return PostMatchSnapshot(
      matchTitle: _matchTitle(match),
      matchTypeSubtitle: _matchTypeSubtitle(match),
      tournamentLogoUrl: tournamentLogoUrl,
      tournamentName: tournamentName ?? '',
      venue: match.venue.trim(),
      crickflowLogoUrl: AppConstants.crickflowLogoUrl,
      sponsorLogoUrls: sponsorLogoUrls,
      teams: teams,
      resultText: _resultText(match, squads),
    );
  }

  static PostMatchTeamSummary _teamSummary({
    required InningsModel innings,
    required MatchModel match,
    required MatchDualSquads squads,
    required int bpo,
    required bool wonToss,
  }) {
    final battingTeam = _teamSide(squads, innings.battingTeamId, match);
    final overs = CricketMath.formatOvers(innings.legalBalls, bpo);

    final batters = innings.batsmen
        .where((b) => b.balls > 0 || b.runs > 0)
        .toList()
      ..sort((a, b) => b.runs.compareTo(a.runs));

    final bowlers = innings.bowlers
        .where((b) => b.oversBowledBalls > 0)
        .toList()
      ..sort((a, b) {
        final w = b.wickets.compareTo(a.wickets);
        if (w != 0) return w;
        return a.runsConceded.compareTo(b.runsConceded);
      });

    return PostMatchTeamSummary(
      teamName: battingTeam.name,
      logoUrl: battingTeam.logoUrl,
      oversLabel: '$overs overs',
      score: '${innings.totalRuns}-${innings.totalWickets}',
      wonToss: wonToss,
      topBatters: batters.take(4).map((b) {
        return PostMatchBatterLine(
          name: b.playerName.isNotEmpty ? b.playerName : 'Batter',
          runs: b.runs,
          balls: b.balls,
          isNotOut: !b.isOut,
        );
      }).toList(),
      topBowlers: bowlers.take(4).map((b) {
        return PostMatchBowlerLine(
          name: b.playerName.isNotEmpty ? b.playerName : 'Bowler',
          wickets: b.wickets,
          runs: b.runsConceded,
          overs: CricketMath.formatOvers(b.oversBowledBalls, bpo),
        );
      }).toList(),
    );
  }

  static String? _tossWinnerTeamId(MatchModel match) {
    final setup = match.setup;
    if (setup?.tossWinnerIsTeamA == null) return null;
    return setup!.tossWinnerIsTeamA! ? match.teamAId : match.teamBId;
  }

  static String _matchTitle(MatchModel match) {
    if (match.teamAName.isNotEmpty && match.teamBName.isNotEmpty) {
      return '${match.teamAName} vs ${match.teamBName}';
    }
    return match.title;
  }

  static String _matchTypeSubtitle(MatchModel match) {
    final overs = match.rules.totalOvers;
    final ballType =
        (match.rules.ballType ?? CricketBallType.leather).name.toUpperCase();
    return '$overs OVERS · $ballType';
  }

  static String _resultText(MatchModel match, MatchDualSquads squads) {
    final summary = match.resultSummary.trim();
    if (summary.isNotEmpty) return summary.toUpperCase();

    final winnerId = match.winnerTeamId;
    if (winnerId == null || winnerId.isEmpty) return 'MATCH COMPLETE';

    final winnerName = winnerId == match.teamAId
        ? (squads.teamA.teamName.isNotEmpty
            ? squads.teamA.teamName
            : match.teamAName)
        : (squads.teamB.teamName.isNotEmpty
            ? squads.teamB.teamName
            : match.teamBName);

    return '${winnerName.toUpperCase()} WON';
  }

  static ({String name, String? logoUrl}) _teamSide(
    MatchDualSquads squads,
    String teamId,
    MatchModel match,
  ) {
    if (match.teamAId == teamId) {
      return (
        name: squads.teamA.teamName.isNotEmpty
            ? squads.teamA.teamName
            : match.teamAName,
        logoUrl: squads.teamA.teamLogoUrl,
      );
    }
    return (
      name: squads.teamB.teamName.isNotEmpty
          ? squads.teamB.teamName
          : match.teamBName,
      logoUrl: squads.teamB.teamLogoUrl,
    );
  }
}
