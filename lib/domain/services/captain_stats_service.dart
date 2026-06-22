import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import 'player_cricket_profile_models.dart';

class CaptainStatsService {
  const CaptainStatsService();

  CaptainStatsSnapshot compute({
    required String playerId,
    required List<MatchModel> completedMatches,
  }) {
    var matchesAsCaptain = 0;
    var wins = 0;
    var losses = 0;
    var ties = 0;
    var tossesWon = 0;
    var tossesTotal = 0;
    var highestTeamScore = 0;
    var lowestDefended = 999999;
    var hasDefended = false;
    var successfulChases = 0;
    var chaseAttempts = 0;
    var totalTeamScore = 0;
    var totalConceded = 0;
    var scoreSamples = 0;
    var concededSamples = 0;

    final yearMap = <int, CaptainYearStats>{};
    final formatMap = <String, CaptainFormatStats>{};
    final timeline = <CaptainTimelinePoint>[];

    for (final match in completedMatches) {
      final setup = match.setup;
      if (setup == null) continue;

      final isTeamACaptain = setup.teamACaptainId == playerId;
      final isTeamBCaptain = setup.teamBCaptainId == playerId;
      if (!isTeamACaptain && !isTeamBCaptain) continue;

      final captainTeamId = isTeamACaptain ? match.teamAId : match.teamBId;
      if (captainTeamId == null) continue;

      matchesAsCaptain += 1;
      final date = match.completedAt ?? match.scheduledAt ?? DateTime.now();
      final year = date.year;

      final yearStats = yearMap.putIfAbsent(
        year,
        () => CaptainYearStats(year: year),
      );
      yearMap[year] = CaptainYearStats(
        year: year,
        matches: yearStats.matches + 1,
        wins: yearStats.wins,
        losses: yearStats.losses,
      );

      final formatLabel = _formatLabel(match);
      final fmtStats = formatMap.putIfAbsent(
        formatLabel,
        () => CaptainFormatStats(label: formatLabel),
      );

      var won = false;
      var lost = false;
      if (match.winnerTeamId == captainTeamId) {
        wins += 1;
        won = true;
      } else if (match.winnerTeamId != null) {
        losses += 1;
        lost = true;
      } else {
        ties += 1;
      }

      yearMap[year] = CaptainYearStats(
        year: year,
        matches: yearMap[year]!.matches,
        wins: yearMap[year]!.wins + (won ? 1 : 0),
        losses: yearMap[year]!.losses + (lost ? 1 : 0),
      );

      formatMap[formatLabel] = CaptainFormatStats(
        label: formatLabel,
        matches: fmtStats.matches + 1,
        wins: fmtStats.wins + (won ? 1 : 0),
        losses: fmtStats.losses + (lost ? 1 : 0),
      );

      if (setup.tossWinnerIsTeamA != null) {
        tossesTotal += 1;
        final captainWonToss =
            (isTeamACaptain && setup.tossWinnerIsTeamA!) ||
                (isTeamBCaptain && !setup.tossWinnerIsTeamA!);
        if (captainWonToss) tossesWon += 1;
      }

      final teamInnings = match.innings.where((inn) {
        return inn.battingTeamId == captainTeamId;
      }).toList();

      final oppInnings = match.innings.where((inn) {
        return inn.battingTeamId.isNotEmpty &&
            inn.battingTeamId != captainTeamId;
      }).toList();

      for (final inn in teamInnings) {
        final score = inn.totalRuns;
        if (score > highestTeamScore) highestTeamScore = score;
        totalTeamScore += score;
        scoreSamples += 1;
      }

      for (final inn in oppInnings) {
        totalConceded += inn.totalRuns;
        concededSamples += 1;
      }

      final isChase = teamInnings.length == 2 ||
          (teamInnings.isNotEmpty &&
              setup.tossWinnerBatsFirst != null &&
              !((isTeamACaptain && setup.tossWinnerIsTeamA == true &&
                      setup.tossWinnerBatsFirst == true) ||
                  (isTeamBCaptain && setup.tossWinnerIsTeamA == false &&
                      setup.tossWinnerBatsFirst == true)));

      if (teamInnings.length >= 2 || isChase) {
        chaseAttempts += 1;
        if (won) successfulChases += 1;
      }

      if (oppInnings.isNotEmpty && teamInnings.isNotEmpty && won) {
        final defended = teamInnings.first.totalRuns;
        final chased = oppInnings.first.totalRuns;
        if (defended > 0 && chased < defended) {
          hasDefended = true;
          if (defended < lowestDefended) lowestDefended = defended;
        }
      }

      timeline.add(
        CaptainTimelinePoint(
          date: date,
          result: won ? 'W' : (lost ? 'L' : 'T'),
          matchTitle: match.title,
          teamScore: teamInnings.isNotEmpty ? teamInnings.last.totalRuns : 0,
          opponentScore:
              oppInnings.isNotEmpty ? oppInnings.last.totalRuns : 0,
        ),
      );
    }

    timeline.sort((a, b) => a.date.compareTo(b.date));

    return CaptainStatsSnapshot(
      matchesAsCaptain: matchesAsCaptain,
      wins: wins,
      losses: losses,
      ties: ties,
      tossesWon: tossesWon,
      tossesTotal: tossesTotal,
      highestTeamScore: highestTeamScore,
      lowestDefendedScore: hasDefended ? lowestDefended : 0,
      successfulChases: successfulChases,
      chaseAttempts: chaseAttempts,
      avgTeamScore:
          scoreSamples == 0 ? 0 : totalTeamScore / scoreSamples,
      avgConcededScore:
          concededSamples == 0 ? 0 : totalConceded / concededSamples,
      byYear: yearMap.values.toList()..sort((a, b) => a.year.compareTo(b.year)),
      byFormat: formatMap.values.toList()
        ..sort((a, b) => b.matches.compareTo(a.matches)),
      timeline: timeline,
    );
  }

  String _formatLabel(MatchModel match) {
    if (match.rules.cricketMatchType == CricketMatchType.testMatch) {
      return 'Test';
    }
    final overs = match.rules.totalOvers;
    if (overs <= 12) return 'T10';
    if (overs <= 20) return 'T20';
    if (overs <= 30) return '${overs} Over';
    if (overs <= 50) return 'ODI';
    return '${overs} Over';
  }
}
