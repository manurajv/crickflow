import 'package:equatable/equatable.dart';

/// Filter chips on the MVP leaderboard.
enum MvpLeaderboardFilter {
  all,
  batters,
  bowlers,
  fielders,
  teamA,
  teamB,
}

/// Display row for the filtered leaderboard (rank + score adapt per filter).
class MvpLeaderboardEntry extends Equatable {
  const MvpLeaderboardEntry({
    required this.player,
    required this.displayRank,
    required this.displayScore,
    required this.scoreLabel,
  });

  final MvpPlayerScore player;
  final int displayRank;
  final double displayScore;
  final String scoreLabel;

  @override
  List<Object?> get props => [player.playerId, displayRank, displayScore];
}

/// Format-aware weights used when scoring MVP components.
class MvpFormatContext extends Equatable {
  const MvpFormatContext({
    required this.totalOvers,
    required this.ballsPerOver,
    required this.totalLegalBalls,
    required this.isTestMatch,
    required this.parRunsPerInnings,
    required this.parStrikeRate,
    required this.parEconomy,
    required this.strikeRateWeight,
    required this.economyWeight,
    required this.runsWeight,
  });

  final int totalOvers;
  final int ballsPerOver;
  final int totalLegalBalls;
  final bool isTestMatch;
  final double parRunsPerInnings;
  final double parStrikeRate;
  final double parEconomy;
  final double strikeRateWeight;
  final double economyWeight;
  final double runsWeight;

  @override
  List<Object?> get props => [
        totalOvers,
        ballsPerOver,
        totalLegalBalls,
        isTestMatch,
        parRunsPerInnings,
        parStrikeRate,
        parEconomy,
        strikeRateWeight,
        economyWeight,
        runsWeight,
      ];
}

/// Per-player MVP breakdown.
class MvpPlayerScore extends Equatable {
  const MvpPlayerScore({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    this.photoUrl,
    required this.rank,
    required this.battingMvp,
    required this.bowlingMvp,
    required this.fieldingMvp,
    required this.clutchBonus,
    required this.partnershipBonus,
    required this.totalMvp,
    this.isPlayerOfTheMatch = false,
    this.isFighterOfTheMatch = false,
  });

  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final String? photoUrl;
  final int rank;
  final double battingMvp;
  final double bowlingMvp;
  final double fieldingMvp;
  final double clutchBonus;
  final double partnershipBonus;
  final double totalMvp;
  final bool isPlayerOfTheMatch;
  final bool isFighterOfTheMatch;

  double get coreBattingMvp => battingMvp;
  double get coreBowlingMvp => bowlingMvp;
  double get coreFieldingMvp => fieldingMvp;

  bool get hasBatting => battingMvp > 0.001;
  bool get hasBowling => bowlingMvp > 0.001;
  bool get hasFielding => fieldingMvp > 0.001;

  MvpPlayerScore copyWith({
    int? rank,
    bool? isPlayerOfTheMatch,
    bool? isFighterOfTheMatch,
  }) {
    return MvpPlayerScore(
      playerId: playerId,
      playerName: playerName,
      teamId: teamId,
      teamName: teamName,
      photoUrl: photoUrl,
      rank: rank ?? this.rank,
      battingMvp: battingMvp,
      bowlingMvp: bowlingMvp,
      fieldingMvp: fieldingMvp,
      clutchBonus: clutchBonus,
      partnershipBonus: partnershipBonus,
      totalMvp: totalMvp,
      isPlayerOfTheMatch: isPlayerOfTheMatch ?? this.isPlayerOfTheMatch,
      isFighterOfTheMatch: isFighterOfTheMatch ?? this.isFighterOfTheMatch,
    );
  }

  bool matchesFilter(
    MvpLeaderboardFilter filter, {
    required String? teamAId,
    required String? teamBId,
  }) {
    switch (filter) {
      case MvpLeaderboardFilter.all:
        return true;
      case MvpLeaderboardFilter.batters:
        return hasBatting;
      case MvpLeaderboardFilter.bowlers:
        return hasBowling;
      case MvpLeaderboardFilter.fielders:
        return hasFielding;
      case MvpLeaderboardFilter.teamA:
        return teamAId != null && teamId == teamAId;
      case MvpLeaderboardFilter.teamB:
        return teamBId != null && teamId == teamBId;
    }
  }

  double scoreForFilter(MvpLeaderboardFilter filter) {
    switch (filter) {
      case MvpLeaderboardFilter.batters:
        return battingMvp;
      case MvpLeaderboardFilter.bowlers:
        return bowlingMvp;
      case MvpLeaderboardFilter.fielders:
        return fieldingMvp;
      case MvpLeaderboardFilter.all:
      case MvpLeaderboardFilter.teamA:
      case MvpLeaderboardFilter.teamB:
        return totalMvp;
    }
  }

  @override
  List<Object?> get props => [
        playerId,
        rank,
        battingMvp,
        bowlingMvp,
        fieldingMvp,
        totalMvp,
        isPlayerOfTheMatch,
        isFighterOfTheMatch,
      ];
}

/// Cached MVP board for a match.
class MatchMvpSnapshot extends Equatable {
  const MatchMvpSnapshot({
    this.players = const [],
    this.formatContext,
    this.losingTeamId,
    this.teamAId,
    this.teamBId,
    this.hasData = false,
    this.isLive = false,
  });

  final List<MvpPlayerScore> players;
  final MvpFormatContext? formatContext;
  final String? losingTeamId;
  final String? teamAId;
  final String? teamBId;
  final bool hasData;
  final bool isLive;

  MvpPlayerScore? get playerOfTheMatch =>
      players.where((p) => p.isPlayerOfTheMatch).firstOrNull;

  MvpPlayerScore? get fighterOfTheMatch =>
      players.where((p) => p.isFighterOfTheMatch).firstOrNull;

  List<MvpPlayerScore> get podium =>
      players.length >= 3 ? players.take(3).toList() : players;

  List<MvpPlayerScore> filtered(MvpLeaderboardFilter filter) {
    if (filter == MvpLeaderboardFilter.all) return players;
    return players
        .where(
          (p) => p.matchesFilter(
            filter,
            teamAId: teamAId,
            teamBId: teamBId,
          ),
        )
        .toList();
  }

  /// Filtered list with category-specific scores and re-ranked positions.
  List<MvpLeaderboardEntry> leaderboardFor(MvpLeaderboardFilter filter) {
    final candidates = filtered(filter);
    final sorted = List<MvpPlayerScore>.from(candidates)
      ..sort((a, b) => b.scoreForFilter(filter).compareTo(a.scoreForFilter(filter)));

    final scoreLabel = switch (filter) {
      MvpLeaderboardFilter.batters => 'Bat',
      MvpLeaderboardFilter.bowlers => 'Bowl',
      MvpLeaderboardFilter.fielders => 'Field',
      _ => 'MVP',
    };

    return [
      for (var i = 0; i < sorted.length; i++)
        MvpLeaderboardEntry(
          player: sorted[i],
          displayRank: i + 1,
          displayScore: sorted[i].scoreForFilter(filter),
          scoreLabel: scoreLabel,
        ),
    ];
  }

  @override
  List<Object?> get props => [players, hasData, isLive];
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
