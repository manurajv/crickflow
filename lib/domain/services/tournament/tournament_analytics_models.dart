import 'package:equatable/equatable.dart';

import '../../../data/models/match_model.dart';
import 'tournament_hero_ranking_engine.dart';
import 'tournament_leaderboard_models.dart';

/// Filter scope for tournament analytics dashboards.
enum TournamentAnalyticsScope {
  tournament,
  round,
  group,
  leagueStage,
  knockoutStage,
}

class TournamentAnalyticsFilter extends Equatable {
  const TournamentAnalyticsFilter({
    this.scope = TournamentAnalyticsScope.tournament,
    this.groupId,
    this.roundId,
    this.scopeLabel = 'Entire tournament',
  });

  final TournamentAnalyticsScope scope;
  final String? groupId;
  final String? roundId;
  final String scopeLabel;

  @override
  List<Object?> get props => [scope, groupId, roundId];

  bool includesMatch(MatchModel match) {
    switch (scope) {
      case TournamentAnalyticsScope.tournament:
        return true;
      case TournamentAnalyticsScope.group:
        if (groupId == null || groupId!.isEmpty) return true;
        return match.groupId == groupId;
      case TournamentAnalyticsScope.round:
        if (roundId == null || roundId!.isEmpty) return true;
        return match.roundId == roundId;
      case TournamentAnalyticsScope.leagueStage:
        return match.bracketRound == null;
      case TournamentAnalyticsScope.knockoutStage:
        return match.bracketRound != null;
    }
  }
}

class StatsMetric extends Equatable {
  const StatsMetric({
    required this.label,
    required this.value,
    this.subtitle,
    this.iconName,
  });

  final String label;
  final String value;
  final String? subtitle;
  final String? iconName;

  @override
  List<Object?> get props => [label, value];
}

class StatsChartPoint extends Equatable {
  const StatsChartPoint({
    required this.label,
    required this.value,
    this.secondaryValue,
  });

  final String label;
  final double value;
  final double? secondaryValue;

  @override
  List<Object?> get props => [label, value];
}

class StatsChartSeries extends Equatable {
  const StatsChartSeries({
    required this.title,
    required this.points,
    this.kind = StatsChartKind.bar,
  });

  final String title;
  final List<StatsChartPoint> points;
  final StatsChartKind kind;

  @override
  List<Object?> get props => [title, points, kind];
}

enum StatsChartKind { bar, line, pie, trend }

enum TournamentStatsSectionId {
  summary,
  matchSummary,
  batting,
  bowling,
  fielding,
  team,
  boundaries,
  partnerships,
  extras,
  bowlingTypes,
  toss,
  venue,
  matchProgress,
  awards,
  charts,
}

extension TournamentStatsSectionIdX on TournamentStatsSectionId {
  String get title => switch (this) {
        TournamentStatsSectionId.summary => 'Tournament summary',
        TournamentStatsSectionId.matchSummary => 'Match summary',
        TournamentStatsSectionId.batting => 'Batting statistics',
        TournamentStatsSectionId.bowling => 'Bowling statistics',
        TournamentStatsSectionId.fielding => 'Fielding statistics',
        TournamentStatsSectionId.team => 'Team statistics',
        TournamentStatsSectionId.boundaries => 'Boundary statistics',
        TournamentStatsSectionId.partnerships => 'Partnership statistics',
        TournamentStatsSectionId.extras => 'Extras statistics',
        TournamentStatsSectionId.bowlingTypes => 'Bowling type analysis',
        TournamentStatsSectionId.toss => 'Toss statistics',
        TournamentStatsSectionId.venue => 'Venue statistics',
        TournamentStatsSectionId.matchProgress => 'Match progress',
        TournamentStatsSectionId.awards => 'Awards',
        TournamentStatsSectionId.charts => 'Charts',
      };

  String get iconName => switch (this) {
        TournamentStatsSectionId.summary => 'dashboard',
        TournamentStatsSectionId.matchSummary => 'sports_cricket',
        TournamentStatsSectionId.batting => 'sports_baseball',
        TournamentStatsSectionId.bowling => 'track_changes',
        TournamentStatsSectionId.fielding => 'front_hand',
        TournamentStatsSectionId.team => 'groups',
        TournamentStatsSectionId.boundaries => 'looks_4',
        TournamentStatsSectionId.partnerships => 'handshake',
        TournamentStatsSectionId.extras => 'add_circle_outline',
        TournamentStatsSectionId.bowlingTypes => 'pie_chart',
        TournamentStatsSectionId.toss => 'casino',
        TournamentStatsSectionId.venue => 'place',
        TournamentStatsSectionId.matchProgress => 'timeline',
        TournamentStatsSectionId.awards => 'emoji_events',
        TournamentStatsSectionId.charts => 'bar_chart',
      };
}

class TournamentSummarySection extends Equatable {
  const TournamentSummarySection({this.metrics = const []});

  final List<StatsMetric> metrics;

  @override
  List<Object?> get props => [metrics];
}

class TournamentMatchSummarySection extends Equatable {
  const TournamentMatchSummarySection({this.metrics = const []});

  final List<StatsMetric> metrics;

  @override
  List<Object?> get props => [metrics];
}

class TournamentSectionSnapshot extends Equatable {
  const TournamentSectionSnapshot({
    required this.id,
    this.metrics = const [],
    this.leaderboardPreview = const [],
    this.partnershipPreview = const [],
    this.tossInsights,
    this.primaryCategory,
    this.chartPreview,
  });

  final TournamentStatsSectionId id;
  final List<StatsMetric> metrics;
  final List<TournamentLeaderboardEntry> leaderboardPreview;
  final List<TournamentPartnershipEntry> partnershipPreview;
  final TournamentTossInsights? tossInsights;
  final TournamentLeaderboardCategory? primaryCategory;
  final StatsChartSeries? chartPreview;

  @override
  List<Object?> get props => [
        id,
        metrics.length,
        leaderboardPreview.length,
        partnershipPreview.length,
        tossInsights,
      ];
}

extension TournamentSectionSnapshotX on TournamentSectionSnapshot {
  bool get hasContent {
    if (metrics.isNotEmpty) return true;
    if (leaderboardPreview.isNotEmpty) return true;
    if (chartPreview != null && chartPreview!.points.isNotEmpty) return true;
    if (partnershipPreview.isNotEmpty) return true;
    if (tossInsights != null && tossInsights!.matchesWithToss > 0) return true;
    return false;
  }
}

class TournamentTossInsights extends Equatable {
  const TournamentTossInsights({
    this.matchesWithToss = 0,
    this.tossWinnerWins = 0,
    this.batFirstWins = 0,
    this.batFirstMatches = 0,
    this.chaseWins = 0,
    this.chaseMatches = 0,
  });

  final int matchesWithToss;
  final int tossWinnerWins;
  final int batFirstWins;
  final int batFirstMatches;
  final int chaseWins;
  final int chaseMatches;

  double get tossWinnerWinPct =>
      matchesWithToss > 0 ? (tossWinnerWins / matchesWithToss) * 100 : 0;

  double get batFirstWinPct =>
      batFirstMatches > 0 ? (batFirstWins / batFirstMatches) * 100 : 0;

  double get chaseWinPct =>
      chaseMatches > 0 ? (chaseWins / chaseMatches) * 100 : 0;

  int get tossWinnerLosses => matchesWithToss - tossWinnerWins;

  @override
  List<Object?> get props => [matchesWithToss, tossWinnerWins, chaseWins];
}

class TournamentPartnershipEntry extends Equatable {
  const TournamentPartnershipEntry({
    required this.matchLabel,
    required this.teamLabel,
    required this.inningsNumber,
    required this.wicketNumber,
    required this.runs,
    required this.balls,
    required this.batterAName,
    required this.batterBName,
    required this.batterARuns,
    required this.batterABalls,
    required this.batterBRuns,
    required this.batterBBalls,
  });

  final String matchLabel;
  final String teamLabel;
  final int inningsNumber;
  final int wicketNumber;
  final int runs;
  final int balls;
  final String batterAName;
  final String batterBName;
  final int batterARuns;
  final int batterABalls;
  final int batterBRuns;
  final int batterBBalls;

  double get batterAShare => runs == 0 ? 0.5 : batterARuns / runs;
  double get batterBShare => runs == 0 ? 0.5 : batterBRuns / runs;

  String get inningsLabel =>
      'Innings $inningsNumber · Wkt ${wicketNumber + 1} stand';

  String get batterALine => '$batterAName ${batterARuns}($batterABalls)';
  String get batterBLine => '$batterBName ${batterBRuns}($batterBBalls)';

  @override
  List<Object?> get props => [matchLabel, runs, batterAName, batterBName];
}

class TournamentPlayerMatchLog extends Equatable {
  const TournamentPlayerMatchLog({
    required this.matchId,
    required this.opponentLabel,
    required this.runs,
    required this.balls,
    required this.wickets,
    required this.oversBowled,
    this.isNotOut = false,
    this.matchDate,
  });

  final String matchId;
  final String opponentLabel;
  final int runs;
  final int balls;
  final int wickets;
  final int oversBowled;
  final bool isNotOut;
  final DateTime? matchDate;

  @override
  List<Object?> get props => [matchId, runs, wickets];
}

class TournamentPlayerStatsDetail extends Equatable {
  const TournamentPlayerStatsDetail({
    required this.playerId,
    required this.playerName,
    this.teamName = '',
    this.battingMetrics = const [],
    this.bowlingMetrics = const [],
    this.fieldingMetrics = const [],
    this.matchLogs = const [],
    this.runsChart = const [],
    this.wicketsChart = const [],
    this.awards = const [],
  });

  final String playerId;
  final String playerName;
  final String teamName;
  final List<StatsMetric> battingMetrics;
  final List<StatsMetric> bowlingMetrics;
  final List<StatsMetric> fieldingMetrics;
  final List<TournamentPlayerMatchLog> matchLogs;
  final List<StatsChartPoint> runsChart;
  final List<StatsChartPoint> wicketsChart;
  final List<TournamentHeroEntry> awards;

  @override
  List<Object?> get props => [playerId, playerName];
}

class TournamentAnalyticsSnapshot extends Equatable {
  const TournamentAnalyticsSnapshot({
    this.filter = const TournamentAnalyticsFilter(),
    this.hasData = false,
    this.summary = const TournamentSummarySection(),
    this.matchSummary = const TournamentMatchSummarySection(),
    this.sections = const {},
    this.leaderboards = const {},
    this.charts = const [],
    this.awards = const TournamentHeroesSnapshot(),
    this.playerDetails = const {},
    this.matchCount = 0,
    this.scoredMatchCount = 0,
    this.updatedAt,
  });

  final TournamentAnalyticsFilter filter;
  final bool hasData;
  final TournamentSummarySection summary;
  final TournamentMatchSummarySection matchSummary;
  final Map<TournamentStatsSectionId, TournamentSectionSnapshot> sections;
  final Map<TournamentLeaderboardCategory, List<TournamentLeaderboardEntry>>
      leaderboards;
  final List<StatsChartSeries> charts;
  final TournamentHeroesSnapshot awards;
  final Map<String, TournamentPlayerStatsDetail> playerDetails;
  final int matchCount;
  final int scoredMatchCount;
  final DateTime? updatedAt;

  List<TournamentLeaderboardEntry> entriesFor(
    TournamentLeaderboardCategory category, {
    int limit = 5,
  }) =>
      (leaderboards[category] ?? const []).take(limit).toList();

  TournamentPlayerStatsDetail? playerDetail(String playerId) =>
      playerDetails[playerId];

  @override
  List<Object?> get props => [
        filter,
        hasData,
        matchCount,
        scoredMatchCount,
        leaderboards.length,
        updatedAt,
      ];
}
