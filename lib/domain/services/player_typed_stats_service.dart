import '../../core/constants/enums.dart';
import '../../core/utils/overs_formatter.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/player_model.dart';
import '../../features/my_cricket/my_cricket_filters.dart';

/// Typed stats plus optional overs metadata for display.
class PlayerTypedStatsResult {
  const PlayerTypedStatsResult({
    required this.stats,
    this.ballsPerOver,
    this.bowlingActualOvers,
  });

  final PlayerStatsModel stats;
  final int? ballsPerOver;
  final double? bowlingActualOvers;
}

/// Builds per-ball-type stats from completed match innings (client fallback).
class PlayerTypedStatsService {
  const PlayerTypedStatsService();

  PlayerStatsModel aggregateForType({
    required List<MatchModel> completedMatches,
    required String playerId,
    required CricketBallType ballType,
    String? authUid,
    String? playerTeamId,
    Set<String> userTeamIds = const {},
  }) {
    final agg = _Agg();

    for (final match in completedMatches) {
      if (match.rules.resolvedBallType != ballType) continue;
      if (!userParticipatedInMatch(
        match,
        uid: authUid,
        player: playerTeamId != null
            ? PlayerModel(id: playerId, name: '', teamId: playerTeamId)
            : null,
        userTeamIds: userTeamIds,
      )) {
        continue;
      }

      var playedInMatch = false;
      for (final inn in match.innings) {
        playedInMatch =
            _accumulateInnings(agg, inn, playerId, match.rules.ballsPerOver) ||
                playedInMatch;
      }
      if (playedInMatch) agg.matchesPlayed += 1;
    }

    return agg.toStats();
  }

  PlayerTypedStatsResult aggregateDetailedForType({
    required List<MatchModel> completedMatches,
    required String playerId,
    required CricketBallType ballType,
    String? authUid,
    String? playerTeamId,
    Set<String> userTeamIds = const {},
  }) {
    final agg = _Agg();
    final bpoCounts = <int, int>{};

    for (final match in completedMatches) {
      if (match.rules.resolvedBallType != ballType) continue;
      if (!userParticipatedInMatch(
        match,
        uid: authUid,
        player: playerTeamId != null
            ? PlayerModel(id: playerId, name: '', teamId: playerTeamId)
            : null,
        userTeamIds: userTeamIds,
      )) {
        continue;
      }

      var playedInMatch = false;
      for (final inn in match.innings) {
        playedInMatch = _accumulateInnings(
              agg,
              inn,
              playerId,
              match.rules.ballsPerOver,
            ) ||
            playedInMatch;
      }
      if (playedInMatch) {
        agg.matchesPlayed += 1;
        final bpo = match.rules.ballsPerOver;
        bpoCounts[bpo] = (bpoCounts[bpo] ?? 0) + 1;
      }
    }

    return PlayerTypedStatsResult(
      stats: agg.toStats(),
      ballsPerOver: bpoCounts.length == 1 ? bpoCounts.keys.first : null,
      bowlingActualOvers:
          agg.bowlingActualOvers > 0 ? agg.bowlingActualOvers : null,
    );
  }

  bool _accumulateInnings(
    _Agg agg,
    InningsModel inn,
    String playerId,
    int ballsPerOver,
  ) {
    var found = false;
    for (final b in inn.batsmen) {
      if (b.playerId != playerId) continue;
      found = true;
      agg.inningsPlayed += 1;
      agg.runs += b.runs;
      agg.ballsFaced += b.balls;
      agg.fours += b.fours;
      agg.sixes += b.sixes;
      if (b.isOut) {
        agg.dismissals += 1;
        if (b.runs == 0) agg.ducks += 1;
      }
      if (b.runs >= 100) {
        agg.hundreds += 1;
      } else if (b.runs >= 50) {
        agg.fifties += 1;
      } else if (b.runs >= 30) {
        agg.thirties += 1;
      }
      if (b.runs > agg.highScore) agg.highScore = b.runs;
    }

    var matchWickets = 0;
    for (final bowler in inn.bowlers) {
      if (bowler.playerId != playerId) continue;
      found = true;
      agg.wickets += bowler.wickets;
      agg.oversBowledBalls += bowler.oversBowledBalls;
      agg.runsConceded += bowler.runsConceded;
      agg.bowlingActualOvers += OversFormatter.calculateOvers(
        bowler.oversBowledBalls,
        ballsPerOver,
      );
      matchWickets += bowler.wickets;
    }
    if (matchWickets >= 5) {
      agg.fiveWickets += 1;
    } else if (matchWickets >= 3) {
      agg.threeWickets += 1;
    }

    return found;
  }
}

class _Agg {
  int runs = 0;
  int ballsFaced = 0;
  int fours = 0;
  int sixes = 0;
  int wickets = 0;
  int oversBowledBalls = 0;
  int runsConceded = 0;
  int matchesPlayed = 0;
  int inningsPlayed = 0;
  int dismissals = 0;
  int highScore = 0;
  int thirties = 0;
  int fifties = 0;
  int hundreds = 0;
  int ducks = 0;
  int threeWickets = 0;
  int fiveWickets = 0;
  int catches = 0;
  int runOuts = 0;
  int stumpings = 0;
  double bowlingActualOvers = 0;

  PlayerStatsModel toStats() => PlayerStatsModel(
        runs: runs,
        ballsFaced: ballsFaced,
        fours: fours,
        sixes: sixes,
        wickets: wickets,
        oversBowledBalls: oversBowledBalls,
        runsConceded: runsConceded,
        matchesPlayed: matchesPlayed,
        inningsPlayed: inningsPlayed,
        dismissals: dismissals,
        highScore: highScore,
        thirties: thirties,
        fifties: fifties,
        hundreds: hundreds,
        ducks: ducks,
        threeWickets: threeWickets,
        fiveWickets: fiveWickets,
        catches: catches,
        runOuts: runOuts,
        stumpings: stumpings,
      );
}

String cricketBallTypeLabel(CricketBallType type) {
  return switch (type) {
    CricketBallType.leather => 'Leather ball',
    CricketBallType.tennis => 'Tennis ball',
    CricketBallType.indoor => 'Indoor',
  };
}
