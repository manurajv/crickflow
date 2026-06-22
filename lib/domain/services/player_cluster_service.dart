import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import 'player_cricket_profile_models.dart';

/// Minimum innings/matches before assigning a cluster.
const _minBattingInnings = 5;
const _minBowlingMatches = 3;

class PlayerClusterService {
  const PlayerClusterService();

  PlayerClusters compute({
    required String playerId,
    required List<MatchModel> completedMatches,
    Map<String, List<BallEventModel>> ballEventsByMatch = const {},
  }) {
    final batting = _aggregateBatting(
      playerId: playerId,
      matches: completedMatches,
      ballEventsByMatch: ballEventsByMatch,
    );
    final bowling = _aggregateBowling(
      playerId: playerId,
      matches: completedMatches,
      ballEventsByMatch: ballEventsByMatch,
    );

    return PlayerClusters(
      batting: batting.inningsCount >= _minBattingInnings
          ? _classifyBatting(batting)
          : null,
      bowling: bowling.matchCount >= _minBowlingMatches
          ? _classifyBowling(bowling)
          : null,
      battingPattern: batting,
      bowlingPattern: bowling,
    );
  }

  BattingPatternStats _aggregateBatting({
    required String playerId,
    required List<MatchModel> matches,
    required Map<String, List<BallEventModel>> ballEventsByMatch,
  }) {
    var balls = 0;
    var runs = 0;
    var dots = 0;
    var singles = 0;
    var doubles = 0;
    var triples = 0;
    var boundaries = 0;
    var sixes = 0;
    var inningsCount = 0;
    final matchIds = <String>{};

    for (final match in matches) {
      final events = ballEventsByMatch[match.id];
      if (events != null && events.isNotEmpty) {
        final fromEvents = _battingFromEvents(playerId, events);
        if (fromEvents.balls == 0) continue;
        balls += fromEvents.balls;
        runs += fromEvents.runs;
        dots += (fromEvents.dotPct * fromEvents.balls / 100).round();
        singles += (fromEvents.singlesPct * fromEvents.balls / 100).round();
        doubles += (fromEvents.doublesPct * fromEvents.balls / 100).round();
        triples += (fromEvents.triplesPct * fromEvents.balls / 100).round();
        boundaries += (fromEvents.boundaryPct * fromEvents.balls / 100).round();
        sixes += (fromEvents.sixPct * fromEvents.balls / 100).round();
        inningsCount += fromEvents.inningsCount;
        matchIds.add(match.id);
        continue;
      }

      for (final inn in match.innings) {
        for (final b in inn.batsmen) {
          if (b.playerId != playerId || b.balls <= 0) continue;
          inningsCount += 1;
          matchIds.add(match.id);
          balls += b.balls;
          runs += b.runs;
          sixes += b.sixes;
          boundaries += b.fours + b.sixes;
          final est = _estimatePatternFromInnings(b);
          dots += est.dots;
          singles += est.singles;
          doubles += est.doubles;
          triples += est.triples;
        }
      }
    }

    if (balls == 0) return BattingPatternStats.empty;

    return BattingPatternStats(
      balls: balls,
      runs: runs,
      strikeRate: (runs / balls) * 100,
      dotPct: (dots / balls) * 100,
      singlesPct: (singles / balls) * 100,
      doublesPct: (doubles / balls) * 100,
      triplesPct: (triples / balls) * 100,
      boundaryPct: (boundaries / balls) * 100,
      sixPct: (sixes / balls) * 100,
      inningsCount: inningsCount,
      matchCount: matchIds.length,
    );
  }

  BattingPatternStats _battingFromEvents(
    String playerId,
    List<BallEventModel> events,
  ) {
    var balls = 0;
    var runs = 0;
    var dots = 0;
    var singles = 0;
    var doubles = 0;
    var triples = 0;
    var boundaries = 0;
    var sixes = 0;
    final inningsSeen = <int>{};

    for (final e in events) {
      if (e.strikerId != playerId) continue;
      if (!e.countsAsBallFaced) continue;
      balls += 1;
      inningsSeen.add(e.inningsNumber);
      final br = e.batsmanRuns;
      runs += br;
      if (e.isBoundary) {
        boundaries += 1;
        if (e.boundaryType == 'six' || br >= 6) {
          sixes += 1;
        }
      } else if (br == 0) {
        dots += 1;
      } else if (br == 1) {
        singles += 1;
      } else if (br == 2) {
        doubles += 1;
      } else if (br == 3) {
        triples += 1;
      } else if (br >= 4) {
        boundaries += 1;
        if (br >= 6) sixes += 1;
      }
    }

    if (balls == 0) return BattingPatternStats.empty;

    return BattingPatternStats(
      balls: balls,
      runs: runs,
      strikeRate: (runs / balls) * 100,
      dotPct: (dots / balls) * 100,
      singlesPct: (singles / balls) * 100,
      doublesPct: (doubles / balls) * 100,
      triplesPct: (triples / balls) * 100,
      boundaryPct: (boundaries / balls) * 100,
      sixPct: (sixes / balls) * 100,
      inningsCount: inningsSeen.length,
      matchCount: 1,
    );
  }

  ({int dots, int singles, int doubles, int triples}) _estimatePatternFromInnings(
    BatsmanInningsModel b,
  ) {
    final boundaryBalls = b.fours + b.sixes;
    final nonBoundaryRuns = b.runs - (b.fours * 4 + b.sixes * 6);
    final nonBoundaryBalls = (b.balls - boundaryBalls).clamp(0, b.balls);

    var singles = nonBoundaryRuns.clamp(0, nonBoundaryBalls);
    var doubles = 0;
    var triples = 0;
    var remainingRuns = nonBoundaryRuns - singles;
    if (remainingRuns > 0 && nonBoundaryBalls > singles) {
      doubles = (remainingRuns ~/ 2).clamp(0, nonBoundaryBalls - singles);
      remainingRuns -= doubles * 2;
      if (remainingRuns >= 3 && nonBoundaryBalls > singles + doubles) {
        triples = 1;
        remainingRuns -= 3;
      }
      singles += remainingRuns.clamp(0, nonBoundaryBalls - doubles - triples);
    }
    final scoringBalls = singles + doubles + triples + boundaryBalls;
    final dots = (b.balls - scoringBalls).clamp(0, b.balls);
    return (dots: dots, singles: singles, doubles: doubles, triples: triples);
  }

  BowlingPatternStats _aggregateBowling({
    required String playerId,
    required List<MatchModel> matches,
    required Map<String, List<BallEventModel>> ballEventsByMatch,
  }) {
    var wickets = 0;
    var runsConceded = 0;
    var legalBalls = 0;
    var dots = 0;
    var oversBowled = 0.0;
    final matchIds = <String>{};

    for (final match in matches) {
      final bpo = match.rules.ballsPerOver;
      final events = ballEventsByMatch[match.id];
      var foundInMatch = false;

      if (events != null && events.isNotEmpty) {
        for (final e in events) {
          if (e.bowlerId != playerId) continue;
          if (!e.countsToBowler) continue;
          foundInMatch = true;
          if (e.isLegalDelivery) {
            legalBalls += 1;
            runsConceded += e.runs;
            if (e.runs == 0 && !e.isWicket) dots += 1;
          } else if (e.countsToBowler) {
            runsConceded += e.runs;
          }
          if (e.bowlerGetsWicket) wickets += 1;
        }
      }

      if (!foundInMatch) {
        for (final inn in match.innings) {
          for (final bowler in inn.bowlers) {
            if (bowler.playerId != playerId) continue;
            foundInMatch = true;
            wickets += bowler.wickets;
            runsConceded += bowler.runsConceded;
            legalBalls += bowler.oversBowledBalls;
            final whole = bowler.oversBowledBalls ~/ bpo;
            final rem = bowler.oversBowledBalls % bpo;
            oversBowled += whole + rem / bpo;
          }
        }
      } else {
        final whole = legalBalls ~/ bpo;
        final rem = legalBalls % bpo;
        oversBowled += whole + rem / bpo;
      }

      if (foundInMatch) matchIds.add(match.id);
    }

    if (legalBalls == 0 && oversBowled == 0) return BowlingPatternStats.empty;

    final overs = oversBowled > 0 ? oversBowled : legalBalls / 6;
    final economy = overs == 0 ? 0.0 : runsConceded / overs;
    final avg = wickets == 0 ? 0.0 : runsConceded / wickets;
    final sr = wickets == 0 ? 0.0 : (legalBalls / wickets);

    return BowlingPatternStats(
      wickets: wickets,
      economy: economy,
      average: avg,
      strikeRate: sr,
      dotPct: legalBalls == 0 ? 0 : (dots / legalBalls) * 100,
      oversBowled: overs,
      matchCount: matchIds.length,
    );
  }

  BattingClusterType _classifyBatting(BattingPatternStats s) {
    if (s.strikeRate >= 160 && s.boundaryPct >= 18) {
      return BattingClusterType.destroyer;
    }
    if (s.strikeRate >= 130 && s.boundaryPct >= 12) {
      return BattingClusterType.hardHitter;
    }
    if (s.singlesPct >= 35 && s.dotPct <= 45 && s.strikeRate < 120) {
      return BattingClusterType.accumulator;
    }
    if (s.doublesPct >= 12 && s.dotPct <= 40) {
      return BattingClusterType.classicist;
    }
    if (s.dotPct >= 50 && s.strikeRate < 100) {
      return BattingClusterType.steadyBatter;
    }
    if (s.strikeRate >= 120) return BattingClusterType.hardHitter;
    if (s.singlesPct >= 30) return BattingClusterType.accumulator;
    return BattingClusterType.classicist;
  }

  BowlingClusterType _classifyBowling(BowlingPatternStats s) {
    if (s.wickets < 5 && s.oversBowled < 10) {
      return BowlingClusterType.aspirant;
    }
    if (s.wickets >= 15 && s.economy <= 7 && s.average <= 22) {
      return BowlingClusterType.spearhead;
    }
    if (s.economy <= 6.5 && s.wickets >= 8) {
      return BowlingClusterType.economist;
    }
    if (s.wickets >= 10 && s.economy > 8) {
      return BowlingClusterType.wildcard;
    }
    if (s.economy <= 7) return BowlingClusterType.economist;
    if (s.wickets >= 8) return BowlingClusterType.wildcard;
    return BowlingClusterType.aspirant;
  }
}
