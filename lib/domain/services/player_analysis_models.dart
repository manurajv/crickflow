import '../../core/constants/enums.dart';
import 'player_cricket_profile_models.dart';

/// Minimum completed matches before showing charts.
const kAnalysisMinMatches = 3;

/// Reusable metric bucket for batting/bowling breakdowns.
class AnalysisMetricBucket {
  const AnalysisMetricBucket({
    required this.label,
    this.matches = 0,
    this.innings = 0,
    this.runs = 0,
    this.balls = 0,
    this.wickets = 0,
    this.dismissals = 0,
    this.oversBalls = 0,
    this.runsConceded = 0,
    this.fours = 0,
    this.sixes = 0,
    this.dots = 0,
    this.boundaries = 0,
    this.fifties = 0,
    this.hundreds = 0,
    this.highScore = 0,
  });

  final String label;
  final int matches;
  final int innings;
  final int runs;
  final int balls;
  final int wickets;
  final int dismissals;
  final int oversBalls;
  final int runsConceded;
  final int fours;
  final int sixes;
  final int dots;
  final int boundaries;

  final int fifties;
  final int hundreds;
  final int highScore;

  double get average => dismissals == 0 ? runs.toDouble() : runs / dismissals;

  double get strikeRate => balls == 0 ? 0 : (runs / balls) * 100;

  double get economy {
    if (oversBalls == 0) return 0;
    final overs = oversBalls / 6;
    return runsConceded / overs;
  }

  double get bowlingAverage =>
      wickets == 0 ? 0 : runsConceded / wickets;

  double get bowlingStrikeRate =>
      wickets == 0 ? 0 : oversBalls / wickets;

  double get boundaryPct => balls == 0 ? 0 : (boundaries / balls) * 100;

  double get dotPct => balls == 0 ? 0 : (dots / balls) * 100;

  AnalysisMetricBucket merge(AnalysisMetricBucket other) => AnalysisMetricBucket(
        label: label,
        matches: matches + other.matches,
        innings: innings + other.innings,
        runs: runs + other.runs,
        balls: balls + other.balls,
        wickets: wickets + other.wickets,
        dismissals: dismissals + other.dismissals,
        oversBalls: oversBalls + other.oversBalls,
        runsConceded: runsConceded + other.runsConceded,
        fours: fours + other.fours,
        sixes: sixes + other.sixes,
        dots: dots + other.dots,
        boundaries: boundaries + other.boundaries,
        fifties: fifties + other.fifties,
        hundreds: hundreds + other.hundreds,
        highScore: highScore > other.highScore ? highScore : other.highScore,
      );
}

class RunDistribution {
  const RunDistribution({
    this.singles = 0,
    this.doubles = 0,
    this.triples = 0,
    this.fours = 0,
    this.sixes = 0,
    this.dots = 0,
    this.totalBalls = 0,
  });

  final int singles;
  final int doubles;
  final int triples;
  final int fours;
  final int sixes;
  final int dots;
  final int totalBalls;

  double pct(int value) =>
      totalBalls == 0 ? 0 : (value / totalBalls) * 100;

  bool get hasData => totalBalls >= 6;
}

class ScoringZoneStats {
  const ScoringZoneStats({
    this.zones = const {},
    this.favoriteZone = '',
    this.weakestZone = '',
    this.totalRuns = 0,
  });

  final Map<String, int> zones;
  final String favoriteZone;
  final String weakestZone;
  final int totalRuns;

  double zonePct(String zone) {
    if (totalRuns == 0) return 0;
    return ((zones[zone] ?? 0) / totalRuns) * 100;
  }

  bool get hasData => totalRuns > 0;
}

class DismissalBreakdown {
  const DismissalBreakdown({this.counts = const {}});

  final Map<String, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);

  double pct(String key) {
    final t = total;
    if (t == 0) return 0;
    return ((counts[key] ?? 0) / t) * 100;
  }

  bool get hasData => total > 0;
}

class FormWindowStats {
  const FormWindowStats({
    required this.label,
    this.runs = 0,
    this.wickets = 0,
    this.balls = 0,
    this.oversBalls = 0,
    this.runsConceded = 0,
    this.innings = 0,
    this.matches = 0,
  });

  final String label;
  final int runs;
  final int wickets;
  final int balls;
  final int oversBalls;
  final int runsConceded;
  final int innings;
  final int matches;

  double get strikeRate => balls == 0 ? 0 : (runs / balls) * 100;

  double get economy {
    if (oversBalls == 0) return 0;
    return runsConceded / (oversBalls / 6);
  }

  double get average => innings == 0 ? 0 : runs / innings;
}

class YearlyProgression {
  const YearlyProgression({
    required this.year,
    this.runs = 0,
    this.wickets = 0,
    this.matches = 0,
    this.innings = 0,
    this.balls = 0,
    this.oversBalls = 0,
  });

  final int year;
  final int runs;
  final int wickets;
  final int matches;
  final int innings;
  final int balls;
  final int oversBalls;

  double get strikeRate => balls == 0 ? 0 : (runs / balls) * 100;

  double get average => innings == 0 ? 0 : runs / innings;
}

class ConsistencyStats {
  const ConsistencyStats({
    this.scores = const [],
    this.ducks = 0,
  });

  final List<int> scores;
  final int ducks;

  double get average =>
      scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length;

  double get median {
    if (scores.isEmpty) return 0;
    final sorted = [...scores]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid].toDouble();
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  int get thirtiesPlus => scores.where((s) => s >= 30).length;

  int get fiftiesPlus => scores.where((s) => s >= 50).length;

  int get hundredsPlus => scores.where((s) => s >= 100).length;

  double get duckPct =>
      scores.isEmpty ? 0 : (ducks / scores.length) * 100;

  double get conversionRate =>
      scores.isEmpty ? 0 : (fiftiesPlus / scores.length) * 100;

  bool get hasData => scores.length >= 3;
}

class FieldingAnalysis {
  const FieldingAnalysis({
    this.catches = 0,
    this.runOuts = 0,
    this.directHits = 0,
    this.stumpings = 0,
    this.missedChances = 0,
    this.catchAttempts = 0,
    this.runOutAttempts = 0,
  });

  final int catches;
  final int runOuts;
  final int directHits;
  final int stumpings;
  final int missedChances;
  final int catchAttempts;
  final int runOutAttempts;

  int get totalDismissals => catches + runOuts + stumpings;

  double get catchSuccessPct =>
      catchAttempts == 0 ? 0 : (catches / catchAttempts) * 100;

  double get runOutConversionPct =>
      runOutAttempts == 0 ? 0 : (runOuts / runOutAttempts) * 100;

  double get safeHandsRating {
    if (catchAttempts == 0) return 0;
    return (catchSuccessPct / 20).clamp(0, 5);
  }

  bool get hasData => totalDismissals > 0 || missedChances > 0;
}

enum FormTrend { excellent, good, average, poor, improving, declining, stable }

enum CareerTrend { improving, declining, stable }

class PlayerSummaryAnalysis {
  const PlayerSummaryAnalysis({
    this.battingCluster,
    this.bowlingCluster,
    this.primaryStrength = '',
    this.secondaryStrength = '',
    this.currentForm = FormTrend.average,
    this.careerTrend = CareerTrend.stable,
    this.formLabel = 'Average',
    this.trendLabel = 'Stable',
  });

  final BattingClusterType? battingCluster;
  final BowlingClusterType? bowlingCluster;
  final String primaryStrength;
  final String secondaryStrength;
  final FormTrend currentForm;
  final CareerTrend careerTrend;
  final String formLabel;
  final String trendLabel;
}

/// Full advanced analysis snapshot — structured for future player comparison.
class PlayerAdvancedAnalysisSnapshot {
  const PlayerAdvancedAnalysisSnapshot({
    this.hasEnoughData = false,
    this.completedMatches = 0,
    this.summary = const PlayerSummaryAnalysis(),
    this.clusters = const PlayerClusters(),
    this.runDistribution = const RunDistribution(),
    this.scoringZones = const ScoringZoneStats(),
    this.battingVsBowlingType = const [],
    this.battingPhases = const [],
    this.battingDismissals = const DismissalBreakdown(),
    this.chaseBatting = const AnalysisMetricBucket(label: 'Batting Second'),
    this.defendBatting = const AnalysisMetricBucket(label: 'Batting First'),
    this.bowlingDismissals = const DismissalBreakdown(),
    this.bowlingVsHand = const [],
    this.wicketsByPosition = const [],
    this.bowlingPhases = const [],
    this.fielding = const FieldingAnalysis(),
    this.captaincy = CaptainStatsSnapshot.empty,
    this.bestOpponents = const [],
    this.worstOpponents = const [],
    this.topOpponents = const [],
    this.situations = const [],
    this.formWindows = const [],
    this.consistency = const ConsistencyStats(),
    this.yearlyProgression = const [],
    this.formSeries = const [],
    this.heatZones = const {},
    this.wicketHeatZones = const {},
  });

  final bool hasEnoughData;
  final int completedMatches;
  final PlayerSummaryAnalysis summary;
  final PlayerClusters clusters;
  final RunDistribution runDistribution;
  final ScoringZoneStats scoringZones;
  final List<AnalysisMetricBucket> battingVsBowlingType;
  final List<AnalysisMetricBucket> battingPhases;
  final DismissalBreakdown battingDismissals;
  final AnalysisMetricBucket chaseBatting;
  final AnalysisMetricBucket defendBatting;
  final DismissalBreakdown bowlingDismissals;
  final List<AnalysisMetricBucket> bowlingVsHand;
  final List<AnalysisMetricBucket> wicketsByPosition;
  final List<AnalysisMetricBucket> bowlingPhases;
  final FieldingAnalysis fielding;
  final CaptainStatsSnapshot captaincy;
  final List<AnalysisMetricBucket> bestOpponents;
  final List<AnalysisMetricBucket> worstOpponents;
  final List<AnalysisMetricBucket> topOpponents;
  final List<AnalysisMetricBucket> situations;
  final List<FormWindowStats> formWindows;
  final ConsistencyStats consistency;
  final List<YearlyProgression> yearlyProgression;
  final List<({DateTime date, double runs, double wickets, double sr, double econ})>
      formSeries;
  final Map<String, int> heatZones;
  final Map<String, int> wicketHeatZones;

  static const empty = PlayerAdvancedAnalysisSnapshot();
}
