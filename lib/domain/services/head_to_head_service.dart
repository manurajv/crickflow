import 'package:intl/intl.dart';

import '../../core/utils/match_score_display.dart';
import '../../data/models/match_model.dart';
import 'match_summary_models.dart';
import 'match_upcoming_models.dart';

/// Historical head-to-head stats between two teams.
class HeadToHeadService {
  HeadToHeadSnapshot build({
    required MatchModel upcoming,
    required List<MatchModel> history,
  }) {
    final teamAId = upcoming.teamAId;
    final teamBId = upcoming.teamBId;
    if (teamAId == null ||
        teamBId == null ||
        teamAId.isEmpty ||
        teamBId.isEmpty ||
        history.isEmpty) {
      return HeadToHeadSnapshot.empty;
    }

    var teamAWins = 0;
    var teamBWins = 0;
    var teamAWonBatFirst = 0;
    var teamBWonBatFirst = 0;
    var teamAWonBowlFirst = 0;
    var teamBWonBowlFirst = 0;
    final teamAScores = <int>[];
    final teamBScores = <int>[];
    final recent = <HeadToHeadRecentMatch>[];

    for (final match in history) {
      final winnerId = match.winnerTeamId;
      if (winnerId == teamAId) {
        teamAWins++;
      } else if (winnerId == teamBId) {
        teamBWins++;
      }

      final firstInn =
          match.innings.isNotEmpty ? match.innings.first : null;
      if (firstInn != null && winnerId != null && winnerId.isNotEmpty) {
        final battedFirst = firstInn.battingTeamId;
        if (winnerId == battedFirst) {
          if (battedFirst == teamAId) {
            teamAWonBatFirst++;
          } else if (battedFirst == teamBId) {
            teamBWonBatFirst++;
          }
        } else {
          if (winnerId == teamAId) {
            teamAWonBowlFirst++;
          } else if (winnerId == teamBId) {
            teamBWonBowlFirst++;
          }
        }
      }

      for (final inn in match.innings) {
        if (inn.battingTeamId == teamAId) {
          teamAScores.add(inn.totalRuns);
        } else if (inn.battingTeamId == teamBId) {
          teamBScores.add(inn.totalRuns);
        }
      }

      if (recent.length < 5) {
        final winner = winnerId == teamAId
            ? upcoming.teamAName
            : winnerId == teamBId
                ? upcoming.teamBName
                : 'Draw / N/R';
        recent.add(
          HeadToHeadRecentMatch(
            dateLabel: _dateLabel(match),
            summary: MatchScoreDisplay.completedResultLine(match) ??
                match.resultSummary,
            winnerName: winner,
          ),
        );
      }
    }

    double avg(List<int> scores) =>
        scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length;

    int highest(List<int> scores) =>
        scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);

    int lowest(List<int> scores) =>
        scores.isEmpty ? 0 : scores.reduce((a, b) => a < b ? a : b);

    final played = history.length;
    final teamAWinPct = played > 0 ? teamAWins / played * 100.0 : 0.0;
    final teamBWinPct = played > 0 ? teamBWins / played * 100.0 : 0.0;

    final comparison = TeamComparisonSummary(
      teamAName: upcoming.teamAName,
      teamBName: upcoming.teamBName,
      metrics: [
        TeamComparisonMetric(
          label: 'Matches played',
          teamAValue: '$played',
          teamBValue: '$played',
        ),
        TeamComparisonMetric(
          label: 'Wins',
          teamAValue: '$teamAWins',
          teamBValue: '$teamBWins',
          teamANumeric: teamAWins.toDouble(),
          teamBNumeric: teamBWins.toDouble(),
        ),
        TeamComparisonMetric(
          label: 'Won batting first',
          teamAValue: '$teamAWonBatFirst',
          teamBValue: '$teamBWonBatFirst',
          teamANumeric: teamAWonBatFirst.toDouble(),
          teamBNumeric: teamBWonBatFirst.toDouble(),
        ),
        TeamComparisonMetric(
          label: 'Won bowling first',
          teamAValue: '$teamAWonBowlFirst',
          teamBValue: '$teamBWonBowlFirst',
          teamANumeric: teamAWonBowlFirst.toDouble(),
          teamBNumeric: teamBWonBowlFirst.toDouble(),
        ),
        TeamComparisonMetric(
          label: 'Average score',
          teamAValue: teamAScores.isEmpty
              ? '—'
              : avg(teamAScores).toStringAsFixed(0),
          teamBValue: teamBScores.isEmpty
              ? '—'
              : avg(teamBScores).toStringAsFixed(0),
          teamANumeric: avg(teamAScores),
          teamBNumeric: avg(teamBScores),
        ),
        TeamComparisonMetric(
          label: 'Highest score',
          teamAValue: '${highest(teamAScores)}',
          teamBValue: '${highest(teamBScores)}',
          teamANumeric: highest(teamAScores).toDouble(),
          teamBNumeric: highest(teamBScores).toDouble(),
        ),
        TeamComparisonMetric(
          label: 'Lowest score',
          teamAValue: teamAScores.isEmpty ? '—' : '${lowest(teamAScores)}',
          teamBValue: teamBScores.isEmpty ? '—' : '${lowest(teamBScores)}',
        ),
        TeamComparisonMetric(
          label: 'Win %',
          teamAValue: '${teamAWinPct.toStringAsFixed(0)}%',
          teamBValue: '${teamBWinPct.toStringAsFixed(0)}%',
          teamANumeric: teamAWinPct,
          teamBNumeric: teamBWinPct,
        ),
      ],
    );

    return HeadToHeadSnapshot(
      hasHistory: true,
      matchesPlayed: played,
      teamAWins: teamAWins,
      teamBWins: teamBWins,
      teamAWonBatFirst: teamAWonBatFirst,
      teamBWonBatFirst: teamBWonBatFirst,
      teamAWonBowlFirst: teamAWonBowlFirst,
      teamBWonBowlFirst: teamBWonBowlFirst,
      teamAAvgScore: avg(teamAScores),
      teamBAvgScore: avg(teamBScores),
      teamAHighest: highest(teamAScores),
      teamBHighest: highest(teamBScores),
      teamALowest: lowest(teamAScores),
      teamBLowest: lowest(teamBScores),
      teamAWinPct: teamAWinPct,
      teamBWinPct: teamBWinPct,
      recentMatches: recent,
      comparison: comparison,
    );
  }

  static String _dateLabel(MatchModel match) {
    final dt = match.completedAt ?? match.startedAt ?? match.scheduledAt;
    if (dt == null) return '';
    return DateFormat('d MMM yyyy').format(dt);
  }
}
