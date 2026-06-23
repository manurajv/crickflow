import '../../data/models/match_model.dart';
import '../../data/models/tournament_model.dart';

class TournamentStatisticsSnapshot {
  const TournamentStatisticsSnapshot({
    this.totalMatches = 0,
    this.completedMatches = 0,
    this.liveMatches = 0,
    this.totalRuns = 0,
    this.totalWickets = 0,
    this.totalSixes = 0,
    this.totalFours = 0,
    this.highestTeamScore = 0,
    this.topScorerName = '',
    this.topScorerRuns = 0,
  });

  final int totalMatches;
  final int completedMatches;
  final int liveMatches;
  final int totalRuns;
  final int totalWickets;
  final int totalSixes;
  final int totalFours;
  final int highestTeamScore;
  final String topScorerName;
  final int topScorerRuns;
}

/// Aggregates tournament-level stats from match documents.
class TournamentStatisticsService {
  const TournamentStatisticsService();

  TournamentStatisticsSnapshot compute({
    required TournamentModel tournament,
    required List<MatchModel> matches,
  }) {
    var completed = 0;
    var live = 0;
    var totalRuns = 0;
    var totalWickets = 0;
    var highestTeamScore = 0;

    for (final match in matches) {
      if (match.status.name == 'completed') completed++;
      if (match.status.name == 'live' || match.status.name == 'inningsBreak') {
        live++;
      }
      for (final inn in match.innings) {
        totalRuns += inn.totalRuns;
        totalWickets += inn.totalWickets;
        if (inn.totalRuns > highestTeamScore) {
          highestTeamScore = inn.totalRuns;
        }
      }
    }

    return TournamentStatisticsSnapshot(
      totalMatches: matches.length,
      completedMatches: completed,
      liveMatches: live,
      totalRuns: totalRuns,
      totalWickets: totalWickets,
      highestTeamScore: highestTeamScore,
    );
  }
}
