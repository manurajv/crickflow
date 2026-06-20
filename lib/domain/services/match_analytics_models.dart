import '../../domain/display/match_revision_display.dart';

/// Dynamic powerplay / middle / death labels for limited-overs matches.
class MatchPhaseRanges {
  const MatchPhaseRanges({
    required this.totalOvers,
    this.powerplayLabel = 'Powerplay',
    this.middleLabel = 'Middle Overs',
    this.deathLabel = 'Death Overs',
    this.lastNOversCount = 1,
    this.lastNOversStart = 1,
    this.momentumWindowSize = 4,
  });

  final int totalOvers;
  final String powerplayLabel;
  final String middleLabel;
  final String deathLabel;
  final int lastNOversCount;
  final int lastNOversStart;
  final int momentumWindowSize;

  String get lastNOversLabel =>
      lastNOversCount <= 1 ? 'Last Over' : 'Last $lastNOversCount Overs';
}

/// Cached analytics snapshot for the Insights tab.
class MatchAnalyticsSnapshot {
  const MatchAnalyticsSnapshot({
    this.hasData = false,
    this.isLive = false,
    this.isTestMatch = false,
    this.isLimitedOvers = true,
    this.ballsPerOver = 6,
    this.summary = const MatchSummaryAnalytics(),
    this.worm = const WormGraphData(),
    this.runRate = const RunRateGraphData(),
    this.manhattan = const ManhattanChartData(),
    this.partnerships = const [],
    this.partnershipGroups = const [],
    this.phases = const [],
    this.phaseRanges,
    this.boundaries = const BoundaryAnalytics(),
    this.bowlingImpact = const [],
    this.extras = const ExtrasAnalytics(),
    this.dotBalls = const DotBallAnalytics(),
    this.dlsInfo,
    this.penalties = const [],
    this.chaseTarget,
    this.testAnalytics,
  });

  final bool hasData;
  final bool isLive;
  final bool isTestMatch;
  final bool isLimitedOvers;
  final int ballsPerOver;
  final MatchSummaryAnalytics summary;
  final WormGraphData worm;
  final RunRateGraphData runRate;
  final ManhattanChartData manhattan;
  final List<PartnershipAnalytics> partnerships;
  final List<PartnershipInningsGroup> partnershipGroups;
  final List<PhaseAnalytics> phases;
  final MatchPhaseRanges? phaseRanges;
  final BoundaryAnalytics boundaries;
  final List<BowlingImpactAnalytics> bowlingImpact;
  final ExtrasAnalytics extras;
  final DotBallAnalytics dotBalls;
  final DlsSummaryInfo? dlsInfo;
  final List<PenaltyAdjustmentEntry> penalties;
  final int? chaseTarget;
  final TestMatchAnalytics? testAnalytics;
}

class MatchSummaryAnalytics {
  const MatchSummaryAnalytics({
    this.topBatterLabel = '—',
    this.bestBowlerLabel = '—',
    this.highestPartnershipLabel = '—',
    this.boundaryPercent = 0,
    this.dotBallPercent = 0,
    this.extras = 0,
    this.mostExpensiveOverLabel = '—',
    this.bestOverLabel = '—',
  });

  final String topBatterLabel;
  final String bestBowlerLabel;
  final String highestPartnershipLabel;
  final double boundaryPercent;
  final double dotBallPercent;
  final int extras;
  final String mostExpensiveOverLabel;
  final String bestOverLabel;
}

class DlsSummaryInfo {
  const DlsSummaryInfo({
    this.originalTarget,
    this.revisedTarget,
    this.originalOvers,
    this.revisedOvers,
    this.appliedAtLabel,
  });

  final int? originalTarget;
  final int? revisedTarget;
  final int? originalOvers;
  final int? revisedOvers;
  final String? appliedAtLabel;
}

class WormGraphData {
  const WormGraphData({
    this.innings = const [],
    this.targetLine,
    this.maxOverNumber = 0,
  });

  final List<WormInningsSeries> innings;
  final int? targetLine;
  final int maxOverNumber;

  WormAutoInsights insightsFor(
    List<WormInningsSeries> visible, {
    MatchPhaseRanges? phaseRanges,
    bool isTestMatch = false,
  }) {
    if (visible.isEmpty) return const WormAutoInsights();
    final overs = visible.expand((s) => s.points.where((p) => p.over > 0)).toList();
    if (overs.isEmpty) return const WormAutoInsights();

    final window = phaseRanges?.momentumWindowSize ?? 4;
    final powerplayName = phaseRanges?.powerplayLabel ?? 'Powerplay';
    final lastNOversName = phaseRanges?.lastNOversLabel ?? 'Last 5 Overs';

    String phaseWindow(int size) {
      for (final s in visible) {
        final sorted = [...s.points]..sort((a, b) => a.over.compareTo(b.over));
        if (sorted.length < window) continue;
        var bestTotal = -1;
        var bestStart = 0;
        for (var i = 0; i <= sorted.length - window; i++) {
          final slice = sorted.sublist(i, i + window);
          final total = slice.fold<int>(0, (sum, p) => sum + p.runsInOver);
          if (total > bestTotal) {
            bestTotal = total;
            bestStart = slice.first.over.round();
          }
        }
        if (bestTotal >= 0) {
          return 'Overs $bestStart-${bestStart + window - 1}\n$bestTotal Runs';
        }
      }
      return '—';
    }

    String bestStartLabel() {
      var best = 0;
      var label = '—';
      for (final s in visible) {
        final pp = s.summary.powerplayRuns;
        if (pp > best) {
          best = pp;
          label = '$powerplayName\n$pp Runs';
        }
      }
      return label;
    }

    String bestFinishLabel() {
      var best = 0;
      var label = '—';
      for (final s in visible) {
        final last = s.summary.lastFiveOversRuns;
        if (last > best) {
          best = last;
          label = '$lastNOversName\n$last Runs';
        }
      }
      return label;
    }

    String accelerationLabel() {
      final accelWindow = window.clamp(2, 999);
      for (final s in visible) {
        final sorted = [...s.points]..sort((a, b) => a.over.compareTo(b.over));
        if (sorted.length < accelWindow) continue;
        var bestDelta = -999.0;
        var bestStart = 0;
        for (var i = 0; i <= sorted.length - accelWindow; i++) {
          final delta = sorted[i + accelWindow - 1].currentRunRate -
              sorted[i].currentRunRate;
          if (delta > bestDelta) {
            bestDelta = delta;
            bestStart = sorted[i].over.round();
          }
        }
        if (bestDelta > 0.01) {
          return 'Overs $bestStart-${bestStart + accelWindow - 1}';
        }
      }
      return '—';
    }

    return WormAutoInsights(
      highestScoringPhaseLabel: phaseWindow(window),
      bestStartLabel: isTestMatch ? '—' : bestStartLabel(),
      bestFinishLabel: isTestMatch ? '—' : bestFinishLabel(),
      fastestAccelerationLabel: accelerationLabel(),
    );
  }
}

class WormInningsSeries {
  const WormInningsSeries({
    required this.inningsNumber,
    required this.label,
    required this.shortLabel,
    required this.points,
    required this.wickets,
    required this.summary,
    this.isChase = false,
  });

  final int inningsNumber;
  final String label;
  final String shortLabel;
  final List<WormPoint> points;
  final List<WormWicketMarker> wickets;
  final WormInningsSummary summary;
  final bool isChase;
}

class WormPoint {
  const WormPoint({
    required this.over,
    required this.runs,
    required this.wickets,
    this.runsInOver = 0,
    this.currentRunRate = 0,
    this.partnershipRuns = 0,
    this.wicketsInOver = 0,
    this.tooltip,
  });

  final double over;
  final int runs;
  final int wickets;
  final int runsInOver;
  final double currentRunRate;
  final int partnershipRuns;
  final int wicketsInOver;
  final String? tooltip;
}

class WormWicketMarker {
  const WormWicketMarker({
    required this.over,
    required this.runs,
    required this.wicketNumber,
  });

  final double over;
  final int runs;
  final int wicketNumber;
}

class WormInningsSummary {
  const WormInningsSummary({
    this.finalScoreLabel = '—',
    this.highestOverLabel = '—',
    this.averageOverLabel = '—',
    this.boundaries = 0,
    this.powerplayRuns = 0,
    this.lastFiveOversRuns = 0,
  });

  final String finalScoreLabel;
  final String highestOverLabel;
  final String averageOverLabel;
  final int boundaries;
  final int powerplayRuns;
  final int lastFiveOversRuns;
}

class WormAutoInsights {
  const WormAutoInsights({
    this.highestScoringPhaseLabel = '—',
    this.bestStartLabel = '—',
    this.bestFinishLabel = '—',
    this.fastestAccelerationLabel = '—',
  });

  final String highestScoringPhaseLabel;
  final String bestStartLabel;
  final String bestFinishLabel;
  final String fastestAccelerationLabel;
}

class RunRateGraphData {
  const RunRateGraphData({
    this.innings = const [],
    this.showRequiredRunRate = false,
    this.maxOverNumber = 0,
  });

  final List<RunRateInningsSeries> innings;
  final bool showRequiredRunRate;
  final int maxOverNumber;

  RunRateTrendInsights insightsFor(
    List<RunRateInningsSeries> visible, {
    MatchPhaseRanges? phaseRanges,
  }) {
    final points = visible
        .expand((s) => s.points)
        .where((p) => p.over > 0)
        .toList();
    if (points.isEmpty) return const RunRateTrendInsights();

    RunRatePoint? highest;
    RunRatePoint? lowest;
    for (final p in points) {
      if (highest == null || p.currentRunRate > highest.currentRunRate) {
        highest = p;
      }
      if (lowest == null || p.currentRunRate < lowest.currentRunRate) {
        lowest = p;
      }
    }

    final sorted = [...points]..sort((a, b) => a.over.compareTo(b.over));
    final finalPoint = sorted.last;

    String windowLabel(int window, bool acceleration) {
      if (sorted.length < window + 1) return '—';
      var bestDelta = acceleration ? -999.0 : 999.0;
      var bestStart = 0;
      for (var i = 0; i <= sorted.length - window; i++) {
        final start = sorted[i];
        final end = sorted[i + window - 1];
        final delta = end.currentRunRate - start.currentRunRate;
        if (acceleration) {
          if (delta > bestDelta) {
            bestDelta = delta;
            bestStart = start.over.round();
          }
        } else if (delta < bestDelta) {
          bestDelta = delta;
          bestStart = start.over.round();
        }
      }
      if (bestDelta.abs() < 0.01) return '—';
      final endOver = bestStart + window - 1;
      return 'Overs $bestStart-$endOver';
    }

    final window = phaseRanges?.momentumWindowSize ?? 4;

    return RunRateTrendInsights(
      highestRunRateLabel: highest == null
          ? '—'
          : highest.currentRunRate.toStringAsFixed(1),
      lowestRunRateLabel:
          lowest == null ? '—' : lowest.currentRunRate.toStringAsFixed(1),
      bestAccelerationLabel: windowLabel(window, true),
      biggestSlowdownLabel: windowLabel(window, false),
      finalRunRateLabel: finalPoint.currentRunRate.toStringAsFixed(2),
    );
  }
}

class RunRateInningsSeries {
  const RunRateInningsSeries({
    required this.inningsNumber,
    required this.label,
    required this.shortLabel,
    required this.points,
    this.isChase = false,
  });

  final int inningsNumber;
  final String label;
  final String shortLabel;
  final List<RunRatePoint> points;
  final bool isChase;
}

class RunRatePoint {
  const RunRatePoint({
    required this.over,
    required this.currentRunRate,
    this.requiredRunRate,
    this.isPressure = false,
    this.totalRuns = 0,
    this.wickets = 0,
    this.boundaries = 0,
    this.partnershipRuns = 0,
    this.wicketsInOver = 0,
  });

  final double over;
  final double currentRunRate;
  final double? requiredRunRate;
  final bool isPressure;
  final int totalRuns;
  final int wickets;
  final int boundaries;
  final int partnershipRuns;
  final int wicketsInOver;
}

class RunRateTrendInsights {
  const RunRateTrendInsights({
    this.highestRunRateLabel = '—',
    this.lowestRunRateLabel = '—',
    this.bestAccelerationLabel = '—',
    this.biggestSlowdownLabel = '—',
    this.finalRunRateLabel = '—',
  });

  final String highestRunRateLabel;
  final String lowestRunRateLabel;
  final String bestAccelerationLabel;
  final String biggestSlowdownLabel;
  final String finalRunRateLabel;
}

enum OverPhaseKind { powerplay, middle, death, normal }

class ManhattanBar {
  const ManhattanBar({
    required this.overNumber,
    required this.runs,
    required this.phase,
    this.isHighest = false,
    this.isLowest = false,
  });

  final int overNumber;
  final int runs;
  final OverPhaseKind phase;
  final bool isHighest;
  final bool isLowest;
}

class ManhattanOverDetail {
  const ManhattanOverDetail({
    required this.overNumber,
    required this.runs,
    required this.wickets,
    required this.boundaryRuns,
    required this.singles,
    required this.legalBalls,
    required this.runRate,
    required this.phase,
  });

  final int overNumber;
  final int runs;
  final int wickets;
  final int boundaryRuns;
  final int singles;
  final int legalBalls;
  final double runRate;
  final OverPhaseKind phase;
}

class ManhattanInningsSeries {
  const ManhattanInningsSeries({
    required this.inningsNumber,
    required this.label,
    required this.shortLabel,
    required this.overs,
    required this.averageRunRate,
    this.bars = const [],
  });

  final int inningsNumber;
  final String label;
  final String shortLabel;
  final List<ManhattanOverDetail> overs;
  final double averageRunRate;
  /// Legacy bars retained for compatibility with older widgets/tests.
  final List<ManhattanBar> bars;
}

class ManhattanComparisonGroup {
  const ManhattanComparisonGroup({
    required this.overNumber,
    this.inningsA,
    this.inningsB,
  });

  final int overNumber;
  final ManhattanOverDetail? inningsA;
  final ManhattanOverDetail? inningsB;
}

class ManhattanMomentumInsights {
  const ManhattanMomentumInsights({
    this.highestScoringOverLabel = '—',
    this.mostEconomicalOverLabel = '—',
    this.bestBowlingPhaseLabel = '—',
    this.powerplayRunRateLabel = '—',
    this.deathOversRunRateLabel = '—',
  });

  final String highestScoringOverLabel;
  final String mostEconomicalOverLabel;
  final String bestBowlingPhaseLabel;
  final String powerplayRunRateLabel;
  final String deathOversRunRateLabel;
}

class ManhattanChartData {
  const ManhattanChartData({
    this.innings = const [],
    this.maxOverNumber = 0,
  });

  final List<ManhattanInningsSeries> innings;
  final int maxOverNumber;

  ManhattanInningsSeries? seriesForInnings(int inningsNumber) {
    for (final s in innings) {
      if (s.inningsNumber == inningsNumber) return s;
    }
    return null;
  }

  List<ManhattanComparisonGroup> comparisonGroups() {
    if (innings.isEmpty) return const [];
    final a = innings.isNotEmpty ? innings.first : null;
    final b = innings.length > 1 ? innings[1] : null;
    final maxOver = maxOverNumber.clamp(1, 999);
    final groups = <ManhattanComparisonGroup>[];
    for (var over = 1; over <= maxOver; over++) {
      groups.add(
        ManhattanComparisonGroup(
          overNumber: over,
          inningsA: a?.overs.where((o) => o.overNumber == over).firstOrNull,
          inningsB: b?.overs.where((o) => o.overNumber == over).firstOrNull,
        ),
      );
    }
    return groups;
  }

  ManhattanMomentumInsights insightsFor({
    ManhattanInningsSeries? primary,
    ManhattanInningsSeries? secondary,
    int ballsPerOver = 6,
    MatchPhaseRanges? phaseRanges,
    bool isTestMatch = false,
  }) {
    final overs = [
      if (primary != null) ...primary.overs,
      if (secondary != null) ...secondary.overs,
    ];
    if (overs.isEmpty) return const ManhattanMomentumInsights();

    ManhattanOverDetail? highest;
    ManhattanOverDetail? lowest;
    for (final o in overs) {
      if (highest == null || o.runs > highest.runs) highest = o;
      if (o.legalBalls > 0 &&
          (lowest == null || o.runs < lowest.runs)) {
        lowest = o;
      }
    }

    final phaseSources = [
      if (primary != null) primary,
      if (secondary != null) secondary,
    ];
    final phaseRuns = <OverPhaseKind, ({int runs, int legal})>{};
    for (final source in phaseSources) {
      for (final o in source.overs) {
        final cur = phaseRuns[o.phase] ?? (runs: 0, legal: 0);
        phaseRuns[o.phase] = (
          runs: cur.runs + o.runs,
          legal: cur.legal + o.legalBalls,
        );
      }
    }

    double phaseRr(OverPhaseKind kind) {
      final p = phaseRuns[kind];
      if (p == null || p.legal == 0) return 0;
      return (p.runs / p.legal) * ballsPerOver;
    }

    final ppLabel = phaseRanges?.powerplayLabel ?? 'Powerplay';
    final deathLabel = phaseRanges?.deathLabel ?? 'Death Overs';
    final window = phaseRanges?.momentumWindowSize ?? 4;

    return ManhattanMomentumInsights(
      highestScoringOverLabel: highest == null
          ? '—'
          : 'Over ${highest.overNumber} (${highest.runs} Runs)',
      mostEconomicalOverLabel: lowest == null
          ? '—'
          : 'Over ${lowest.overNumber} (${lowest.runs} Runs)',
      bestBowlingPhaseLabel: _bestBowlingPhaseLabel(
        (primary ?? innings.first).overs,
        window,
      ),
      powerplayRunRateLabel: isTestMatch || phaseRr(OverPhaseKind.powerplay) == 0
          ? '—'
          : '${phaseRr(OverPhaseKind.powerplay).toStringAsFixed(1)} · $ppLabel',
      deathOversRunRateLabel: isTestMatch || phaseRr(OverPhaseKind.death) == 0
          ? '—'
          : '${phaseRr(OverPhaseKind.death).toStringAsFixed(1)} · $deathLabel',
    );
  }

  String _bestBowlingPhaseLabel(List<ManhattanOverDetail> overs, int window) {
    if (overs.length < window) return '—';
    var bestStart = overs.first.overNumber;
    var bestTotal = 999999;
    for (var i = 0; i <= overs.length - window; i++) {
      final slice = overs.sublist(i, i + window);
      final total = slice.fold<int>(0, (s, o) => s + o.runs);
      if (total < bestTotal) {
        bestTotal = total;
        bestStart = slice.first.overNumber;
      }
    }
    final end = bestStart + window - 1;
    return 'Overs $bestStart-$end';
  }
}

class PartnershipAnalytics {
  const PartnershipAnalytics({
    required this.inningsNumber,
    required this.wicketNumber,
    required this.runs,
    required this.balls,
    required this.batterAId,
    required this.batterBId,
    required this.batterAName,
    required this.batterBName,
    required this.batterARuns,
    required this.batterABalls,
    required this.batterBRuns,
    required this.batterBBalls,
    this.isHighest = false,
  });

  final int inningsNumber;
  final int wicketNumber;
  final int runs;
  final int balls;
  final String batterAId;
  final String batterBId;
  final String batterAName;
  final String batterBName;
  final int batterARuns;
  final int batterABalls;
  final int batterBRuns;
  final int batterBBalls;
  final bool isHighest;

  double get batterAShare => runs == 0 ? 0.5 : batterARuns / runs;
  double get batterBShare => runs == 0 ? 0.5 : batterBRuns / runs;
}

class PartnershipSummary {
  const PartnershipSummary({
    this.highest = 0,
    this.average = 0,
    this.count = 0,
  });

  final int highest;
  final double average;
  final int count;
}

class PartnershipInningsGroup {
  const PartnershipInningsGroup({
    required this.inningsNumber,
    required this.label,
    required this.partnerships,
    required this.summary,
  });

  final int inningsNumber;
  final String label;
  final List<PartnershipAnalytics> partnerships;
  final PartnershipSummary summary;
}

class PhaseAnalytics {
  const PhaseAnalytics({
    required this.label,
    required this.runs,
    required this.wickets,
    required this.runRate,
    this.boundaries = 0,
    this.dotBallPercent = 0,
    this.strikeRate = 0,
    this.boundaryPercent = 0,
    this.strikeRotationPercent = 0,
  });

  final String label;
  final int runs;
  final int wickets;
  final double runRate;
  final int boundaries;
  final double dotBallPercent;
  final double strikeRate;
  final double boundaryPercent;
  final double strikeRotationPercent;
}

class BoundaryAnalytics {
  const BoundaryAnalytics({
    this.fours = 0,
    this.sixes = 0,
    this.boundaryRuns = 0,
    this.boundaryPercent = 0,
  });

  final int fours;
  final int sixes;
  final int boundaryRuns;
  final double boundaryPercent;
}

class BowlingImpactAnalytics {
  const BowlingImpactAnalytics({
    required this.playerId,
    required this.playerName,
    required this.oversLabel,
    required this.runs,
    required this.wickets,
    required this.economy,
    required this.dotBallPercent,
    required this.impactScore,
  });

  final String playerId;
  final String playerName;
  final String oversLabel;
  final int runs;
  final int wickets;
  final double economy;
  final double dotBallPercent;
  final double impactScore;
}

class ExtrasAnalytics {
  const ExtrasAnalytics({
    this.total = 0,
    this.wides = 0,
    this.noBalls = 0,
    this.byes = 0,
    this.legByes = 0,
    this.penalties = 0,
  });

  final int total;
  final int wides;
  final int noBalls;
  final int byes;
  final int legByes;
  final int penalties;

  double percentOf(int value) => total == 0 ? 0 : (value / total) * 100;
}

class DotBallAnalytics {
  const DotBallAnalytics({
    this.dotBalls = 0,
    this.scoringBalls = 0,
    this.dotBallPercent = 0,
    this.boundaryBallPercent = 0,
  });

  final int dotBalls;
  final int scoringBalls;
  final double dotBallPercent;
  final double boundaryBallPercent;
}

/// Test-match session block (approx. 30-over blocks per innings).
class TestSessionBlock {
  const TestSessionBlock({
    required this.label,
    required this.inningsLabel,
    required this.runs,
    required this.wickets,
    required this.runRate,
    required this.oversCompleted,
  });

  final String label;
  final String inningsLabel;
  final int runs;
  final int wickets;
  final double runRate;
  final int oversCompleted;
}

/// Stats for the new-ball / opening spell (first 10 overs).
class TestNewBallStats {
  const TestNewBallStats({
    required this.label,
    required this.inningsLabel,
    required this.runs,
    required this.wickets,
    required this.runRate,
    required this.boundaries,
    required this.dotBallPercent,
  });

  final String label;
  final String inningsLabel;
  final int runs;
  final int wickets;
  final double runRate;
  final int boundaries;
  final double dotBallPercent;
}

class TestBattingControlMetrics {
  const TestBattingControlMetrics({
    this.dotBallPercent = 0,
    this.strikeRate = 0,
    this.boundaryPercent = 0,
    this.scoringShotPercent = 0,
    this.controlLabel = '—',
  });

  final double dotBallPercent;
  final double strikeRate;
  final double boundaryPercent;
  final double scoringShotPercent;
  final String controlLabel;
}

class TestBowlingPressureMetrics {
  const TestBowlingPressureMetrics({
    this.dotBallPercent = 0,
    this.economyRate = 0,
    this.wickets = 0,
    this.topBowlerLabel = '—',
    this.pressureLabel = '—',
  });

  final double dotBallPercent;
  final double economyRate;
  final int wickets;
  final String topBowlerLabel;
  final String pressureLabel;
}

class TestMatchAnalytics {
  const TestMatchAnalytics({
    this.sessions = const [],
    this.newBall = const [],
    this.battingControl = const TestBattingControlMetrics(),
    this.bowlingPressure = const TestBowlingPressureMetrics(),
  });

  final List<TestSessionBlock> sessions;
  final List<TestNewBallStats> newBall;
  final TestBattingControlMetrics battingControl;
  final TestBowlingPressureMetrics bowlingPressure;

  bool get hasData =>
      sessions.isNotEmpty ||
      newBall.isNotEmpty ||
      battingControl.controlLabel != '—';
}

class PieSlice {
  const PieSlice({
    required this.label,
    required this.value,
    required this.colorArgb,
  });

  final String label;
  final double value;
  final int colorArgb;
}
