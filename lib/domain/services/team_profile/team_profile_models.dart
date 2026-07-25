import 'package:equatable/equatable.dart';

import '../../../data/models/match_model.dart';
import '../../../data/models/player_model.dart';
import '../../../data/models/team_model.dart';

/// Aggregated career / form stats for a team's profile hub.
class TeamProfileStats extends Equatable {
  const TeamProfileStats({
    this.matches = 0,
    this.wins = 0,
    this.losses = 0,
    this.ties = 0,
    this.winPct = 0,
    this.currentStreak = 0,
    this.longestWinStreak = 0,
    this.averageScore = 0,
    this.highestScore = 0,
    this.lowestScore = 0,
    this.hasInningsScores = false,
    this.highestSuccessfulChase = 0,
    this.lowestSuccessfulDefence = 0,
    this.averageRuns = 0,
    this.averageWickets = 0,
    this.boundaries = 0,
    this.sixes = 0,
    this.runRate = 0,
    this.averagePartnership = 0,
    this.homeWins = 0,
    this.awayWins = 0,
    this.tournamentWins = 0,
  });

  final int matches;
  final int wins;
  final int losses;
  final int ties;
  final double winPct;
  /// Positive = win streak, negative = loss streak, 0 = none / mixed.
  final int currentStreak;
  final int longestWinStreak;
  final double averageScore;
  final int highestScore;
  final int lowestScore;
  /// True when at least one completed batting innings was used for score stats.
  final bool hasInningsScores;
  final int highestSuccessfulChase;
  final int lowestSuccessfulDefence;
  final double averageRuns;
  final double averageWickets;
  final int boundaries;
  final int sixes;
  final double runRate;
  final double averagePartnership;
  final int homeWins;
  final int awayWins;
  final int tournamentWins;

  @override
  List<Object?> get props => [matches, wins, losses, winPct, currentStreak];
}

enum TeamLeaderboardCategory {
  // Batting
  mostRuns,
  highestScore,
  highestAverage,
  bestStrikeRate,
  mostFifties,
  mostHundreds,
  mostSixes,
  mostFours,
  mostBallsFaced,
  mostNotOuts,
  fastestFifty,
  fastestHundred,
  // Bowling
  mostWickets,
  bestBowlingFigures,
  bestEconomy,
  bestBowlingStrikeRate,
  mostMaidens,
  mostDotBalls,
  mostOversBowled,
  mostFiveWicketHauls,
  lowestAverage,
  // Fielding
  mostCatches,
  mostRunOuts,
  mostStumpings,
  mostDirectHits,
  mostFieldingPoints,
  // Partnerships
  highestPartnership,
  mostCenturyPartnerships,
  mostFiftyPartnerships,
  highestOpeningPartnership,
  highestMiddleOrderPartnership,
  highestLastWicketPartnership,
}

enum TeamLeaderboardSection { batting, bowling, fielding, partnerships }

extension TeamLeaderboardCategoryX on TeamLeaderboardCategory {
  TeamLeaderboardSection get section => switch (this) {
        TeamLeaderboardCategory.mostRuns ||
        TeamLeaderboardCategory.highestScore ||
        TeamLeaderboardCategory.highestAverage ||
        TeamLeaderboardCategory.bestStrikeRate ||
        TeamLeaderboardCategory.mostFifties ||
        TeamLeaderboardCategory.mostHundreds ||
        TeamLeaderboardCategory.mostSixes ||
        TeamLeaderboardCategory.mostFours ||
        TeamLeaderboardCategory.mostBallsFaced ||
        TeamLeaderboardCategory.mostNotOuts ||
        TeamLeaderboardCategory.fastestFifty ||
        TeamLeaderboardCategory.fastestHundred =>
          TeamLeaderboardSection.batting,
        TeamLeaderboardCategory.mostWickets ||
        TeamLeaderboardCategory.bestBowlingFigures ||
        TeamLeaderboardCategory.bestEconomy ||
        TeamLeaderboardCategory.bestBowlingStrikeRate ||
        TeamLeaderboardCategory.mostMaidens ||
        TeamLeaderboardCategory.mostDotBalls ||
        TeamLeaderboardCategory.mostOversBowled ||
        TeamLeaderboardCategory.mostFiveWicketHauls ||
        TeamLeaderboardCategory.lowestAverage =>
          TeamLeaderboardSection.bowling,
        TeamLeaderboardCategory.mostCatches ||
        TeamLeaderboardCategory.mostRunOuts ||
        TeamLeaderboardCategory.mostStumpings ||
        TeamLeaderboardCategory.mostDirectHits ||
        TeamLeaderboardCategory.mostFieldingPoints =>
          TeamLeaderboardSection.fielding,
        TeamLeaderboardCategory.highestPartnership ||
        TeamLeaderboardCategory.mostCenturyPartnerships ||
        TeamLeaderboardCategory.mostFiftyPartnerships ||
        TeamLeaderboardCategory.highestOpeningPartnership ||
        TeamLeaderboardCategory.highestMiddleOrderPartnership ||
        TeamLeaderboardCategory.highestLastWicketPartnership =>
          TeamLeaderboardSection.partnerships,
      };

  String get title => switch (this) {
        TeamLeaderboardCategory.mostRuns => 'Most Runs',
        TeamLeaderboardCategory.highestScore => 'Highest Score',
        TeamLeaderboardCategory.highestAverage => 'Highest Average',
        TeamLeaderboardCategory.bestStrikeRate => 'Best Strike Rate',
        TeamLeaderboardCategory.mostFifties => 'Most Fifties',
        TeamLeaderboardCategory.mostHundreds => 'Most Hundreds',
        TeamLeaderboardCategory.mostSixes => 'Most Sixes',
        TeamLeaderboardCategory.mostFours => 'Most Fours',
        TeamLeaderboardCategory.mostBallsFaced => 'Most Balls Faced',
        TeamLeaderboardCategory.mostNotOuts => 'Most Not Outs',
        TeamLeaderboardCategory.fastestFifty => 'Fastest Fifty',
        TeamLeaderboardCategory.fastestHundred => 'Fastest Hundred',
        TeamLeaderboardCategory.mostWickets => 'Most Wickets',
        TeamLeaderboardCategory.bestBowlingFigures => 'Best Bowling Figures',
        TeamLeaderboardCategory.bestEconomy => 'Best Economy',
        TeamLeaderboardCategory.bestBowlingStrikeRate => 'Best Strike Rate',
        TeamLeaderboardCategory.mostMaidens => 'Most Maidens',
        TeamLeaderboardCategory.mostDotBalls => 'Most Dot Balls',
        TeamLeaderboardCategory.mostOversBowled => 'Most Overs Bowled',
        TeamLeaderboardCategory.mostFiveWicketHauls => 'Most 5-Wicket Hauls',
        TeamLeaderboardCategory.lowestAverage => 'Lowest Average',
        TeamLeaderboardCategory.mostCatches => 'Most Catches',
        TeamLeaderboardCategory.mostRunOuts => 'Most Run Outs',
        TeamLeaderboardCategory.mostStumpings => 'Most Stumpings',
        TeamLeaderboardCategory.mostDirectHits => 'Most Direct Hits',
        TeamLeaderboardCategory.mostFieldingPoints => 'Most Fielding Points',
        TeamLeaderboardCategory.highestPartnership => 'Highest Partnership',
        TeamLeaderboardCategory.mostCenturyPartnerships =>
          'Most Century Partnerships',
        TeamLeaderboardCategory.mostFiftyPartnerships =>
          'Most Fifty Partnerships',
        TeamLeaderboardCategory.highestOpeningPartnership =>
          'Highest Opening Partnership',
        TeamLeaderboardCategory.highestMiddleOrderPartnership =>
          'Highest Middle Order Partnership',
        TeamLeaderboardCategory.highestLastWicketPartnership =>
          'Highest Last Wicket Partnership',
      };
}

const kTeamBattingLeaderboardCategories = [
  TeamLeaderboardCategory.mostRuns,
  TeamLeaderboardCategory.highestScore,
  TeamLeaderboardCategory.highestAverage,
  TeamLeaderboardCategory.bestStrikeRate,
  TeamLeaderboardCategory.mostFifties,
  TeamLeaderboardCategory.mostHundreds,
  TeamLeaderboardCategory.mostSixes,
  TeamLeaderboardCategory.mostFours,
  TeamLeaderboardCategory.mostBallsFaced,
  TeamLeaderboardCategory.mostNotOuts,
  TeamLeaderboardCategory.fastestFifty,
  TeamLeaderboardCategory.fastestHundred,
];

const kTeamBowlingLeaderboardCategories = [
  TeamLeaderboardCategory.mostWickets,
  TeamLeaderboardCategory.bestBowlingFigures,
  TeamLeaderboardCategory.bestEconomy,
  TeamLeaderboardCategory.bestBowlingStrikeRate,
  TeamLeaderboardCategory.mostMaidens,
  TeamLeaderboardCategory.mostDotBalls,
  TeamLeaderboardCategory.mostOversBowled,
  TeamLeaderboardCategory.mostFiveWicketHauls,
  TeamLeaderboardCategory.lowestAverage,
];

const kTeamFieldingLeaderboardCategories = [
  TeamLeaderboardCategory.mostCatches,
  TeamLeaderboardCategory.mostRunOuts,
  TeamLeaderboardCategory.mostStumpings,
  TeamLeaderboardCategory.mostDirectHits,
  TeamLeaderboardCategory.mostFieldingPoints,
];

const kTeamPartnershipLeaderboardCategories = [
  TeamLeaderboardCategory.highestPartnership,
  TeamLeaderboardCategory.mostCenturyPartnerships,
  TeamLeaderboardCategory.mostFiftyPartnerships,
  TeamLeaderboardCategory.highestOpeningPartnership,
  TeamLeaderboardCategory.highestMiddleOrderPartnership,
  TeamLeaderboardCategory.highestLastWicketPartnership,
];

class TeamLeaderboardEntry extends Equatable {
  const TeamLeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.playerName,
    this.photoUrl,
    this.role = '',
    this.valueLabel = '',
    this.matches = 0,
    this.subtitle = '',
  });

  final int rank;
  final String playerId;
  final String playerName;
  final String? photoUrl;
  final String role;
  final String valueLabel;
  final int matches;
  final String subtitle;

  @override
  List<Object?> get props => [rank, playerId, valueLabel];
}

/// Pair-based partnership row for the team leaderboard (insights-style card).
class TeamPartnershipLeaderboardEntry extends Equatable {
  const TeamPartnershipLeaderboardEntry({
    required this.rank,
    required this.runs,
    required this.balls,
    required this.wicketNumber,
    required this.batterAId,
    required this.batterAName,
    required this.batterBId,
    required this.batterBName,
    this.batterAPhotoUrl,
    this.batterBPhotoUrl,
    this.batterARuns = 0,
    this.batterABalls = 0,
    this.batterBRuns = 0,
    this.batterBBalls = 0,
    this.matchLabel = '',
    this.isHighest = false,
  });

  final int rank;
  final int runs;
  final int balls;
  final int wicketNumber;
  final String batterAId;
  final String batterAName;
  final String batterBId;
  final String batterBName;
  final String? batterAPhotoUrl;
  final String? batterBPhotoUrl;
  final int batterARuns;
  final int batterABalls;
  final int batterBRuns;
  final int batterBBalls;
  final String matchLabel;
  final bool isHighest;

  double get batterAShare {
    final total = (batterARuns + batterBRuns).clamp(1, 999999);
    return batterARuns / total;
  }

  double get batterBShare {
    final total = (batterARuns + batterBRuns).clamp(1, 999999);
    return batterBRuns / total;
  }

  @override
  List<Object?> get props => [rank, batterAId, batterBId, runs, balls, matchLabel];
}

enum TeamTrophyKind {
  tournamentWinner,
  runnerUp,
  leagueWinner,
  championship,
  seriesWinner,
  fairPlay,
  special,
}

extension TeamTrophyKindX on TeamTrophyKind {
  String get title => switch (this) {
        TeamTrophyKind.tournamentWinner => 'Tournament Winner',
        TeamTrophyKind.runnerUp => 'Runner-up',
        TeamTrophyKind.leagueWinner => 'League Winner',
        TeamTrophyKind.championship => 'Championship',
        TeamTrophyKind.seriesWinner => 'Series Winner',
        TeamTrophyKind.fairPlay => 'Fair Play',
        TeamTrophyKind.special => 'Special Award',
      };

  String get emoji => switch (this) {
        TeamTrophyKind.tournamentWinner => '🏆',
        TeamTrophyKind.runnerUp => '🥈',
        TeamTrophyKind.leagueWinner => '🥇',
        TeamTrophyKind.championship => '👑',
        TeamTrophyKind.seriesWinner => '⭐',
        TeamTrophyKind.fairPlay => '🤝',
        TeamTrophyKind.special => '🎖️',
      };
}

class TeamTrophy extends Equatable {
  const TeamTrophy({
    required this.id,
    required this.kind,
    required this.title,
    this.season = '',
    this.date,
    this.description = '',
    this.tournamentId,
  });

  final String id;
  final TeamTrophyKind kind;
  final String title;
  final String season;
  final DateTime? date;
  final String description;
  final String? tournamentId;

  @override
  List<Object?> get props => [id, kind, title];
}

/// Snapshot driving the Team Profile hub.
class TeamProfileSnapshot extends Equatable {
  const TeamProfileSnapshot({
    required this.team,
    required this.players,
    required this.matches,
    required this.stats,
    this.captain,
    this.viceCaptain,
    this.trophies = const [],
    this.followersCount = 0,
  });

  final TeamModel team;
  final List<PlayerModel> players;
  final List<MatchModel> matches;
  final TeamProfileStats stats;
  final PlayerModel? captain;
  final PlayerModel? viceCaptain;
  final List<TeamTrophy> trophies;
  final int followersCount;

  @override
  List<Object?> get props => [team.id, players.length, matches.length, stats];
}
