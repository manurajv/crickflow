import 'package:equatable/equatable.dart';

/// Scope filter for tournament leaderboard / stats.
enum TournamentStatsScope {
  tournament,
  round,
  group,
}

/// A single leaderboard row.
class TournamentLeaderboardEntry extends Equatable {
  const TournamentLeaderboardEntry({
    required this.rank,
    required this.label,
    this.subtitle = '',
    this.playerId,
    this.teamId,
    this.teamName = '',
    this.value = 0,
    this.valueLabel = '',
    this.secondaryValue,
    this.photoUrl,
  });

  final int rank;
  final String label;
  final String subtitle;
  final String? playerId;
  final String? teamId;
  final String teamName;
  final num value;
  final String valueLabel;
  final String? secondaryValue;
  final String? photoUrl;

  @override
  List<Object?> get props => [rank, label, playerId, teamId, value];
}

enum TournamentLeaderboardCategory {
  mostRuns,
  highestScore,
  mostFours,
  mostSixes,
  bestStrikeRate,
  mostFifties,
  mostHundreds,
  mostWickets,
  bestBowlingFigures,
  bestEconomy,
  bestBowlingStrikeRate,
  mostMaidens,
  mostCatches,
  mostRunOuts,
  mostStumpings,
  highestTeamScore,
  lowestDefendedTotal,
  biggestWin,
  closestWin,
}

extension TournamentLeaderboardCategoryX on TournamentLeaderboardCategory {
  String get title => switch (this) {
        TournamentLeaderboardCategory.mostRuns => 'Most Runs',
        TournamentLeaderboardCategory.highestScore => 'Highest Score',
        TournamentLeaderboardCategory.mostFours => 'Most Fours',
        TournamentLeaderboardCategory.mostSixes => 'Most Sixes',
        TournamentLeaderboardCategory.bestStrikeRate => 'Best Strike Rate',
        TournamentLeaderboardCategory.mostFifties => 'Most Fifties',
        TournamentLeaderboardCategory.mostHundreds => 'Most Hundreds',
        TournamentLeaderboardCategory.mostWickets => 'Most Wickets',
        TournamentLeaderboardCategory.bestBowlingFigures => 'Best Bowling',
        TournamentLeaderboardCategory.bestEconomy => 'Best Economy',
        TournamentLeaderboardCategory.bestBowlingStrikeRate =>
          'Best Bowling Strike Rate',
        TournamentLeaderboardCategory.mostMaidens => 'Most Maidens',
        TournamentLeaderboardCategory.mostCatches => 'Most Catches',
        TournamentLeaderboardCategory.mostRunOuts => 'Most Run Outs',
        TournamentLeaderboardCategory.mostStumpings => 'Most Stumpings',
        TournamentLeaderboardCategory.highestTeamScore => 'Highest Team Score',
        TournamentLeaderboardCategory.lowestDefendedTotal =>
          'Lowest Defended Total',
        TournamentLeaderboardCategory.biggestWin => 'Biggest Win',
        TournamentLeaderboardCategory.closestWin => 'Closest Win',
      };
}

const kTournamentBattingCategories = [
  TournamentLeaderboardCategory.mostRuns,
  TournamentLeaderboardCategory.highestScore,
  TournamentLeaderboardCategory.mostFours,
  TournamentLeaderboardCategory.mostSixes,
  TournamentLeaderboardCategory.bestStrikeRate,
  TournamentLeaderboardCategory.mostFifties,
  TournamentLeaderboardCategory.mostHundreds,
];

const kTournamentBowlingCategories = [
  TournamentLeaderboardCategory.mostWickets,
  TournamentLeaderboardCategory.bestBowlingFigures,
  TournamentLeaderboardCategory.bestEconomy,
  TournamentLeaderboardCategory.bestBowlingStrikeRate,
  TournamentLeaderboardCategory.mostMaidens,
];

const kTournamentFieldingCategories = [
  TournamentLeaderboardCategory.mostCatches,
  TournamentLeaderboardCategory.mostRunOuts,
  TournamentLeaderboardCategory.mostStumpings,
];

const kTournamentTeamCategories = [
  TournamentLeaderboardCategory.highestTeamScore,
  TournamentLeaderboardCategory.lowestDefendedTotal,
  TournamentLeaderboardCategory.biggestWin,
  TournamentLeaderboardCategory.closestWin,
];

class TournamentLeaderboardSnapshot extends Equatable {
  const TournamentLeaderboardSnapshot({
    this.scope = TournamentStatsScope.tournament,
    this.scopeLabel = 'Tournament',
    this.byCategory = const {},
    this.hasData = false,
  });

  final TournamentStatsScope scope;
  final String scopeLabel;
  final Map<TournamentLeaderboardCategory, List<TournamentLeaderboardEntry>>
      byCategory;
  final bool hasData;

  List<TournamentLeaderboardEntry> entriesFor(
    TournamentLeaderboardCategory category,
  ) =>
      byCategory[category] ?? const [];

  @override
  List<Object?> get props => [scope, scopeLabel, hasData, byCategory.length];
}
