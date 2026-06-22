import 'dart:math' as math;

import '../../core/constants/enums.dart';
import '../../core/constants/player_profile_constants.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_player_snapshot.dart';
import '../../data/models/player_model.dart';
import '../../domain/wagon_wheel/wagon_wheel_analytics_service.dart';
import '../../domain/wagon_wheel/wagon_wheel_batting_orientation.dart';
import '../../domain/wagon_wheel/wagon_wheel_coordinate_mapper.dart';
import '../../domain/wagon_wheel/wagon_wheel_filter.dart';
import 'captain_stats_service.dart';
import 'match_phase_service.dart';
import 'player_analysis_models.dart';
import 'player_cluster_service.dart';
import 'match_analytics_models.dart';
import 'player_cricket_profile_models.dart';

/// Aggregates career analytics from completed matches and ball events.
class PlayerAdvancedAnalysisService {
  PlayerAdvancedAnalysisService({
    PlayerClusterService? clusterService,
    CaptainStatsService? captainService,
    WagonWheelAnalyticsService? wagonService,
  })  : clusterService = clusterService ?? const PlayerClusterService(),
        captainService = captainService ?? const CaptainStatsService(),
        wagonService = wagonService ?? WagonWheelAnalyticsService();

  final PlayerClusterService clusterService;
  final CaptainStatsService captainService;
  final WagonWheelAnalyticsService wagonService;

  static const _bowlingTypeLabels = [
    'Right Arm Fast',
    'Left Arm Fast',
    'Right Arm Medium',
    'Left Arm Medium',
    'Right Arm Off Spin',
    'Right Arm Leg Spin',
    'Left Arm Orthodox',
    'Left Arm Chinaman',
    'Unknown',
  ];

  static const _fieldSectors = [
    'Fine Leg',
    'Square Leg',
    'Mid Wicket',
    'Mid On',
    'Straight',
    'Long Off',
    'Mid Off',
    'Cover',
    'Point',
    'Third Man',
  ];

  PlayerAdvancedAnalysisSnapshot compute({
    required PlayerModel player,
    required List<MatchModel> completedMatches,
    Map<String, List<BallEventModel>> ballEventsByMatch = const {},
  }) {
    if (completedMatches.length < kAnalysisMinMatches) {
      return PlayerAdvancedAnalysisSnapshot(
        completedMatches: completedMatches.length,
      );
    }

    final playerId = player.id;
    final leftHandedLookup =
        WagonWheelBattingOrientation.leftHandedLookupFromMatches(
      completedMatches,
    );
    WagonWheelBattingOrientation.enrichLeftHandedLookup(
      leftHandedLookup,
      batterId: playerId,
      battingStyle: player.battingStyle,
    );

    final clusters = clusterService.compute(
      playerId: playerId,
      completedMatches: completedMatches,
      ballEventsByMatch: ballEventsByMatch,
    );

    final runDist = _runDistribution(playerId, completedMatches, ballEventsByMatch);
    final scoringZones = _scoringZones(
      playerId: playerId,
      player: player,
      matches: completedMatches,
      ballEventsByMatch: ballEventsByMatch,
      leftHandedLookup: leftHandedLookup,
    );

    final battingTypeMap = <String, _Agg>{};
    final battingPhaseMap = <String, _Agg>{};
    final battingDismissals = <String, int>{};
    final chaseAgg = _Agg();
    final defendAgg = _Agg();
    final bowlingDismissals = <String, int>{};
    final bowlingHandMap = <String, _Agg>{
      'RHB': _Agg(),
      'LHB': _Agg(),
    };
    final wicketPosMap = <String, _Agg>{};
    final bowlingPhaseMap = <String, _Agg>{};
    final opponentMap = <String, _Agg>{};
    final situationMap = <String, _Agg>{};
    final yearlyMap = <int, _Agg>{};
    final inningsScores = <int>[];
    var ducks = 0;
    final formByMatch = <_MatchForm>[];

    var catches = 0;
    var runOuts = 0;
    var stumpings = 0;
    var directHits = 0;

    final sortedMatches = [...completedMatches]
      ..sort((a, b) {
        final da = a.completedAt ?? a.scheduledAt ?? DateTime(2000);
        final db = b.completedAt ?? b.scheduledAt ?? DateTime(2000);
        return da.compareTo(db);
      });

    for (final match in sortedMatches) {
      final events = ballEventsByMatch[match.id] ?? const [];
      final playerTeamId = _playerTeamId(match, playerId);
      final opponentName = _opponentName(match, playerTeamId);
      final year = (match.completedAt ?? match.scheduledAt ?? DateTime.now()).year;
      final yearAgg = yearlyMap.putIfAbsent(year, _Agg.new);
      yearAgg.matches += 1;

      final matchForm = _MatchForm(
        date: match.completedAt ?? match.scheduledAt ?? DateTime.now(),
      );

      final hasEvents = events.isNotEmpty;

      if (hasEvents) {
        _scorecardInningsScores(
          match: match,
          playerId: playerId,
          inningsScores: inningsScores,
          ducks: () => ducks++,
        );
        _scorecardFielding(
          match: match,
          playerId: playerId,
          catches: () => catches++,
          runOuts: () => runOuts++,
          stumpings: () => stumpings++,
        );
      } else {
        _aggregateFromScorecard(
          match: match,
          playerId: playerId,
          playerTeamId: playerTeamId,
          inningsScores: inningsScores,
          ducks: () => ducks++,
          matchForm: matchForm,
          yearAgg: yearAgg,
          fielding: (
            catches: () => catches++,
            runOuts: () => runOuts++,
            stumpings: () => stumpings++,
          ),
        );
      }

      if (!hasEvents) {
        formByMatch.add(matchForm);
        continue;
      }

      final isTest = match.rules.isTestMatch;
      final bpo = match.rules.ballsPerOver;
      final phaseLabels = _phaseLabels(match);

      // Track per-innings batting context for chase/defend.
      final inningsBatting = <int, _InningsBatCtx>{};

      for (final e in events) {
        if (e.strikerId == playerId && e.countsAsBallFaced) {
          final ctx = inningsBatting.putIfAbsent(
            e.inningsNumber,
            () => _InningsBatCtx(
              isChase: _isChaseInnings(match, e.inningsNumber, playerTeamId),
            ),
          );
          ctx.balls += 1;
          ctx.runs += e.batsmanRuns;
          if (e.batsmanRuns == 0) ctx.dots += 1;
          if (e.isBoundary || e.batsmanRuns >= 4) ctx.boundaries += 1;

          final bowlerStyle = _bowlerStyleLabel(
            _lookupPlayer(match, e.bowlerId)?.bowlingStyle,
          );
          final typeAgg = battingTypeMap.putIfAbsent(bowlerStyle, _Agg.new);
          typeAgg.balls += 1;
          typeAgg.runs += e.batsmanRuns;
          if (e.batsmanRuns == 0) typeAgg.dots += 1;
          if (e.isBoundary || e.batsmanRuns >= 4) typeAgg.boundaries += 1;

          final phase = _battingPhaseLabel(
            match: match,
            overNumber: e.overNumber,
            isTest: isTest,
            phaseLabels: phaseLabels,
          );
          final phaseAgg = battingPhaseMap.putIfAbsent(phase, _Agg.new);
          phaseAgg.balls += 1;
          phaseAgg.runs += e.batsmanRuns;
          if (e.batsmanRuns == 0) phaseAgg.dots += 1;
          if (e.isBoundary || e.batsmanRuns >= 4) phaseAgg.boundaries += 1;

          if (opponentName.isNotEmpty) {
            final opp = opponentMap.putIfAbsent(opponentName, _Agg.new);
            opp.balls += 1;
            opp.runs += e.batsmanRuns;
            if (e.batsmanRuns == 0) opp.dots += 1;
            if (e.isBoundary || e.batsmanRuns >= 4) opp.boundaries += 1;
          }

          _situationBatting(
            e: e,
            match: match,
            playerTeamId: playerTeamId,
            situationMap: situationMap,
            bpo: bpo,
          );

          matchForm.runs += e.batsmanRuns;
          matchForm.balls += 1;
          yearAgg.runs += e.batsmanRuns;
          yearAgg.balls += 1;
        }

        if (e.isWicket &&
            e.dismissedPlayerId == playerId &&
            e.strikerId == playerId) {
          final mode = _dismissalLabel(e);
          battingDismissals[mode] = (battingDismissals[mode] ?? 0) + 1;
          final ctx = inningsBatting[e.inningsNumber];
          if (ctx != null) ctx.dismissed = true;
        }

        if (e.bowlerId == playerId && e.countsToBowler) {
          if (e.isLegalDelivery) {
            matchForm.oversBalls += 1;
            matchForm.runsConceded += e.runs;
            yearAgg.oversBalls += 1;
            if (e.runs == 0 && !e.isWicket) {
              // dot
            }
          } else {
            matchForm.runsConceded += e.runs;
          }

          if (e.bowlerGetsWicket) {
            matchForm.wickets += 1;
            yearAgg.wickets += 1;
            final mode = _bowlingDismissalLabel(e);
            bowlingDismissals[mode] = (bowlingDismissals[mode] ?? 0) + 1;

            final dismissedHand = _batterHandLabel(
              _lookupPlayer(match, e.dismissedPlayerId ?? e.strikerId)
                  ?.battingStyle,
            );
            bowlingHandMap[dismissedHand]!.wickets += 1;

            final pos = _battingPositionLabel(
              match: match,
              inningsNumber: e.inningsNumber,
              batterId: e.dismissedPlayerId ?? e.strikerId ?? '',
            );
            wicketPosMap.putIfAbsent(pos, _Agg.new).wickets += 1;
          }

          final phase = _battingPhaseLabel(
            match: match,
            overNumber: e.overNumber,
            isTest: isTest,
            phaseLabels: phaseLabels,
          );
          final bowlPhase = bowlingPhaseMap.putIfAbsent(phase, _Agg.new);
          if (e.isLegalDelivery) {
            bowlPhase.oversBalls += 1;
            bowlPhase.runsConceded += e.runs;
            if (e.runs == 0 && !e.isWicket) bowlPhase.dots += 1;
            if (e.isBoundary || e.batsmanRuns >= 4) bowlPhase.boundaries += 1;
          } else {
            bowlPhase.runsConceded += e.runs;
          }
          if (e.bowlerGetsWicket) bowlPhase.wickets += 1;

          final hand = _batterHandLabel(
            _lookupPlayer(match, e.strikerId)?.battingStyle,
          );
          final handAgg = bowlingHandMap[hand]!;
          if (e.isLegalDelivery) {
            handAgg.oversBalls += 1;
            handAgg.runsConceded += e.runs;
            if (e.runs == 0 && !e.isWicket) handAgg.dots += 1;
          } else {
            handAgg.runsConceded += e.runs;
          }

          _situationBowling(
            e: e,
            match: match,
            playerTeamId: playerTeamId,
            situationMap: situationMap,
            bpo: bpo,
          );
        }

        if (e.primaryFielderId == playerId ||
            e.fielderId == playerId ||
            e.fielderIds.contains(playerId)) {
          if (e.wicketType == WicketType.caught ||
              e.wicketType == WicketType.caughtBehind ||
              e.wicketType == WicketType.caughtAndBowled) {
            catches += 1;
          } else if (e.wicketType == WicketType.runOut ||
              e.wicketType == WicketType.mankad) {
            runOuts += 1;
            if (e.primaryFielderId == playerId && e.secondaryFielderId == null) {
              directHits += 1;
            }
          } else if (e.wicketType == WicketType.stumped) {
            stumpings += 1;
          }
        }
      }

      for (final ctx in inningsBatting.values) {
        if (ctx.runs <= 0 && ctx.balls <= 0) continue;
        if (ctx.isChase) {
          chaseAgg.innings += 1;
          chaseAgg.runs += ctx.runs;
          chaseAgg.balls += ctx.balls;
          chaseAgg.boundaries += ctx.boundaries;
          chaseAgg.dismissals += ctx.dismissed ? 1 : 0;
        } else {
          defendAgg.innings += 1;
          defendAgg.runs += ctx.runs;
          defendAgg.balls += ctx.balls;
          defendAgg.boundaries += ctx.boundaries;
          defendAgg.dismissals += ctx.dismissed ? 1 : 0;
        }
      }

      formByMatch.add(matchForm);
    }

    final captaincy = captainService.compute(
      playerId: playerId,
      completedMatches: completedMatches,
    );

    final summary = _buildSummary(
      clusters: clusters,
      formByMatch: formByMatch,
      yearlyMap: yearlyMap,
      battingTypeMap: battingTypeMap,
      scoringZones: scoringZones,
      bowlingPhaseMap: bowlingPhaseMap,
    );

    final opponentBuckets = opponentMap.entries
        .where((e) => e.value.balls >= 6)
        .map(
          (e) => _toBucket(
            e.key,
            e.value,
            includeBatting: true,
          ),
        )
        .toList()
      ..sort((a, b) => b.average.compareTo(a.average));

    final bestOpponents = opponentBuckets.take(3).toList();
    final worstOpponents = opponentBuckets.reversed.take(3).toList();
    final topOpponents = opponentBuckets.take(10).toList();

    final heatZones = Map<String, int>.from(scoringZones.zones);
    final wicketHeat = _wicketHeatZones(
      playerId: playerId,
      matches: completedMatches,
      ballEventsByMatch: ballEventsByMatch,
      leftHandedLookup: leftHandedLookup,
    );

    final formSeries = _buildFormSeries(formByMatch);
    final formWindows = _buildFormWindows(formByMatch);

    return PlayerAdvancedAnalysisSnapshot(
      hasEnoughData: true,
      completedMatches: completedMatches.length,
      summary: summary,
      clusters: clusters,
      runDistribution: runDist,
      scoringZones: scoringZones,
      battingVsBowlingType: _bowlingTypeLabels
          .where((l) => battingTypeMap.containsKey(l))
          .map((l) => _toBucket(l, battingTypeMap[l]!, includeBatting: true))
          .where((b) => b.balls >= 6)
          .toList()
        ..sort((a, b) => b.runs.compareTo(a.runs)),
      battingPhases: battingPhaseMap.entries
          .map((e) => _toBucket(e.key, e.value, includeBatting: true))
          .where((b) => b.balls >= 6)
          .toList(),
      battingDismissals: DismissalBreakdown(counts: battingDismissals),
      chaseBatting: _toBucket('Batting Second', chaseAgg, includeBatting: true),
      defendBatting: _toBucket('Batting First', defendAgg, includeBatting: true),
      bowlingDismissals: DismissalBreakdown(counts: bowlingDismissals),
      bowlingVsHand: bowlingHandMap.entries
          .map((e) => _toBucket('Against ${e.key}', e.value, includeBowling: true))
          .where((b) => b.oversBalls >= 6)
          .toList(),
      wicketsByPosition: wicketPosMap.entries
          .map((e) => AnalysisMetricBucket(
                label: e.key,
                wickets: e.value.wickets,
              ))
          .where((b) => b.wickets > 0)
          .toList()
        ..sort((a, b) => b.wickets.compareTo(a.wickets)),
      bowlingPhases: bowlingPhaseMap.entries
          .map((e) => _toBucket(e.key, e.value, includeBowling: true))
          .where((b) => b.oversBalls >= 6)
          .toList(),
      fielding: FieldingAnalysis(
        catches: catches,
        runOuts: runOuts,
        directHits: directHits,
        stumpings: stumpings,
        catchAttempts: catches,
        runOutAttempts: runOuts,
      ),
      captaincy: captaincy,
      bestOpponents: bestOpponents,
      worstOpponents: worstOpponents,
      topOpponents: topOpponents,
      situations: situationMap.entries
          .map((e) => _toBucket(e.key, e.value, includeBatting: true))
          .where((b) => b.balls >= 6 || b.wickets > 0)
          .toList(),
      formWindows: formWindows,
      consistency: ConsistencyStats(scores: inningsScores, ducks: ducks),
      yearlyProgression: yearlyMap.entries
          .map(
            (e) => YearlyProgression(
              year: e.key,
              runs: e.value.runs,
              wickets: e.value.wickets,
              matches: e.value.matches,
              innings: e.value.innings,
              balls: e.value.balls,
              oversBalls: e.value.oversBalls,
            ),
          )
          .toList()
        ..sort((a, b) => a.year.compareTo(b.year)),
      formSeries: formSeries,
      heatZones: heatZones,
      wicketHeatZones: wicketHeat,
    );
  }

  static String fieldSectorFromCoordinates(double x, double y) {
    final mapper = WagonWheelCoordinateMapper(
      WagonWheelCoordinateMapper.referenceSize,
    );
    var deg = mapper.angleFromStriker(x, y) * 180 / math.pi;
    if (deg < 0) deg += 360;

    // Straight ≈ 270° (toward top of field from striker at bottom of top edge).
    const sectorCount = 10;
    const width = 360 / sectorCount;
    const offset = 270 - width / 2;
    var idx = ((deg - offset) / width).floor() % sectorCount;
    if (idx < 0) idx += sectorCount;
    return _fieldSectors[idx];
  }

  PlayerSummaryAnalysis _buildSummary({
    required PlayerClusters clusters,
    required List<_MatchForm> formByMatch,
    required Map<int, _Agg> yearlyMap,
    required Map<String, _Agg> battingTypeMap,
    required ScoringZoneStats scoringZones,
    required Map<String, _Agg> bowlingPhaseMap,
  }) {
    final primary = _derivePrimaryStrength(
      clusters: clusters,
      battingTypeMap: battingTypeMap,
      scoringZones: scoringZones,
      bowlingPhaseMap: bowlingPhaseMap,
    );
    final secondary = _deriveSecondaryStrength(clusters, primary);

    final recent = formByMatch.length >= 5
        ? formByMatch.sublist(formByMatch.length - 5)
        : formByMatch;
    final careerSr = _avgStrikeRate(formByMatch);
    final recentSr = _avgStrikeRate(recent);
    final form = _formTrend(recentSr, careerSr, recent);

    final years = yearlyMap.keys.toList()..sort();
    final trend = years.length >= 2
        ? _careerTrend(
            yearlyMap[years[years.length - 2]]!,
            yearlyMap[years.last]!,
          )
        : CareerTrend.stable;

    return PlayerSummaryAnalysis(
      battingCluster: clusters.batting,
      bowlingCluster: clusters.bowling,
      primaryStrength: primary,
      secondaryStrength: secondary,
      currentForm: form.$1,
      careerTrend: trend,
      formLabel: form.$2,
      trendLabel: _trendLabel(trend),
    );
  }

  (FormTrend, String) _formTrend(
    double recentSr,
    double careerSr,
    List<_MatchForm> recent,
  ) {
    final recentRuns = recent.fold<int>(0, (s, m) => s + m.runs);
    if (recent.length >= 3 && recentRuns >= 120 && recentSr >= careerSr * 1.15) {
      return (FormTrend.excellent, 'Excellent');
    }
    if (recentSr >= careerSr * 1.05) {
      return (FormTrend.good, 'Good');
    }
    if (recentSr >= careerSr * 0.85) {
      return (FormTrend.average, 'Average');
    }
    return (FormTrend.poor, 'Needs work');
  }

  CareerTrend _careerTrend(_Agg prev, _Agg latest) {
    if (latest.runs > prev.runs * 1.1 || latest.wickets > prev.wickets * 1.1) {
      return CareerTrend.improving;
    }
    if (latest.runs < prev.runs * 0.85 && latest.wickets < prev.wickets * 0.85) {
      return CareerTrend.declining;
    }
    return CareerTrend.stable;
  }

  String _trendLabel(CareerTrend t) => switch (t) {
        CareerTrend.improving => 'Improving ↑',
        CareerTrend.declining => 'Declining ↓',
        CareerTrend.stable => 'Stable →',
      };

  String _derivePrimaryStrength({
    required PlayerClusters clusters,
    required Map<String, _Agg> battingTypeMap,
    required ScoringZoneStats scoringZones,
    required Map<String, _Agg> bowlingPhaseMap,
  }) {
    if (battingTypeMap.isNotEmpty) {
      final best = battingTypeMap.entries.toList()
        ..sort((a, b) {
          final avgA = a.value.dismissals == 0
              ? a.value.runs.toDouble()
              : a.value.runs / a.value.dismissals;
          final avgB = b.value.dismissals == 0
              ? b.value.runs.toDouble()
              : b.value.runs / b.value.dismissals;
          return avgB.compareTo(avgA);
        });
      if (best.first.value.balls >= 12) {
        return 'Excellent against ${_shortBowlingType(best.first.key)}';
      }
    }

    if (scoringZones.favoriteZone.isNotEmpty && scoringZones.totalRuns >= 30) {
      return 'Strong through ${scoringZones.favoriteZone}';
    }

    final death = bowlingPhaseMap['Death Overs'];
    if (death != null && death.wickets >= 5 && death.oversBalls >= 12) {
      return 'Strong death-over bowler';
    }

    if (clusters.bowling == BowlingClusterType.spearhead) {
      return 'Spearhead bowler';
    }
    if (clusters.batting == BattingClusterType.hardHitter ||
        clusters.batting == BattingClusterType.destroyer) {
      return 'Hard hitter';
    }
    return 'All-round contributor';
  }

  String _deriveSecondaryStrength(PlayerClusters clusters, String primary) {
    final tags = clusters.topTagLabels;
    for (final tag in tags) {
      if (!primary.toLowerCase().contains(tag.toLowerCase())) return tag;
    }
    if (clusters.bowling == BowlingClusterType.economist) {
      return 'Economy bowler';
    }
    if (clusters.batting == BattingClusterType.accumulator) {
      return 'Rotates strike well';
    }
    return '';
  }

  String _shortBowlingType(String label) {
    return label
        .replaceAll('Right Arm ', 'R ')
        .replaceAll('Left Arm ', 'L ')
        .replaceAll(' Spin', '');
  }

  double _avgStrikeRate(List<_MatchForm> matches) {
    final balls = matches.fold<int>(0, (s, m) => s + m.balls);
    final runs = matches.fold<int>(0, (s, m) => s + m.runs);
    if (balls == 0) return 0;
    return (runs / balls) * 100;
  }

  RunDistribution _runDistribution(
    String playerId,
    List<MatchModel> matches,
    Map<String, List<BallEventModel>> ballEventsByMatch,
  ) {
    var singles = 0;
    var doubles = 0;
    var triples = 0;
    var fours = 0;
    var sixes = 0;
    var dots = 0;
    var total = 0;

    for (final match in matches) {
      final events = ballEventsByMatch[match.id];
      if (events != null && events.isNotEmpty) {
        for (final e in events) {
          if (e.strikerId != playerId || !e.countsAsBallFaced) continue;
          total += 1;
          final br = e.batsmanRuns;
          if (br == 0) {
            dots += 1;
          } else if (br == 1) {
            singles += 1;
          } else if (br == 2) {
            doubles += 1;
          } else if (br == 3) {
            triples += 1;
          } else if (br == 4 || (e.isBoundary && br < 6)) {
            fours += 1;
          } else if (br >= 6) {
            sixes += 1;
          }
        }
        continue;
      }

      for (final inn in match.innings) {
        for (final b in inn.batsmen) {
          if (b.playerId != playerId || b.balls <= 0) continue;
          total += b.balls;
          fours += b.fours;
          sixes += b.sixes;
          final boundaryBalls = b.fours + b.sixes;
          final nonBoundaryRuns = b.runs - (b.fours * 4 + b.sixes * 6);
          final nonBoundaryBalls = (b.balls - boundaryBalls).clamp(0, b.balls);
          var s = nonBoundaryRuns.clamp(0, nonBoundaryBalls);
          var d = 0;
          var remaining = nonBoundaryRuns - s;
          if (remaining > 0 && nonBoundaryBalls > s) {
            d = (remaining ~/ 2).clamp(0, nonBoundaryBalls - s);
            remaining -= d * 2;
            s += remaining.clamp(0, nonBoundaryBalls - d);
          }
          singles += s;
          doubles += d;
          final scoringBalls = s + d + boundaryBalls;
          dots += (b.balls - scoringBalls).clamp(0, b.balls);
        }
      }
    }

    if (total == 0) return const RunDistribution();

    return RunDistribution(
      singles: singles,
      doubles: doubles,
      triples: triples,
      fours: fours,
      sixes: sixes,
      dots: dots,
      totalBalls: total,
    );
  }

  ScoringZoneStats _scoringZones({
    required String playerId,
    required PlayerModel player,
    required List<MatchModel> matches,
    required Map<String, List<BallEventModel>> ballEventsByMatch,
    required Map<String, bool> leftHandedLookup,
  }) {
    final allEvents = <BallEventModel>[];
    for (final m in matches) {
      allEvents.addAll(ballEventsByMatch[m.id] ?? const []);
    }
    if (allEvents.isEmpty) return const ScoringZoneStats();

    final shots = wagonService.extractShots(
      events: allEvents,
      matches: matches,
      filter: WagonWheelFilter(batterId: playerId),
    );
    if (shots.isEmpty) return const ScoringZoneStats();

    final zoneRuns = <String, int>{};
    var totalRuns = 0;

    for (final shot in shots) {
      final coords = WagonWheelBattingOrientation.getAnalyticsCoordinates(
        shot,
        leftHandedLookup,
        fallbackBatterId: playerId,
        fallbackBattingStyle: player.battingStyle,
      );
      final sector = fieldSectorFromCoordinates(coords.dx, coords.dy);
      zoneRuns[sector] = (zoneRuns[sector] ?? 0) + shot.batsmanRuns;
      totalRuns += shot.batsmanRuns;
    }

    if (totalRuns == 0) return const ScoringZoneStats();

    final sorted = zoneRuns.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final favorite = sorted.first.key;
    final weakest = sorted.last.key;

    return ScoringZoneStats(
      zones: zoneRuns,
      favoriteZone: favorite,
      weakestZone: weakest,
      totalRuns: totalRuns,
    );
  }

  Map<String, int> _wicketHeatZones({
    required String playerId,
    required List<MatchModel> matches,
    required Map<String, List<BallEventModel>> ballEventsByMatch,
    required Map<String, bool> leftHandedLookup,
  }) {
    final zones = <String, int>{};
    for (final match in matches) {
      for (final e in ballEventsByMatch[match.id] ?? const []) {
        if (e.bowlerId != playerId || !e.bowlerGetsWicket) continue;
        final ww = e.wagonWheel;
        if (ww == null || !ww.enabled) continue;
        final coords = WagonWheelBattingOrientation.getAnalyticsCoordinates(
          WagonWheelShotPoint(
            event: e,
            wagonWheel: ww,
            batsmanRuns: e.batsmanRuns,
            batterId: e.strikerId,
            bowlerId: e.bowlerId,
            battingTeamId: e.battingTeamId,
            matchId: e.matchId,
            inningsNumber: e.inningsNumber,
            timestamp: e.timestamp,
          ),
          leftHandedLookup,
          fallbackBatterId: e.strikerId,
        );
        final sector = fieldSectorFromCoordinates(coords.dx, coords.dy);
        zones[sector] = (zones[sector] ?? 0) + 1;
      }
    }
    return zones;
  }

  List<FormWindowStats> _buildFormWindows(List<_MatchForm> formByMatch) {
    FormWindowStats window(String label, int count) {
      final slice = count >= formByMatch.length
          ? formByMatch
          : formByMatch.sublist(formByMatch.length - count);
      return FormWindowStats(
        label: label,
        runs: slice.fold(0, (s, m) => s + m.runs),
        wickets: slice.fold(0, (s, m) => s + m.wickets),
        balls: slice.fold(0, (s, m) => s + m.balls),
        oversBalls: slice.fold(0, (s, m) => s + m.oversBalls),
        runsConceded: slice.fold(0, (s, m) => s + m.runsConceded),
        innings: slice.where((m) => m.runs > 0).length,
        matches: slice.length,
      );
    }

    return [
      window('Last 5', 5),
      window('Last 10', 10),
      window('Last 20', 20),
      window('Career', formByMatch.length),
    ];
  }

  List<({DateTime date, double runs, double wickets, double sr, double econ})>
      _buildFormSeries(List<_MatchForm> formByMatch) {
    return formByMatch
        .map(
          (m) => (
            date: m.date,
            runs: m.runs.toDouble(),
            wickets: m.wickets.toDouble(),
            sr: m.balls == 0 ? 0.0 : (m.runs / m.balls) * 100,
            econ: m.oversBalls == 0
                ? 0.0
                : m.runsConceded / (m.oversBalls / 6),
          ),
        )
        .toList();
  }

  void _scorecardInningsScores({
    required MatchModel match,
    required String playerId,
    required List<int> inningsScores,
    required void Function() ducks,
  }) {
    for (final inn in match.innings) {
      for (final b in inn.batsmen) {
        if (b.playerId != playerId) continue;
        if (b.balls <= 0 && b.runs <= 0) continue;
        inningsScores.add(b.runs);
        if (b.runs == 0 && b.isOut) ducks();
      }
    }
  }

  void _scorecardFielding({
    required MatchModel match,
    required String playerId,
    required void Function() catches,
    required void Function() runOuts,
    required void Function() stumpings,
  }) {
    for (final inn in match.innings) {
      for (final f in inn.fielders) {
        if (f.playerId != playerId) continue;
        for (var i = 0; i < f.catches; i++) {
          catches();
        }
        for (var i = 0; i < f.runOuts; i++) {
          runOuts();
        }
        for (var i = 0; i < f.stumpings; i++) {
          stumpings();
        }
      }
    }
  }

  void _aggregateFromScorecard({
    required MatchModel match,
    required String playerId,
    required String? playerTeamId,
    required List<int> inningsScores,
    required void Function() ducks,
    required _MatchForm matchForm,
    required _Agg yearAgg,
    required ({
      void Function() catches,
      void Function() runOuts,
      void Function() stumpings,
    }) fielding,
  }) {
    for (final inn in match.innings) {
      for (final b in inn.batsmen) {
        if (b.playerId != playerId) continue;
        if (b.balls <= 0 && b.runs <= 0) continue;
        inningsScores.add(b.runs);
        yearAgg.innings += 1;
        yearAgg.runs += b.runs;
        yearAgg.balls += b.balls;
        matchForm.runs += b.runs;
        matchForm.balls += b.balls;
        if (b.runs == 0 && b.isOut) ducks();
        if (b.runs >= 50) {
          // tracked via consistency
        }
      }
      for (final bowler in inn.bowlers) {
        if (bowler.playerId != playerId) continue;
        yearAgg.wickets += bowler.wickets;
        yearAgg.oversBalls += bowler.oversBowledBalls;
        matchForm.wickets += bowler.wickets;
        matchForm.oversBalls += bowler.oversBowledBalls;
        matchForm.runsConceded += bowler.runsConceded;
      }
      for (final f in inn.fielders) {
        if (f.playerId != playerId) continue;
        for (var i = 0; i < f.catches; i++) {
          fielding.catches();
        }
        for (var i = 0; i < f.runOuts; i++) {
          fielding.runOuts();
        }
        for (var i = 0; i < f.stumpings; i++) {
          fielding.stumpings();
        }
      }
    }
  }

  AnalysisMetricBucket _toBucket(
    String label,
    _Agg agg, {
    bool includeBatting = false,
    bool includeBowling = false,
  }) {
    return AnalysisMetricBucket(
      label: label,
      runs: agg.runs,
      balls: agg.balls,
      wickets: agg.wickets,
      dismissals: agg.dismissals,
      oversBalls: agg.oversBalls,
      runsConceded: agg.runsConceded,
      dots: agg.dots,
      boundaries: agg.boundaries,
      innings: agg.innings,
      matches: agg.matches,
    );
  }

  List<String> _phaseLabels(MatchModel match) {
    if (match.rules.isTestMatch) {
      return const [
        'Opening Phase',
        'Middle Session',
        'New Ball Phase',
        'Old Ball Phase',
      ];
    }
    return const ['Powerplay', 'Middle Overs', 'Death Overs'];
  }

  String _battingPhaseLabel({
    required MatchModel match,
    required int overNumber,
    required bool isTest,
    required List<String> phaseLabels,
  }) {
    if (isTest) {
      if (overNumber <= 20) return phaseLabels[0];
      if (overNumber <= 60) return phaseLabels[1];
      if (overNumber <= 80) return phaseLabels[2];
      return phaseLabels[3];
    }
    final kind = MatchPhaseService.classifyOver(overNumber, match.rules);
    return switch (kind) {
      OverPhaseKind.powerplay => phaseLabels[0],
      OverPhaseKind.middle => phaseLabels[1],
      OverPhaseKind.death => phaseLabels[2],
      OverPhaseKind.normal => phaseLabels[1],
    };
  }

  void _situationBatting({
    required BallEventModel e,
    required MatchModel match,
    required String? playerTeamId,
    required Map<String, _Agg> situationMap,
    required int bpo,
  }) {
    final inn = _innings(match, e.inningsNumber);
    if (inn == null) return;

    final teamScore = inn.totalRuns;
    final wickets = inn.totalWickets;
    final target = _chaseTarget(match, e.inningsNumber);
    final oversDone = inn.legalBalls / bpo;

    if (target != null && teamScore < target - 30) {
      _addSituation(situationMap, 'Chasing', e);
    }
    if (target == null && e.inningsNumber == 1) {
      _addSituation(situationMap, 'Defending', e);
    }
    if (wickets >= 5) {
      _addSituation(situationMap, 'Team Losing', e);
    } else if (wickets <= 2 && teamScore > 40) {
      _addSituation(situationMap, 'Team Winning', e);
    }

    final phase = MatchPhaseService.classifyOver(e.overNumber, match.rules);
    if (phase == OverPhaseKind.powerplay &&
        e.overNumber > (match.rules.powerplayOvers ?? 2)) {
      _addSituation(situationMap, 'After Powerplay', e);
    }
    if (phase == OverPhaseKind.death) {
      _addSituation(situationMap, 'Death Overs', e);
    }
    if (e.overNumber >= match.rules.totalOvers - 4) {
      _addSituation(situationMap, 'Last 5 Overs', e);
    }
    if (phase == OverPhaseKind.death) {
      _addSituation(situationMap, 'Pressure Overs', e);
    }
    if (oversDone > 0) {
      // context captured
    }
  }

  void _situationBowling({
    required BallEventModel e,
    required MatchModel match,
    required String? playerTeamId,
    required Map<String, _Agg> situationMap,
    required int bpo,
  }) {
    final phase = MatchPhaseService.classifyOver(e.overNumber, match.rules);
    if (phase == OverPhaseKind.death) {
      final agg = situationMap.putIfAbsent('Death Overs (Bowling)', _Agg.new);
      if (e.isLegalDelivery) {
        agg.oversBalls += 1;
        agg.runsConceded += e.runs;
      }
      if (e.bowlerGetsWicket) agg.wickets += 1;
    }
  }

  void _addSituation(
    Map<String, _Agg> map,
    String label,
    BallEventModel e,
  ) {
    final agg = map.putIfAbsent(label, _Agg.new);
    agg.balls += 1;
    agg.runs += e.batsmanRuns;
    if (e.batsmanRuns == 0) agg.dots += 1;
    if (e.isBoundary || e.batsmanRuns >= 4) agg.boundaries += 1;
  }

  String? _playerTeamId(MatchModel match, String playerId) {
    final setup = match.setup;
    if (setup == null) return null;
    for (final p in [
      ...setup.teamAPlayingPlayers,
      ...setup.teamASubstitutePlayers,
      ...setup.teamBPlayingPlayers,
      ...setup.teamBSubstitutePlayers,
    ]) {
      if (p.id == playerId) {
        if (setup.teamAPlayingPlayers.any((x) => x.id == playerId) ||
            setup.teamASubstitutePlayers.any((x) => x.id == playerId)) {
          return match.teamAId;
        }
        return match.teamBId;
      }
    }
    return null;
  }

  String _opponentName(MatchModel match, String? playerTeamId) {
    if (playerTeamId == null) return '';
    if (match.teamAId == playerTeamId) return match.teamBName;
    if (match.teamBId == playerTeamId) return match.teamAName;
    return '';
  }

  bool _isChaseInnings(MatchModel match, int inningsNumber, String? teamId) {
    if (inningsNumber <= 1) return false;
    return true;
  }

  int? _chaseTarget(MatchModel match, int inningsNumber) {
    if (inningsNumber <= 1) return null;
    if (match.innings.isEmpty) return null;
    return match.innings.first.totalRuns + 1;
  }

  InningsModel? _innings(MatchModel match, int inningsNumber) {
    for (final inn in match.innings) {
      if (inn.inningsNumber == inningsNumber) return inn;
    }
    return null;
  }

  MatchPlayerSnapshot? _lookupPlayer(MatchModel match, String? id) {
    if (id == null) return null;
    final setup = match.setup;
    if (setup == null) return null;
    for (final p in [
      ...setup.teamAPlayingPlayers,
      ...setup.teamASubstitutePlayers,
      ...setup.teamBPlayingPlayers,
      ...setup.teamBSubstitutePlayers,
    ]) {
      if (p.id == id) return p;
    }
    return null;
  }

  String _bowlerStyleLabel(String? raw) {
    final style = PlayerBowlingStyleLabels.fromStored(raw);
    if (style == null) return 'Unknown';
    return switch (style) {
      PlayerBowlingStyle.rightArmFast => 'Right Arm Fast',
      PlayerBowlingStyle.leftArmFast => 'Left Arm Fast',
      PlayerBowlingStyle.rightArmMediumFast ||
      PlayerBowlingStyle.rightArmMedium =>
        'Right Arm Medium',
      PlayerBowlingStyle.leftArmMediumFast ||
      PlayerBowlingStyle.leftArmMedium =>
        'Left Arm Medium',
      PlayerBowlingStyle.rightArmOffSpin => 'Right Arm Off Spin',
      PlayerBowlingStyle.rightArmLegSpin ||
      PlayerBowlingStyle.rightArmLegBreak ||
      PlayerBowlingStyle.rightArmGoogly =>
        'Right Arm Leg Spin',
      PlayerBowlingStyle.leftArmOrthodoxSpin => 'Left Arm Orthodox',
      PlayerBowlingStyle.leftArmChinaman ||
      PlayerBowlingStyle.leftArmWristSpin =>
        'Left Arm Chinaman',
      PlayerBowlingStyle.doNotBowl => 'Unknown',
    };
  }

  String _batterHandLabel(String? battingStyle) {
    if (WagonWheelBattingOrientation.isLeftHanded(battingStyle)) return 'LHB';
    return 'RHB';
  }

  String _battingPositionLabel({
    required MatchModel match,
    required int inningsNumber,
    required String batterId,
  }) {
    final inn = _innings(match, inningsNumber);
    if (inn == null || batterId.isEmpty) return 'No.8+';
    final order = <String>[];
    for (final fow in inn.fallOfWickets) {
      if (!order.contains(fow.batsmanId)) order.add(fow.batsmanId);
    }
    for (final b in inn.batsmen) {
      if (!order.contains(b.playerId)) order.add(b.playerId);
    }
    final idx = order.indexOf(batterId);
    if (idx <= 0) return 'Openers';
    if (idx == 1) return 'No.3';
    if (idx == 2) return 'No.4';
    if (idx == 3) return 'No.5';
    if (idx == 4) return 'No.6';
    if (idx == 5) return 'No.7';
    return 'No.8+';
  }

  String _dismissalLabel(BallEventModel e) {
    return switch (e.wicketType) {
      WicketType.bowled => 'Bowled',
      WicketType.lbw => 'LBW',
      WicketType.caught ||
      WicketType.caughtBehind ||
      WicketType.caughtAndBowled =>
        'Caught',
      WicketType.stumped => 'Stumped',
      WicketType.runOut || WicketType.mankad => 'Run Out',
      WicketType.hitWicket => 'Hit Wicket',
      WicketType.retiredHurt || WicketType.retiredOut => 'Retired',
      _ => 'Caught',
    };
  }

  String _bowlingDismissalLabel(BallEventModel e) {
    return switch (e.wicketType) {
      WicketType.bowled => 'Bowled',
      WicketType.lbw => 'LBW',
      WicketType.caught ||
      WicketType.caughtBehind =>
        'Caught',
      WicketType.caughtAndBowled => 'Caught & Bowled',
      WicketType.stumped => 'Stumped',
      WicketType.runOut || WicketType.mankad => 'Run Out Assisted',
      WicketType.hitWicket => 'Hit Wicket',
      _ => 'Caught',
    };
  }
}

class _Agg {
  int runs = 0;
  int balls = 0;
  int wickets = 0;
  int dismissals = 0;
  int oversBalls = 0;
  int runsConceded = 0;
  int dots = 0;
  int boundaries = 0;
  int innings = 0;
  int matches = 0;
}

class _InningsBatCtx {
  _InningsBatCtx({required this.isChase});

  final bool isChase;
  int runs = 0;
  int balls = 0;
  int dots = 0;
  int boundaries = 0;
  bool dismissed = false;
}

class _MatchForm {
  _MatchForm({required this.date});

  final DateTime date;
  int runs = 0;
  int balls = 0;
  int wickets = 0;
  int oversBalls = 0;
  int runsConceded = 0;
}
