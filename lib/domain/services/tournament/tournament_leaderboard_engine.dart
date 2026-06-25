import '../../../data/models/ball_event_model.dart';
import '../../../data/models/match_model.dart';
import 'tournament_leaderboard_models.dart';
import 'tournament_player_stats_engine.dart';

/// Builds ranked leaderboard categories from tournament match data.
class TournamentLeaderboardEngine {
  TournamentLeaderboardEngine({
    TournamentPlayerStatsEngine? statsEngine,
  }) : _statsEngine = statsEngine ?? TournamentPlayerStatsEngine();

  final TournamentPlayerStatsEngine _statsEngine;

  TournamentLeaderboardSnapshot build({
    required List<MatchModel> matches,
    required Map<String, List<BallEventModel>> eventsByMatch,
    TournamentStatsScope scope = TournamentStatsScope.tournament,
    String scopeLabel = 'Tournament',
    String? groupId,
    String? roundId,
    int limit = 10,
  }) {
    final agg = _statsEngine.aggregate(
      matches: matches,
      eventsByMatch: eventsByMatch,
      groupId: groupId,
      roundId: roundId,
    );

    final byCategory = <TournamentLeaderboardCategory,
        List<TournamentLeaderboardEntry>>{};

    void addCategory(
      TournamentLeaderboardCategory cat,
      List<TournamentLeaderboardEntry> rows,
    ) {
      if (rows.isNotEmpty) {
        byCategory[cat] = rows.take(limit).toList();
      }
    }

    final players = agg.players.values.toList();

    addCategory(
      TournamentLeaderboardCategory.mostRuns,
      _rankPlayers(
        players,
        (p) => p.runs,
        (p) => '${p.runs}',
        (p) => p.teamName,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.highestScore,
      _rankPlayers(
        players,
        (p) => p.highScore,
        (p) => '${p.highScore}',
        (p) => p.teamName,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.mostFours,
      _rankPlayers(
        players,
        (p) => p.fours,
        (p) => '${p.fours}',
        (p) => p.teamName,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.mostSixes,
      _rankPlayers(
        players,
        (p) => p.sixes,
        (p) => '${p.sixes}',
        (p) => p.teamName,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.bestStrikeRate,
      _rankPlayers(
        players.where((p) => p.balls >= 12).toList(),
        (p) => p.strikeRate,
        (p) => p.strikeRate.toStringAsFixed(1),
        (p) => '${p.runs} (${p.balls}b)',
        descending: true,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.mostFifties,
      _rankPlayers(
        players,
        (p) => p.fifties,
        (p) => '${p.fifties}',
        (p) => p.teamName,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.mostHundreds,
      _rankPlayers(
        players,
        (p) => p.hundreds,
        (p) => '${p.hundreds}',
        (p) => p.teamName,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.mostWickets,
      _rankPlayers(
        players,
        (p) => p.wickets,
        (p) => '${p.wickets}',
        (p) => p.teamName,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.bestBowlingFigures,
      _rankPlayers(
        players.where((p) => p.bestWickets > 0).toList(),
        (p) => p.bestWickets * 1000 - p.bestRunsConceded,
        (p) => '${p.bestWickets}/${p.bestRunsConceded}',
        (p) => p.teamName,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.bestEconomy,
      _rankPlayers(
        players.where((p) => p.legalBallsBowled >= 12).toList(),
        (p) => -p.economy,
        (p) => p.economy.toStringAsFixed(2),
        (p) => '${p.wickets} wkts',
        descending: true,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.bestBowlingStrikeRate,
      _rankPlayers(
        players.where((p) => p.wickets >= 2).toList(),
        (p) => -p.bowlingStrikeRate,
        (p) => p.bowlingStrikeRate == double.infinity
            ? '—'
            : p.bowlingStrikeRate.toStringAsFixed(1),
        (p) => '${p.wickets} wkts',
        descending: true,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.mostMaidens,
      _rankPlayers(
        players,
        (p) => p.maidens,
        (p) => '${p.maidens}',
        (p) => p.teamName,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.mostCatches,
      _rankPlayers(
        players,
        (p) => p.catches,
        (p) => '${p.catches}',
        (p) => p.teamName,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.mostRunOuts,
      _rankPlayers(
        players,
        (p) => p.runOuts,
        (p) => '${p.runOuts}',
        (p) => p.teamName,
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.mostStumpings,
      _rankPlayers(
        players,
        (p) => p.stumpings,
        (p) => '${p.stumpings}',
        (p) => p.teamName,
      ),
    );

    final teams = agg.teams.values.toList();
    addCategory(
      TournamentLeaderboardCategory.highestTeamScore,
      _rankTeams(
        teams,
        (t) => t.highestScore,
        (t) => '${t.highestScore}',
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.lowestDefendedTotal,
      _rankTeams(
        teams.where((t) => t.lowestDefended < 999999).toList(),
        (t) => -t.lowestDefended,
        (t) => '${t.lowestDefended}',
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.biggestWin,
      _rankTeams(
        teams.where((t) => t.biggestWinMargin > 0).toList(),
        (t) => t.biggestWinMargin,
        (t) => 'by ${t.biggestWinMargin}',
      ),
    );
    addCategory(
      TournamentLeaderboardCategory.closestWin,
      _rankTeams(
        teams.where((t) => t.closestWinMargin < 999999 && t.wins > 0).toList(),
        (t) => -t.closestWinMargin,
        (t) => 'by ${t.closestWinMargin}',
      ),
    );

    return TournamentLeaderboardSnapshot(
      scope: scope,
      scopeLabel: scopeLabel,
      byCategory: byCategory,
      hasData: byCategory.isNotEmpty,
    );
  }

  List<TournamentLeaderboardEntry> _rankPlayers(
    List<TournamentPlayerAccum> players,
    num Function(TournamentPlayerAccum) metric,
    String Function(TournamentPlayerAccum) valueLabel,
    String Function(TournamentPlayerAccum) subtitle, {
    bool descending = true,
  }) {
    final sorted = [...players]
      ..sort((a, b) {
        final cmp = metric(b).compareTo(metric(a));
        return descending ? cmp : -cmp;
      });
    return [
      for (var i = 0; i < sorted.length; i++)
        if (metric(sorted[i]) > 0)
          TournamentLeaderboardEntry(
            rank: i + 1,
            label: sorted[i].playerName.isNotEmpty
                ? sorted[i].playerName
                : 'Player',
            subtitle: subtitle(sorted[i]),
            playerId: sorted[i].playerId,
            teamId: sorted[i].teamId,
            teamName: sorted[i].teamName,
            value: metric(sorted[i]),
            valueLabel: valueLabel(sorted[i]),
            photoUrl: sorted[i].photoUrl,
          ),
    ];
  }

  List<TournamentLeaderboardEntry> _rankTeams(
    List<TournamentTeamAccum> teams,
    num Function(TournamentTeamAccum) metric,
    String Function(TournamentTeamAccum) valueLabel,
  ) {
    final sorted = [...teams]..sort((a, b) => metric(b).compareTo(metric(a)));
    return [
      for (var i = 0; i < sorted.length; i++)
        if (metric(sorted[i]) != 0)
          TournamentLeaderboardEntry(
            rank: i + 1,
            label: sorted[i].teamName.isNotEmpty
                ? sorted[i].teamName
                : 'Team',
            teamId: sorted[i].teamId,
            teamName: sorted[i].teamName,
            value: metric(sorted[i]),
            valueLabel: valueLabel(sorted[i]),
          ),
    ];
  }
}
