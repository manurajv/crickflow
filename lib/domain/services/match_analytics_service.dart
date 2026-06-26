import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/cricket_math.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_revision_model.dart';
import '../../data/models/match_rules_model.dart';
import '../../domain/display/match_revision_display.dart';
import '../../domain/scoring/ball_event_aggregator.dart';
import 'match_analytics_models.dart';
import 'match_phase_service.dart';
import 'dismissal_formatter.dart';

/// Read-only analytics derived from match + ball events (no scoring changes).
class MatchAnalyticsService {
  MatchAnalyticsSnapshot build({
    required MatchModel match,
    List<BallEventModel> ballEvents = const [],
    List<MatchRevisionModel> revisions = const [],
  }) {
    final rules = match.rules;
    final ballsPerOver = rules.ballsPerOver;
    final isTest = rules.isTestMatch;
    final isLimited = !isTest;

    if (ballEvents.isEmpty && match.innings.every((i) => i.legalBalls == 0)) {
      return MatchAnalyticsSnapshot(
        isLive: _isLive(match),
        isTestMatch: isTest,
        isLimitedOvers: isLimited,
        ballsPerOver: ballsPerOver,
        dlsInfo: _dlsInfo(match, revisions),
        penalties: MatchRevisionDisplay.penaltyEntries(match, revisions),
        chaseTarget: _chaseTarget(match),
      );
    }

    final aggregator = BallEventAggregator();
    final projections = match.innings
        .map(
          (inn) => ballEvents.isEmpty
              ? null
              : aggregator.projectInnings(
                  match: match,
                  lineupInnings: inn,
                  allEvents: ballEvents,
                ),
        )
        .whereType<InningsDerivedProjection>()
        .toList();

    final allEvents = _sortedEvents(ballEvents);
    final overRuns = _overRunsByInnings(allEvents);
    final summary = _buildSummary(match, projections, allEvents, overRuns);
    final worm = _buildWorm(
      match,
      allEvents,
      ballsPerOver,
      match.rules.isTestMatch == false,
    );
    final runRate = _buildRunRate(
      match,
      projections,
      allEvents,
      ballsPerOver,
      isLimited,
    );
    final manhattan = _buildManhattan(match, overRuns, allEvents, rules, projections);
    final partnershipData = _buildPartnershipGroups(match, projections);
    final partnerships = partnershipData.$1;
    final partnershipGroups = partnershipData.$2;
    final phases = isLimited
        ? _buildPhases(match, allEvents, rules)
        : const <PhaseAnalytics>[];
    final phaseRanges =
        isLimited ? MatchPhaseService.forRules(rules) : null;
    final boundaries = _buildBoundaries(allEvents, projections);
    final bowling = _buildBowlingImpact(match, allEvents, ballsPerOver);
    final extras = _buildExtras(projections);
    final dots = _buildDotBalls(allEvents);
    final testAnalytics =
        isTest ? _buildTestAnalytics(match, allEvents, ballsPerOver) : null;

    return MatchAnalyticsSnapshot(
      hasData: true,
      isLive: _isLive(match),
      isTestMatch: isTest,
      isLimitedOvers: isLimited,
      ballsPerOver: ballsPerOver,
      summary: summary,
      worm: worm,
      runRate: runRate,
      manhattan: manhattan,
      partnerships: partnerships,
      partnershipGroups: partnershipGroups,
      phases: phases,
      phaseRanges: phaseRanges,
      boundaries: boundaries,
      bowlingImpact: bowling,
      extras: extras,
      dotBalls: dots,
      dlsInfo: _dlsInfo(match, revisions),
      penalties: MatchRevisionDisplay.penaltyEntries(match, revisions),
      chaseTarget: _chaseTarget(match),
      testAnalytics: testAnalytics,
    );
  }

  bool _isLive(MatchModel match) =>
      match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak;

  int? _chaseTarget(MatchModel match) {
    final s = match.targetState;
    if (s.effectiveRevisedTarget != null) return s.effectiveRevisedTarget;
    final second = MatchRevisionDisplay.secondRegularInnings(match);
    return second?.targetRuns;
  }

  DlsSummaryInfo? _dlsInfo(
    MatchModel match,
    List<MatchRevisionModel> revisions,
  ) {
    final s = match.targetState;
    if (!s.dlsApplied && s.effectiveRevisedTarget == null) return null;

    MatchRevisionModel? dlsRev;
    for (final rev in revisions) {
      if (rev.type.toLowerCase() == 'dls') {
        dlsRev = rev;
        break;
      }
    }

    String? appliedAt;
    if (dlsRev?.createdAt != null) {
      final dt = dlsRev!.createdAt!;
      appliedAt =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return DlsSummaryInfo(
      originalTarget: s.effectiveOriginalTarget ?? s.originalTarget,
      revisedTarget: s.effectiveRevisedTarget,
      originalOvers: s.originalOvers,
      revisedOvers: s.effectiveRevisedOvers,
      appliedAtLabel: appliedAt,
    );
  }

  List<BallEventModel> _sortedEvents(List<BallEventModel> events) {
    final copy = [...events]..sort((a, b) => a.sequence.compareTo(b.sequence));
    return copy;
  }

  Map<int, Map<int, int>> _overRunsByInnings(List<BallEventModel> events) {
    final map = <int, Map<int, int>>{};
    for (final e in events) {
      if (!_countsInOver(e)) continue;
      final innMap = map.putIfAbsent(e.inningsNumber, () => {});
      innMap[e.overNumber] = (innMap[e.overNumber] ?? 0) + e.runs;
    }
    return map;
  }

  bool _countsInOver(BallEventModel e) {
    if (e.eventType == BallEventType.lineupChange ||
        e.eventType == BallEventType.wicketKeeperChange ||
        !e.countsInOver) {
      return false;
    }
    return true;
  }

  MatchSummaryAnalytics _buildSummary(
    MatchModel match,
    List<InningsDerivedProjection> projections,
    List<BallEventModel> events,
    Map<int, Map<int, int>> overRuns,
  ) {
    final topBatter = _topBatter(match, projections);
    final bestBowler = _bestBowler(match, projections);
    final highestPartnership = _highestPartnership(projections);

    var totalRuns = 0;
    var legalBalls = 0;
    var dotBalls = 0;
    var boundaryRuns = 0;
    var extras = 0;

    for (final e in events) {
      if (e.isLegalDelivery) {
        legalBalls++;
        if (e.runs == 0) dotBalls++;
      }
      totalRuns += e.runs;
      if (e.isBoundary || e.batsmanRuns == 4 || e.batsmanRuns == 6) {
        boundaryRuns += e.batsmanRuns;
      }
    }

    for (final p in projections) {
      extras += p.extrasBreakdown.total;
    }

    final overStats = _overExtremes(overRuns);
    final boundaryPct =
        totalRuns == 0 ? 0.0 : (boundaryRuns / totalRuns) * 100;
    final dotPct = legalBalls == 0 ? 0.0 : (dotBalls / legalBalls) * 100;

    return MatchSummaryAnalytics(
      topBatterLabel: topBatter,
      bestBowlerLabel: bestBowler,
      highestPartnershipLabel: highestPartnership,
      boundaryPercent: boundaryPct,
      dotBallPercent: dotPct,
      extras: extras,
      mostExpensiveOverLabel: overStats.$1,
      bestOverLabel: overStats.$2,
    );
  }

  String _topBatter(
    MatchModel match,
    List<InningsDerivedProjection> projections,
  ) {
    String? name;
    var runs = -1;
    var balls = 0;

    final inningsList =
        projections.isNotEmpty ? projections.map((p) => p.innings) : match.innings;

    for (final inn in inningsList) {
      for (final b in inn.batsmen) {
        if (b.runs > runs || (b.runs == runs && b.balls > balls)) {
          runs = b.runs;
          balls = b.balls;
          name = b.playerName.isNotEmpty ? b.playerName : b.playerId;
        }
      }
    }

    if (name == null || runs < 0) return '—';
    return '$runs ($balls)';
  }

  String _bestBowler(
    MatchModel match,
    List<InningsDerivedProjection> projections,
  ) {
    String? label;
    var bestScore = -1.0;

    final inningsList =
        projections.isNotEmpty ? projections.map((p) => p.innings) : match.innings;

    for (final inn in inningsList) {
      for (final b in inn.bowlers) {
        if (b.playerId.isEmpty) continue;
        final econ = CricketMath.economyRate(
          b.runsConceded,
          b.oversBowledBalls,
          match.rules.ballsPerOver,
        );
        final score = b.wickets * 1000 - b.runsConceded - econ * 10;
        if (score > bestScore) {
          bestScore = score;
          label = '${b.wickets}/${b.runsConceded}';
        }
      }
    }
    return label ?? '—';
  }

  String _highestPartnership(List<InningsDerivedProjection> projections) {
    var max = 0;
    for (final p in projections) {
      for (final part in p.partnerships) {
        if (part.runs > max) max = part.runs;
      }
      if (p.innings.partnershipRuns > max) {
        max = p.innings.partnershipRuns;
      }
    }
    return max == 0 ? '—' : '$max Runs';
  }

  (String, String) _overExtremes(Map<int, Map<int, int>> overRuns) {
    var maxRuns = -1;
    var minRuns = 999999;
    var maxLabel = '—';
    var minLabel = '—';

    for (final entry in overRuns.entries) {
      for (final over in entry.value.entries) {
        if (over.value > maxRuns) {
          maxRuns = over.value;
          maxLabel = '${over.value} Runs';
        }
        if (over.value < minRuns) {
          minRuns = over.value;
          minLabel = '${over.value} Run${over.value == 1 ? '' : 's'}';
        }
      }
    }
    return (maxLabel, minLabel);
  }

  WormGraphData _buildWorm(
    MatchModel match,
    List<BallEventModel> allEvents,
    int ballsPerOver,
    bool isLimited,
  ) {
    final series = <WormInningsSeries>[];
    final target = _chaseTarget(match);
    var maxOver = 0;
    final innings = _inningsForAnalytics(match, allEvents);

    for (final inn in innings) {
      final events = BallEventAggregator.eventsForInnings(
        allEvents,
        inn.inningsNumber,
      );
      if (events.isEmpty) continue;

      final isChase = inn.inningsNumber >= 2 && target != null && isLimited;
      final built = _wormSeriesForInnings(
        match: match,
        inn: inn,
        events: events,
        ballsPerOver: ballsPerOver,
        isChase: isChase,
      );

      for (final p in built.points) {
        if (p.over.round() > maxOver) maxOver = p.over.round();
      }

      series.add(
        WormInningsSeries(
          inningsNumber: inn.inningsNumber,
          label: _inningsLabel(match, inn.inningsNumber),
          shortLabel: _shortTeamLabel(_inningsLabel(match, inn.inningsNumber)),
          points: built.points,
          wickets: built.wickets,
          summary: built.summary,
          isChase: isChase,
        ),
      );
    }

    return WormGraphData(
      innings: series,
      targetLine: target,
      maxOverNumber: maxOver,
    );
  }

  List<InningsModel> _inningsForAnalytics(
    MatchModel match,
    List<BallEventModel> events,
  ) {
    if (events.isEmpty) return match.innings;
    final numbers = {
      ...match.innings.map((i) => i.inningsNumber),
      ...events.map((e) => e.inningsNumber),
    }.toList()
      ..sort();
    if (numbers.isEmpty) return match.innings;
    return [
      for (final n in numbers)
        match.innings.where((i) => i.inningsNumber == n).firstOrNull ??
            InningsModel(
              inningsNumber: n,
              battingTeamId: '',
              bowlingTeamId: '',
            ),
    ];
  }

  ({List<WormPoint> points, List<WormWicketMarker> wickets, WormInningsSummary summary})
      _wormSeriesForInnings({
    required MatchModel match,
    required InningsModel inn,
    required List<BallEventModel> events,
    required int ballsPerOver,
    required bool isChase,
  }) {
    final points = <WormPoint>[const WormPoint(over: 0, runs: 0, wickets: 0)];
    final wickets = <WormWicketMarker>[];
    var runs = 0;
    var legal = 0;
    var wkts = 0;
    var boundaries = 0;
    var partnershipRuns = 0;
    var wicketsInOver = 0;
    var runsAtOverStart = 0;
    var highestOverRuns = 0;
    var powerplayRuns = 0;
    final overRuns = <int, int>{};
    final rules = match.rules;
    final playerNames = _playerNamesFromInnings(inn);
    final batterRuns = <String, int>{};
    final batterBalls = <String, int>{};

    String displayName({String? eventName, String? playerId}) {
      if (eventName != null && eventName.trim().isNotEmpty) {
        return eventName.trim();
      }
      if (playerId != null && playerId.isNotEmpty) {
        return playerNames[playerId] ?? playerId;
      }
      return 'Batter';
    }

    for (final e in events) {
      runs += e.runs;
      partnershipRuns += e.runs;
      if (e.isLegalDelivery) legal++;
      if (e.batsmanRuns == 4 || e.batsmanRuns == 6 || e.isBoundary) {
        boundaries++;
      }

      final strikerId = e.strikerId;
      if (strikerId != null &&
          strikerId.isNotEmpty &&
          e.eventType == BallEventType.runs) {
        batterRuns[strikerId] = (batterRuns[strikerId] ?? 0) + e.batsmanRuns;
        if (e.countsAsBallFaced) {
          batterBalls[strikerId] = (batterBalls[strikerId] ?? 0) + 1;
        }
      }

      if (_isWicket(e)) {
        wkts++;
        wicketsInOver++;
        partnershipRuns = 0;

        final dismissedId = e.dismissedPlayerId ?? strikerId ?? '';
        if (dismissedId.isNotEmpty) {
          batterRuns[dismissedId] =
              (batterRuns[dismissedId] ?? 0) + e.batsmanRuns;
          if (e.countsAsBallFaced) {
            batterBalls[dismissedId] = (batterBalls[dismissedId] ?? 0) + 1;
          }
        }

        final dismissedName = displayName(
          eventName: e.dismissedPlayerName,
          playerId: dismissedId.isEmpty ? strikerId : dismissedId,
        );
        final bowlerName = displayName(
          eventName: e.bowlerName,
          playerId: e.bowlerId,
        );
        final dismissalLabel = DismissalFormatter.fromWicketEvent(
          e,
          playerNames: playerNames,
        );

        wickets.add(
          WormWicketMarker(
            over: _fractionalOver(legal, ballsPerOver),
            runs: runs,
            wicketNumber: wkts,
            legalBalls: legal,
            currentRunRate: CricketMath.runRate(runs, legal, ballsPerOver),
            dismissedPlayerName: dismissedName,
            batterRuns: dismissedId.isEmpty ? 0 : (batterRuns[dismissedId] ?? 0),
            batterBalls: dismissedId.isEmpty ? 0 : (batterBalls[dismissedId] ?? 0),
            bowlerName: bowlerName,
            dismissalLabel: dismissalLabel,
          ),
        );
      }

      if (e.isLegalDelivery && legal % ballsPerOver == 0) {
        final over = legal ~/ ballsPerOver;
        final runsInOver = runs - runsAtOverStart;
        overRuns[over] = runsInOver;
        if (runsInOver > highestOverRuns) highestOverRuns = runsInOver;
        if (MatchPhaseService.classifyOver(over, rules) ==
            OverPhaseKind.powerplay) {
          powerplayRuns += runsInOver;
        }
        points.add(
          WormPoint(
            over: over.toDouble(),
            runs: runs,
            wickets: wkts,
            runsInOver: runsInOver,
            currentRunRate: CricketMath.runRate(runs, legal, ballsPerOver),
            partnershipRuns: partnershipRuns,
            wicketsInOver: wicketsInOver,
            tooltip: 'Over $over\n$runs/$wkts',
          ),
        );
        runsAtOverStart = runs;
        wicketsInOver = 0;
      }
    }

    if (legal > 0 && (legal % ballsPerOver != 0 || points.length == 1)) {
      final fracOver = _fractionalOver(legal, ballsPerOver);
      final runsInOver = runs - runsAtOverStart;
      points.add(
        WormPoint(
          over: fracOver,
          runs: runs,
          wickets: wkts,
          runsInOver: runsInOver,
          currentRunRate: CricketMath.runRate(runs, legal, ballsPerOver),
          partnershipRuns: partnershipRuns,
          wicketsInOver: wicketsInOver,
          tooltip: 'Over ${fracOver.toStringAsFixed(1)}\n$runs/$wkts',
        ),
      );
    }

    final completedOvers = overRuns.length;
    final avgOver = completedOvers == 0
        ? 0.0
        : runs / completedOvers;
    final maxOverNum = overRuns.keys.fold(0, (m, k) => math.max(m, k));
    final phaseRanges = MatchPhaseService.forRules(rules);
    var lastNOversRuns = 0;
    if (maxOverNum > 0) {
      for (var o = phaseRanges.lastNOversStart; o <= maxOverNum; o++) {
        lastNOversRuns += overRuns[o] ?? 0;
      }
    }

    final summary = WormInningsSummary(
      finalScoreLabel: '$runs/$wkts',
      highestOverLabel: highestOverRuns == 0 ? '—' : '$highestOverRuns Runs',
      averageOverLabel: completedOvers == 0 ? '—' : avgOver.toStringAsFixed(1),
      boundaries: boundaries,
      powerplayRuns: powerplayRuns,
      lastFiveOversRuns: lastNOversRuns,
    );

    return (points: points, wickets: wickets, summary: summary);
  }

  RunRateGraphData _buildRunRate(
    MatchModel match,
    List<InningsDerivedProjection> projections,
    List<BallEventModel> allEvents,
    int ballsPerOver,
    bool isLimited,
  ) {
    final series = <RunRateInningsSeries>[];
    final target = _chaseTarget(match);
    var maxOver = 0;

    for (final inn in match.innings) {
      final events = BallEventAggregator.eventsForInnings(
        allEvents,
        inn.inningsNumber,
      );
      if (events.isEmpty) continue;

      final isChase = inn.inningsNumber >= 2 && target != null && isLimited;
      final points = _runRatePointsForInnings(
        events: events,
        ballsPerOver: ballsPerOver,
        isChase: isChase,
        target: target,
        match: match,
        inn: inn,
      );

      for (final p in points) {
        if (p.over.round() > maxOver) maxOver = p.over.round();
      }

      series.add(
        RunRateInningsSeries(
          inningsNumber: inn.inningsNumber,
          label: _inningsLabel(match, inn.inningsNumber),
          shortLabel: _shortTeamLabel(_inningsLabel(match, inn.inningsNumber)),
          points: points,
          isChase: isChase,
        ),
      );
    }

    return RunRateGraphData(
      innings: series,
      showRequiredRunRate: isLimited &&
          series.any((s) => s.isChase) &&
          target != null,
      maxOverNumber: maxOver,
    );
  }

  List<RunRatePoint> _runRatePointsForInnings({
    required List<BallEventModel> events,
    required int ballsPerOver,
    required bool isChase,
    required int? target,
    required MatchModel match,
    required InningsModel inn,
  }) {
    final points = <RunRatePoint>[
      const RunRatePoint(over: 0, currentRunRate: 0),
    ];
    var runs = 0;
    var legal = 0;
    var wickets = 0;
    var boundaries = 0;
    var partnershipRuns = 0;
    var wicketsInOver = 0;

    RunRatePoint buildPoint(double over) {
      final crr = CricketMath.runRate(runs, legal, ballsPerOver);
      double? rrr;
      var pressure = false;
      if (isChase && target != null) {
        final runsNeeded = target - runs + 1;
        final maxBalls = _effectiveMaxBalls(match, inn);
        final ballsLeft = maxBalls - legal;
        if (ballsLeft > 0 && runsNeeded > 0) {
          rrr = CricketMath.requiredRunRate(
            runsNeeded: runsNeeded,
            ballsRemaining: ballsLeft,
            ballsPerOver: ballsPerOver,
          );
          pressure = rrr > crr + 1.5;
        }
      }
      return RunRatePoint(
        over: over,
        currentRunRate: crr,
        requiredRunRate: rrr,
        isPressure: pressure,
        totalRuns: runs,
        wickets: wickets,
        boundaries: boundaries,
        partnershipRuns: partnershipRuns,
        wicketsInOver: wicketsInOver,
        legalBalls: legal,
      );
    }

    for (final e in events) {
      runs += e.runs;
      partnershipRuns += e.runs;
      if (e.isLegalDelivery) legal++;
      if (e.batsmanRuns == 4 || e.batsmanRuns == 6 || e.isBoundary) {
        boundaries++;
      }
      if (_isWicket(e)) {
        wickets++;
        wicketsInOver++;
        partnershipRuns = 0;
      }

      if (e.isLegalDelivery && legal % ballsPerOver == 0) {
        final over = legal ~/ ballsPerOver;
        points.add(buildPoint(over.toDouble()));
        wicketsInOver = 0;
      }
    }

    if (legal > 0 && (legal % ballsPerOver != 0 || points.length == 1)) {
      points.add(buildPoint(_fractionalOver(legal, ballsPerOver)));
    }

    return points;
  }

  int _effectiveMaxBalls(MatchModel match, InningsModel inn) {
    final rules = match.rules;
    final revisedOvers = match.targetState.effectiveRevisedOvers;
    final overs = revisedOvers ?? rules.totalOvers;
    return overs * rules.ballsPerOver;
  }

  ManhattanChartData _buildManhattan(
    MatchModel match,
    Map<int, Map<int, int>> overRuns,
    List<BallEventModel> allEvents,
    MatchRulesModel rules,
    List<InningsDerivedProjection> projections,
  ) {
    final details = _overDetailsByInnings(allEvents, rules, overRuns);
    final series = <ManhattanInningsSeries>[];
    var maxOver = 0;

    for (final entry in overRuns.entries) {
      final innNum = entry.key;
      final overDetails = details[innNum]?.values.toList() ?? [];
      overDetails.sort((a, b) => a.overNumber.compareTo(b.overNumber));

      if (overDetails.isEmpty) continue;

      for (final o in overDetails) {
        if (o.overNumber > maxOver) maxOver = o.overNumber;
      }

      var maxRuns = overDetails.first.runs;
      var minRuns = overDetails.first.runs;
      for (final b in overDetails) {
        if (b.runs > maxRuns) maxRuns = b.runs;
        if (b.runs < minRuns) minRuns = b.runs;
      }

      final legacyBars = overDetails
          .map(
            (b) => ManhattanBar(
              overNumber: b.overNumber,
              runs: b.runs,
              phase: b.phase,
              isHighest: b.runs == maxRuns && maxRuns > 0,
              isLowest: b.runs == minRuns,
            ),
          )
          .toList();

      InningsDerivedProjection? projection;
      for (final p in projections) {
        if (p.innings.inningsNumber == innNum) {
          projection = p;
          break;
        }
      }
      final inn = projection?.innings ??
          match.innings
              .where((i) => i.inningsNumber == innNum)
              .cast<InningsModel?>()
              .firstOrNull;
      final avgRr = inn == null
          ? 0.0
          : CricketMath.runRate(
              inn.totalRuns,
              inn.legalBalls,
              rules.ballsPerOver,
            );

      series.add(
        ManhattanInningsSeries(
          inningsNumber: innNum,
          label: _inningsLabel(match, innNum),
          shortLabel: _shortTeamLabel(_inningsLabel(match, innNum)),
          overs: overDetails,
          averageRunRate: avgRr,
          bars: legacyBars,
        ),
      );
    }

    series.sort((a, b) => a.inningsNumber.compareTo(b.inningsNumber));
    return ManhattanChartData(innings: series, maxOverNumber: maxOver);
  }

  Map<int, Map<int, ManhattanOverDetail>> _overDetailsByInnings(
    List<BallEventModel> events,
    MatchRulesModel rules,
    Map<int, Map<int, int>> overRuns,
  ) {
    final acc = <int, Map<int, _OverAccumulator>>{};

    for (final e in events) {
      if (!_countsInOver(e)) continue;
      final innMap = acc.putIfAbsent(e.inningsNumber, () => {});
      final overAcc = innMap.putIfAbsent(e.overNumber, () => _OverAccumulator());
      overAcc.runs += e.runs;
      if (e.isLegalDelivery) overAcc.legalBalls++;
      if (_isWicket(e)) overAcc.wickets++;
      if (e.batsmanRuns == 4 || e.batsmanRuns == 6 || e.isBoundary) {
        overAcc.boundaryRuns += e.batsmanRuns;
      } else {
        overAcc.singles += e.batsmanRuns;
      }
    }

    final result = <int, Map<int, ManhattanOverDetail>>{};
    for (final innEntry in overRuns.entries) {
      final innNum = innEntry.key;
      final overs = <int, ManhattanOverDetail>{};
      for (final overEntry in innEntry.value.entries) {
        final overNum = overEntry.key;
        final runs = overEntry.value;
        final a = acc[innNum]?[overNum] ?? _OverAccumulator();
        overs[overNum] = ManhattanOverDetail(
          overNumber: overNum,
          runs: runs,
          wickets: a.wickets,
          boundaryRuns: a.boundaryRuns,
          singles: a.singles,
          legalBalls: a.legalBalls,
          runRate: CricketMath.runRate(
            runs,
            a.legalBalls > 0 ? a.legalBalls : rules.ballsPerOver,
            rules.ballsPerOver,
          ),
          phase: MatchPhaseService.classifyOver(overNum, rules),
        );
      }
      result[innNum] = overs;
    }
    return result;
  }

  String _shortTeamLabel(String name) {
    if (name.length <= 4) return name;
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length > 1) {
      return words.map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    }
    return name.substring(0, 3).toUpperCase();
  }

  (List<PartnershipAnalytics>, List<PartnershipInningsGroup>)
      _buildPartnershipGroups(
    MatchModel match,
    List<InningsDerivedProjection> projections,
  ) {
    final all = <PartnershipAnalytics>[];
    final groups = <PartnershipInningsGroup>[];

    for (final projection in projections) {
      final innNum = projection.innings.inningsNumber;
      final innPartnerships = _partnershipsForInnings(
        match: match,
        projection: projection,
        inningsNumber: innNum,
      );
      if (innPartnerships.isEmpty) continue;

      var maxRuns = 0;
      var totalRuns = 0;
      for (final p in innPartnerships) {
        if (p.runs > maxRuns) maxRuns = p.runs;
        totalRuns += p.runs;
      }

      final marked = innPartnerships
          .map(
            (p) => PartnershipAnalytics(
              inningsNumber: p.inningsNumber,
              wicketNumber: p.wicketNumber,
              runs: p.runs,
              balls: p.balls,
              batterAId: p.batterAId,
              batterBId: p.batterBId,
              batterAName: p.batterAName,
              batterBName: p.batterBName,
              batterARuns: p.batterARuns,
              batterABalls: p.batterABalls,
              batterBRuns: p.batterBRuns,
              batterBBalls: p.batterBBalls,
              isHighest: p.runs == maxRuns && maxRuns > 0,
            ),
          )
          .toList();

      all.addAll(marked);
      groups.add(
        PartnershipInningsGroup(
          inningsNumber: innNum,
          label: _inningsLabel(match, innNum),
          partnerships: marked,
          summary: PartnershipSummary(
            highest: maxRuns,
            average: marked.isEmpty ? 0 : totalRuns / marked.length,
            count: marked.length,
          ),
        ),
      );
    }

    return (all, groups);
  }

  List<PartnershipAnalytics> _partnershipsForInnings({
    required MatchModel match,
    required InningsDerivedProjection projection,
    required int inningsNumber,
  }) {
    final events = projection.events;
    if (events.isEmpty) return const [];

    final closed = projection.partnerships;
    final result = <PartnershipAnalytics>[];
    final playerRuns = <String, int>{};
    final playerBalls = <String, int>{};
    var closedIndex = 0;
    var wicketNumber = 0;

    void addPartnership({
      required PartnershipRecord part,
      required int runs,
      required int balls,
    }) {
      wicketNumber++;
      final aRuns = playerRuns[part.batterAId] ?? 0;
      final bRuns = playerRuns[part.batterBId] ?? 0;
      final aBalls = playerBalls[part.batterAId] ?? 0;
      final bBalls = playerBalls[part.batterBId] ?? 0;
      result.add(
        PartnershipAnalytics(
          inningsNumber: inningsNumber,
          wicketNumber: wicketNumber,
          runs: runs,
          balls: balls,
          batterAId: part.batterAId,
          batterBId: part.batterBId,
          batterAName: part.batterAName,
          batterBName: part.batterBName,
          batterARuns: aRuns,
          batterABalls: aBalls,
          batterBRuns: bRuns,
          batterBBalls: bBalls,
        ),
      );
      playerRuns.clear();
      playerBalls.clear();
    }

    for (final e in events) {
      _accumulatePartnershipContribution(e, playerRuns, playerBalls);

      if (!_isWicket(e)) continue;

      if (closedIndex < closed.length) {
        final part = closed[closedIndex];
        if (part.runs > 0 || part.balls > 0) {
          addPartnership(part: part, runs: part.runs, balls: part.balls);
        } else {
          playerRuns.clear();
          playerBalls.clear();
        }
        closedIndex++;
      }
    }

    final inn = projection.innings;
    final hasTracked = playerRuns.isNotEmpty;
    if (hasTracked && inn.strikerId != null && inn.nonStrikerId != null) {
      final aId = inn.strikerId!;
      final bId = inn.nonStrikerId!;
      if (aId.isNotEmpty && bId.isNotEmpty) {
        wicketNumber++;
        final sorted = [aId, bId]..sort();
        final names = _playerNamesFromInnings(inn);
        final runs = playerRuns.values.fold<int>(0, (a, b) => a + b);
        final balls = playerBalls.values.fold<int>(0, (a, b) => a + b);
        result.add(
          PartnershipAnalytics(
            inningsNumber: inningsNumber,
            wicketNumber: wicketNumber,
            runs: inn.partnershipRuns > 0 ? inn.partnershipRuns : runs,
            balls: inn.partnershipBalls > 0 ? inn.partnershipBalls : balls,
            batterAId: sorted[0],
            batterBId: sorted[1],
            batterAName: names[sorted[0]] ?? '',
            batterBName: names[sorted[1]] ?? '',
            batterARuns: playerRuns[sorted[0]] ?? 0,
            batterABalls: playerBalls[sorted[0]] ?? 0,
            batterBRuns: playerRuns[sorted[1]] ?? 0,
            batterBBalls: playerBalls[sorted[1]] ?? 0,
          ),
        );
      }
    }

    return result;
  }

  void _accumulatePartnershipContribution(
    BallEventModel e,
    Map<String, int> playerRuns,
    Map<String, int> playerBalls,
  ) {
    final striker = e.strikerId;
    if (striker == null || striker.isEmpty) return;
    playerRuns[striker] = (playerRuns[striker] ?? 0) + e.batsmanRuns;
    if (e.countsAsBallFaced) {
      playerBalls[striker] = (playerBalls[striker] ?? 0) + 1;
    }
  }

  Map<String, String> _playerNamesFromInnings(InningsModel innings) {
    final names = <String, String>{};
    for (final b in innings.batsmen) {
      if (b.playerId.isNotEmpty) {
        names[b.playerId] = b.playerName;
      }
    }
    return names;
  }

  List<PhaseAnalytics> _buildPhases(
    MatchModel match,
    List<BallEventModel> events,
    MatchRulesModel rules,
  ) {
    final ranges = MatchPhaseService.forRules(rules);
    final phaseKeys = <OverPhaseKind, String>{
      OverPhaseKind.powerplay: ranges.powerplayLabel,
      OverPhaseKind.middle: ranges.middleLabel,
      OverPhaseKind.death: ranges.deathLabel,
    };

    final stats = <OverPhaseKind, ({
      int runs,
      int wickets,
      int legal,
      int boundaries,
      int dots,
      int singles,
      int batterRuns,
      int batterBalls,
    })>{
      for (final kind in phaseKeys.keys)
        kind: (
          runs: 0,
          wickets: 0,
          legal: 0,
          boundaries: 0,
          dots: 0,
          singles: 0,
          batterRuns: 0,
          batterBalls: 0,
        ),
    };

    for (final e in events) {
      final kind = MatchPhaseService.classifyOver(e.overNumber, rules);
      if (kind == OverPhaseKind.normal || !stats.containsKey(kind)) continue;

      final cur = stats[kind]!;
      var runs = cur.runs + e.runs;
      var wickets = cur.wickets;
      var legal = cur.legal;
      var boundaries = cur.boundaries;
      var dots = cur.dots;
      var singles = cur.singles;
      var batterRuns = cur.batterRuns;
      var batterBalls = cur.batterBalls;

      if (e.isLegalDelivery) legal++;
      if (_isWicket(e)) wickets++;
      if (e.isLegalDelivery && e.batsmanRuns == 0 && e.runs == 0) dots++;
      if (e.batsmanRuns == 4 ||
          e.batsmanRuns == 6 ||
          e.isBoundary ||
          e.boundaryType == 'four' ||
          e.boundaryType == 'six') {
        boundaries++;
      } else if (e.batsmanRuns == 1 || e.batsmanRuns == 2 || e.batsmanRuns == 3) {
        singles += e.batsmanRuns;
      }
      if (e.strikerId != null && e.strikerId!.isNotEmpty) {
        batterRuns += e.batsmanRuns;
        if (e.countsAsBallFaced) batterBalls++;
      }

      stats[kind] = (
        runs: runs,
        wickets: wickets,
        legal: legal,
        boundaries: boundaries,
        dots: dots,
        singles: singles,
        batterRuns: batterRuns,
        batterBalls: batterBalls,
      );
    }

    return phaseKeys.entries.map((entry) {
      final value = stats[entry.key]!;
      final rr = CricketMath.runRate(
        value.runs,
        value.legal,
        rules.ballsPerOver,
      );
      final dotPct =
          value.legal == 0 ? 0.0 : (value.dots / value.legal) * 100;
      final strikeRate = value.batterBalls == 0
          ? 0.0
          : (value.batterRuns / value.batterBalls) * 100;
      final boundaryPct =
          value.runs == 0 ? 0.0 : (value.boundaries / value.legal) * 100;
      final rotationPct = value.runs == 0
          ? 0.0
          : (value.singles / value.runs) * 100;

      return PhaseAnalytics(
        label: entry.value,
        runs: value.runs,
        wickets: value.wickets,
        runRate: rr,
        boundaries: value.boundaries,
        dotBallPercent: dotPct,
        strikeRate: strikeRate,
        boundaryPercent: boundaryPct,
        strikeRotationPercent: rotationPct,
      );
    }).toList();
  }

  BoundaryAnalytics _buildBoundaries(
    List<BallEventModel> events,
    List<InningsDerivedProjection> projections,
  ) {
    var fours = 0;
    var sixes = 0;
    var boundaryRuns = 0;
    var totalRuns = 0;

    for (final e in events) {
      totalRuns += e.runs;
      if (e.batsmanRuns == 4 || e.boundaryType == 'four') {
        fours++;
        boundaryRuns += 4;
      } else if (e.batsmanRuns == 6 || e.boundaryType == 'six') {
        sixes++;
        boundaryRuns += 6;
      } else if (e.isBoundary) {
        boundaryRuns += e.batsmanRuns;
      }
    }

    return BoundaryAnalytics(
      fours: fours,
      sixes: sixes,
      boundaryRuns: boundaryRuns,
      boundaryPercent:
          totalRuns == 0 ? 0 : (boundaryRuns / totalRuns) * 100,
    );
  }

  List<BowlingImpactAnalytics> _buildBowlingImpact(
    MatchModel match,
    List<BallEventModel> events,
    int ballsPerOver,
  ) {
    final map =
        <String, ({String name, int runs, int balls, int wickets, int dots})>{};

    for (final e in events) {
      final id = e.bowlerId;
      if (id == null || id.isEmpty || !e.countsToBowler) continue;
      final cur = map[id];
      final runs = (cur?.runs ?? 0) + _runsAgainstBowler(e);
      final balls = (cur?.balls ?? 0) + (e.isLegalDelivery ? 1 : 0);
      final wkts = (cur?.wickets ?? 0) + (e.bowlerGetsWicket ? 1 : 0);
      final dots = (cur?.dots ?? 0) +
          (e.isLegalDelivery && e.runs == 0 ? 1 : 0);
      map[id] = (
        name: e.bowlerName?.isNotEmpty == true
            ? e.bowlerName!
            : (cur?.name ?? id),
        runs: runs,
        balls: balls,
        wickets: wkts,
        dots: dots,
      );
    }

    final list = map.entries.map((e) {
      final econ = CricketMath.economyRate(
        e.value.runs,
        e.value.balls,
        ballsPerOver,
      );
      final dotPct = e.value.balls == 0
          ? 0.0
          : (e.value.dots / e.value.balls) * 100;
      final impact = e.value.wickets * 100 +
          dotPct * 0.4 -
          econ * 8 -
          e.value.runs * 0.05;
      return BowlingImpactAnalytics(
        playerId: e.key,
        playerName: e.value.name,
        oversLabel: CricketMath.formatOvers(e.value.balls, ballsPerOver),
        runs: e.value.runs,
        wickets: e.value.wickets,
        economy: econ,
        dotBallPercent: dotPct,
        impactScore: impact,
      );
    }).toList();

    list.sort((a, b) => b.impactScore.compareTo(a.impactScore));
    return list;
  }

  ExtrasAnalytics _buildExtras(List<InningsDerivedProjection> projections) {
    var total = 0;
    var wides = 0;
    var noBalls = 0;
    var byes = 0;
    var legByes = 0;
    var penalties = 0;

    for (final p in projections) {
      final e = p.extrasBreakdown;
      total += e.total;
      wides += e.wides;
      noBalls += e.noBalls;
      byes += e.byes;
      legByes += e.legByes;
      penalties += e.penalties;
    }

    return ExtrasAnalytics(
      total: total,
      wides: wides,
      noBalls: noBalls,
      byes: byes,
      legByes: legByes,
      penalties: penalties,
    );
  }

  DotBallAnalytics _buildDotBalls(List<BallEventModel> events) {
    var dots = 0;
    var scoring = 0;
    var boundaries = 0;
    var legal = 0;

    for (final e in events) {
      if (!e.isLegalDelivery) continue;
      legal++;
      if (e.runs == 0) {
        dots++;
      } else {
        scoring++;
      }
      if (e.batsmanRuns == 4 ||
          e.batsmanRuns == 6 ||
          e.isBoundary) {
        boundaries++;
      }
    }

    return DotBallAnalytics(
      dotBalls: dots,
      scoringBalls: scoring,
      dotBallPercent: legal == 0 ? 0 : (dots / legal) * 100,
      boundaryBallPercent: legal == 0 ? 0 : (boundaries / legal) * 100,
    );
  }

  int _runsAgainstBowler(BallEventModel event) {
    if (event.eventType == BallEventType.bye ||
        event.eventType == BallEventType.legBye) {
      return 0;
    }
    return event.runs;
  }

  bool _isWicket(BallEventModel e) {
    if (e.retiredHurt) return false;
    if (e.isWicket) return true;
    if (e.eventType != BallEventType.wicket) return false;
    return !(e.isFreeHit && e.wicketType != WicketType.runOut);
  }

  double _fractionalOver(int legalBalls, int ballsPerOver) {
    if (legalBalls <= 0) return 0;
    final whole = legalBalls ~/ ballsPerOver;
    final rem = legalBalls % ballsPerOver;
    return whole + (rem / ballsPerOver);
  }

  String _inningsLabel(MatchModel match, int inningsNumber) {
    if (inningsNumber == 1) return match.teamAName;
    if (inningsNumber == 2) return match.teamBName;
    return 'Innings $inningsNumber';
  }

  static const _testSessionOvers = 30;
  static const _testNewBallOvers = 10;

  TestMatchAnalytics _buildTestAnalytics(
    MatchModel match,
    List<BallEventModel> events,
    int ballsPerOver,
  ) {
    if (events.isEmpty) return const TestMatchAnalytics();

    final sessions = <TestSessionBlock>[];
    final newBall = <TestNewBallStats>[];

    for (final inn in match.innings) {
      final innEvents = BallEventAggregator.eventsForInnings(
        events,
        inn.inningsNumber,
      );
      if (innEvents.isEmpty) continue;

      final innLabel = _inningsLabel(match, inn.inningsNumber);
      final maxOver = innEvents.fold<int>(
        0,
        (m, e) => math.max(m, e.overNumber),
      );

      for (var start = 1; start <= maxOver; start += _testSessionOvers) {
        final end = math.min(start + _testSessionOvers - 1, maxOver);
        final block = _aggregateOverRange(innEvents, start, end);
        if (block.legal == 0) continue;
        sessions.add(
          TestSessionBlock(
            label: start == end ? 'Over $start' : 'Overs $start-$end',
            inningsLabel: innLabel,
            runs: block.runs,
            wickets: block.wickets,
            runRate: CricketMath.runRate(block.runs, block.legal, ballsPerOver),
            oversCompleted: end - start + 1,
          ),
        );
      }

      final nbEnd = math.min(_testNewBallOvers, maxOver);
      if (nbEnd >= 1) {
        final block = _aggregateOverRange(innEvents, 1, nbEnd);
        if (block.legal > 0) {
          newBall.add(
            TestNewBallStats(
              label: nbEnd == 1 ? 'Over 1' : 'Overs 1-$nbEnd',
              inningsLabel: innLabel,
              runs: block.runs,
              wickets: block.wickets,
              runRate:
                  CricketMath.runRate(block.runs, block.legal, ballsPerOver),
              boundaries: block.boundaries,
              dotBallPercent:
                  block.legal == 0 ? 0 : (block.dots / block.legal) * 100,
            ),
          );
        }
      }
    }

    var legal = 0;
    var dots = 0;
    var scoring = 0;
    var boundaries = 0;
    var batterRuns = 0;
    var batterBalls = 0;
    var bowlLegal = 0;
    var bowlDots = 0;
    var bowlRuns = 0;
    var bowlWkts = 0;
    String? topBowler;
    var topBowlerDots = -1;

    for (final e in events) {
      if (e.isLegalDelivery) {
        legal++;
        if (e.runs == 0) {
          dots++;
        } else {
          scoring++;
        }
      }
      if (e.batsmanRuns == 4 ||
          e.batsmanRuns == 6 ||
          e.isBoundary ||
          e.boundaryType == 'four' ||
          e.boundaryType == 'six') {
        boundaries++;
      }
      if (e.strikerId != null && e.strikerId!.isNotEmpty) {
        batterRuns += e.batsmanRuns;
        if (e.countsAsBallFaced) batterBalls++;
      }
      if (e.countsToBowler && e.bowlerId != null && e.bowlerId!.isNotEmpty) {
        if (e.isLegalDelivery) {
          bowlLegal++;
          bowlRuns += _runsAgainstBowler(e);
          if (e.runs == 0) bowlDots++;
        }
        if (e.bowlerGetsWicket) bowlWkts++;
        final id = e.bowlerId!;
        final bowlerDots = _bowlerDots(events, id);
        if (bowlerDots > topBowlerDots) {
          topBowlerDots = bowlerDots;
          topBowler = e.bowlerName?.isNotEmpty == true ? e.bowlerName : id;
        }
      }
    }

    final dotPct = legal == 0 ? 0.0 : (dots / legal) * 100;
    final strikeRate = batterBalls == 0
        ? 0.0
        : (batterRuns / batterBalls) * 100;
    final boundaryPct = legal == 0 ? 0.0 : (boundaries / legal) * 100;
    final scoringPct = legal == 0 ? 0.0 : (scoring / legal) * 100;
    final controlLabel = _battingControlLabel(strikeRate, boundaryPct, dotPct);

    final bowlDotPct = bowlLegal == 0 ? 0.0 : (bowlDots / bowlLegal) * 100;
    final bowlEcon =
        CricketMath.economyRate(bowlRuns, bowlLegal, ballsPerOver);
    final pressureLabel = _bowlingPressureLabel(bowlDotPct, bowlEcon, bowlWkts);

    return TestMatchAnalytics(
      sessions: sessions,
      newBall: newBall,
      battingControl: TestBattingControlMetrics(
        dotBallPercent: dotPct,
        strikeRate: strikeRate,
        boundaryPercent: boundaryPct,
        scoringShotPercent: scoringPct,
        controlLabel: controlLabel,
      ),
      bowlingPressure: TestBowlingPressureMetrics(
        dotBallPercent: bowlDotPct,
        economyRate: bowlEcon,
        wickets: bowlWkts,
        topBowlerLabel: topBowler ?? '—',
        pressureLabel: pressureLabel,
      ),
    );
  }

  int _bowlerDots(List<BallEventModel> events, String bowlerId) {
    var dots = 0;
    for (final e in events) {
      if (e.bowlerId == bowlerId &&
          e.countsToBowler &&
          e.isLegalDelivery &&
          e.runs == 0) {
        dots++;
      }
    }
    return dots;
  }

  String _battingControlLabel(double sr, double boundaryPct, double dotPct) {
    if (sr >= 55 && boundaryPct >= 12) return 'Aggressive';
    if (dotPct >= 55 && sr <= 45) return 'Patient';
    if (sr >= 45 && dotPct <= 50) return 'Balanced';
    return 'Building';
  }

  String _bowlingPressureLabel(double dotPct, double economy, int wickets) {
    if (dotPct >= 55 && economy <= 3.0) return 'High pressure';
    if (wickets >= 5 && economy <= 3.5) return 'Wicket-taking spell';
    if (dotPct >= 45) return 'Containment';
    return 'Moderate pressure';
  }

  ({
    int runs,
    int wickets,
    int legal,
    int dots,
    int boundaries,
  }) _aggregateOverRange(
    List<BallEventModel> events,
    int startOver,
    int endOver,
  ) {
    var runs = 0;
    var wickets = 0;
    var legal = 0;
    var dots = 0;
    var boundaries = 0;

    for (final e in events) {
      if (e.overNumber < startOver || e.overNumber > endOver) continue;
      runs += e.runs;
      if (e.isLegalDelivery) {
        legal++;
        if (e.runs == 0) dots++;
      }
      if (_isWicket(e)) wickets++;
      if (e.batsmanRuns == 4 ||
          e.batsmanRuns == 6 ||
          e.isBoundary ||
          e.boundaryType == 'four' ||
          e.boundaryType == 'six') {
        boundaries++;
      }
    }

    return (
      runs: runs,
      wickets: wickets,
      legal: legal,
      dots: dots,
      boundaries: boundaries,
    );
  }
}

class _OverAccumulator {
  int runs = 0;
  int wickets = 0;
  int boundaryRuns = 0;
  int singles = 0;
  int legalBalls = 0;
}
