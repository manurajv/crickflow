import 'package:equatable/equatable.dart';

import '../../../data/models/ball_event_model.dart';
import '../../../data/models/match_model.dart';
import 'tournament_player_stats_engine.dart';

enum TournamentHeroAward {
  playerOfTournament,
  bestBatter,
  bestBowler,
  bestAllRounder,
  bestFielder,
  emergingPlayer,
  mostValuablePlayer,
  orangeCap,
  purpleCap,
  bestCaptain,
  bestWicketKeeper,
}

extension TournamentHeroAwardX on TournamentHeroAward {
  String get title => switch (this) {
        TournamentHeroAward.playerOfTournament => 'Player of the Tournament',
        TournamentHeroAward.bestBatter => 'Best Batter',
        TournamentHeroAward.bestBowler => 'Best Bowler',
        TournamentHeroAward.bestAllRounder => 'Best All-Rounder',
        TournamentHeroAward.bestFielder => 'Best Fielder',
        TournamentHeroAward.emergingPlayer => 'Emerging Player',
        TournamentHeroAward.mostValuablePlayer => 'Most Valuable Player',
        TournamentHeroAward.orangeCap => 'Orange Cap',
        TournamentHeroAward.purpleCap => 'Purple Cap',
        TournamentHeroAward.bestCaptain => 'Best Captain',
        TournamentHeroAward.bestWicketKeeper => 'Best Wicket Keeper',
      };

  String get iconName => switch (this) {
        TournamentHeroAward.orangeCap => 'orange_cap',
        TournamentHeroAward.purpleCap => 'purple_cap',
        _ => 'emoji_events',
      };
}

class TournamentHeroEntry extends Equatable {
  const TournamentHeroEntry({
    required this.award,
    required this.playerId,
    required this.playerName,
    this.teamId = '',
    this.teamName = '',
    this.valueLabel = '',
    this.score = 0,
    this.photoUrl,
  });

  final TournamentHeroAward award;
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final String valueLabel;
  final double score;
  final String? photoUrl;

  @override
  List<Object?> get props => [award, playerId, score];
}

class TournamentHeroesSnapshot extends Equatable {
  const TournamentHeroesSnapshot({
    this.heroes = const [],
    this.hasData = false,
  });

  final List<TournamentHeroEntry> heroes;
  final bool hasData;

  TournamentHeroEntry? heroFor(TournamentHeroAward award) {
    for (final h in heroes) {
      if (h.award == award) return h;
    }
    return null;
  }

  @override
  List<Object?> get props => [heroes, hasData];
}

/// Computes tournament hero awards from aggregated player stats.
class TournamentHeroRankingEngine {
  TournamentHeroRankingEngine({
    TournamentPlayerStatsEngine? statsEngine,
  }) : _statsEngine = statsEngine ?? TournamentPlayerStatsEngine();

  final TournamentPlayerStatsEngine _statsEngine;

  TournamentHeroesSnapshot build({
    required List<MatchModel> matches,
    required Map<String, List<BallEventModel>> eventsByMatch,
    String? groupId,
    String? roundId,
    bool leagueStageOnly = false,
    bool knockoutStageOnly = false,
  }) {
    final agg = _statsEngine.aggregate(
      matches: matches,
      eventsByMatch: eventsByMatch,
      groupId: groupId,
      roundId: roundId,
      leagueStageOnly: leagueStageOnly,
      knockoutStageOnly: knockoutStageOnly,
    );
    final players = agg.players.values.toList();
    if (players.isEmpty) {
      return const TournamentHeroesSnapshot();
    }

    for (final p in players) {
      p.mvpPoints = _mvpScore(p);
    }

    final heroes = <TournamentHeroEntry>[];

    void addIfFound(
      TournamentHeroAward award,
      TournamentPlayerAccum? p,
      String valueLabel,
    ) {
      if (p == null || p.playerId.isEmpty) return;
      heroes.add(
        TournamentHeroEntry(
          award: award,
          playerId: p.playerId,
          playerName: p.playerName,
          teamId: p.teamId,
          teamName: p.teamName,
          valueLabel: valueLabel,
          score: p.mvpPoints,
          photoUrl: p.photoUrl,
        ),
      );
    }

    final byRuns = _top(players, (p) => p.runs);
    final byWickets = _top(players, (p) => p.wickets);
    final byMvp = _top(players, (p) => p.mvpPoints);
    final byFielding = _top(
      players,
      (p) => p.catches + p.runOuts + p.stumpings,
    );
    final emerging = _top(
      players.where((p) => p.matchesPlayed <= 3).toList(),
      (p) => p.mvpPoints,
    );
    final allRounder = _top(players, _allRounderScore);
    final keeper = _top(players, (p) => p.stumpings * 3 + p.catches);

    addIfFound(
      TournamentHeroAward.orangeCap,
      byRuns,
      byRuns != null ? '${byRuns.runs} runs' : '',
    );
    addIfFound(
      TournamentHeroAward.purpleCap,
      byWickets,
      byWickets != null ? '${byWickets.wickets} wkts' : '',
    );
    addIfFound(
      TournamentHeroAward.bestBatter,
      byRuns,
      byRuns != null ? 'SR ${byRuns.strikeRate.toStringAsFixed(1)}' : '',
    );
    addIfFound(
      TournamentHeroAward.bestBowler,
      byWickets,
      byWickets != null ? 'Econ ${byWickets.economy.toStringAsFixed(2)}' : '',
    );
    addIfFound(
      TournamentHeroAward.bestAllRounder,
      allRounder,
      allRounder != null
          ? '${allRounder.runs} & ${allRounder.wickets} wkts'
          : '',
    );
    addIfFound(
      TournamentHeroAward.bestFielder,
      byFielding,
      byFielding != null
          ? '${byFielding.catches + byFielding.runOuts + byFielding.stumpings} dismissals'
          : '',
    );
    addIfFound(
      TournamentHeroAward.emergingPlayer,
      emerging,
      emerging != null ? '${emerging.matchesPlayed} matches' : '',
    );
    addIfFound(
      TournamentHeroAward.mostValuablePlayer,
      byMvp,
      byMvp != null ? '${byMvp.mvpPoints.toStringAsFixed(1)} pts' : '',
    );
    addIfFound(
      TournamentHeroAward.playerOfTournament,
      byMvp,
      byMvp != null ? '${byMvp.mvpPoints.toStringAsFixed(1)} MVP pts' : '',
    );
    addIfFound(
      TournamentHeroAward.bestWicketKeeper,
      keeper,
      keeper != null ? '${keeper.stumpings} stumpings' : '',
    );

    return TournamentHeroesSnapshot(heroes: heroes, hasData: heroes.isNotEmpty);
  }

  double _mvpScore(TournamentPlayerAccum p) {
    final bat = p.runs * 1.0 + p.fours * 0.5 + p.sixes * 1.0;
    final bowl = p.wickets * 25.0 - p.runsConceded * 0.5 + p.maidens * 4.0;
    final field = (p.catches + p.runOuts + p.stumpings) * 8.0;
    final srBonus = p.balls >= 12 ? (p.strikeRate - 100) * 0.05 : 0;
    return bat + bowl + field + srBonus;
  }

  double _allRounderScore(TournamentPlayerAccum p) =>
      p.runs * 0.8 + p.wickets * 20.0;

  TournamentPlayerAccum? _top(
    List<TournamentPlayerAccum> list,
    num Function(TournamentPlayerAccum) metric,
  ) {
    if (list.isEmpty) return null;
    list.sort((a, b) => metric(b).compareTo(metric(a)));
    final best = list.first;
    if (metric(best) <= 0) return null;
    return best;
  }
}
