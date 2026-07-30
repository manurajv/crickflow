import 'package:equatable/equatable.dart';

import 'analytics_enums.dart';
import 'analytics_filters.dart';

/// KPI card with period-over-period change.
class AnalyticsKpi extends Equatable {
  const AnalyticsKpi({
    required this.id,
    required this.label,
    required this.value,
    this.previousValue = 0,
    this.unit = '',
    this.subtitle,
  });

  final String id;
  final String label;
  final num value;
  final num previousValue;
  final String unit;
  final String? subtitle;

  double get changePercent {
    if (previousValue == 0) {
      return value == 0 ? 0 : 100;
    }
    return ((value - previousValue) / previousValue) * 100;
  }

  bool get isUp => changePercent >= 0;

  String get formattedValue {
    if (value is double) {
      final d = value.toDouble();
      if (d >= 1000000) return '${(d / 1000000).toStringAsFixed(1)}M';
      if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}K';
      return d.toStringAsFixed(d.truncateToDouble() == d ? 0 : 1);
    }
    final i = value.toInt();
    if (i >= 1000000) return '${(i / 1000000).toStringAsFixed(1)}M';
    if (i >= 1000) return '${(i / 1000).toStringAsFixed(1)}K';
    return '$i';
  }

  @override
  List<Object?> get props => [id, value, previousValue];
}

class AnalyticsSeriesPoint extends Equatable {
  const AnalyticsSeriesPoint({required this.label, required this.value});

  final String label;
  final double value;

  @override
  List<Object?> get props => [label, value];
}

class AnalyticsNamedValue extends Equatable {
  const AnalyticsNamedValue({
    required this.name,
    required this.value,
    this.subtitle,
    this.id,
  });

  final String? id;
  final String name;
  final num value;
  final String? subtitle;

  @override
  List<Object?> get props => [id, name, value];
}

class AnalyticsRealtimeSnapshot extends Equatable {
  const AnalyticsRealtimeSnapshot({
    this.usersOnline = 0,
    this.matchesLive = 0,
    this.streamsRunning = 0,
    this.notificationsSentToday = 0,
    this.postsCreatedToday = 0,
    this.reportsReceivedToday = 0,
    this.updatedAt,
  });

  final int usersOnline;
  final int matchesLive;
  final int streamsRunning;
  final int notificationsSentToday;
  final int postsCreatedToday;
  final int reportsReceivedToday;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
        usersOnline,
        matchesLive,
        streamsRunning,
        notificationsSentToday,
        postsCreatedToday,
        reportsReceivedToday,
      ];
}

/// Full analytics payload for the hub (read-only; never mutates platform data).
class AnalyticsSnapshot extends Equatable {
  const AnalyticsSnapshot({
    required this.filters,
    required this.generatedAt,
    required this.scoped,
    required this.organizationId,
    required this.overviewKpis,
    required this.realtime,
    required this.dauSeries,
    required this.mauSeries,
    required this.registrationsSeries,
    required this.matchesPerDaySeries,
    required this.streamsPerDaySeries,
    required this.tournamentGrowthSeries,
    required this.communityActivitySeries,
    required this.adPerformanceSeries,
    required this.userAnalytics,
    required this.matchAnalytics,
    required this.tournamentAnalytics,
    required this.teamAnalytics,
    required this.playerAnalytics,
    required this.streamingAnalytics,
    required this.communityAnalytics,
    required this.adAnalytics,
    required this.revenueAnalytics,
    this.dataQualityNote,
    this.fromCache = false,
  });

  final AnalyticsFilters filters;
  final DateTime generatedAt;
  final bool scoped;
  final String? organizationId;
  final List<AnalyticsKpi> overviewKpis;
  final AnalyticsRealtimeSnapshot realtime;
  final List<AnalyticsSeriesPoint> dauSeries;
  final List<AnalyticsSeriesPoint> mauSeries;
  final List<AnalyticsSeriesPoint> registrationsSeries;
  final List<AnalyticsSeriesPoint> matchesPerDaySeries;
  final List<AnalyticsSeriesPoint> streamsPerDaySeries;
  final List<AnalyticsSeriesPoint> tournamentGrowthSeries;
  final List<AnalyticsSeriesPoint> communityActivitySeries;
  final List<AnalyticsSeriesPoint> adPerformanceSeries;
  final UserAnalyticsBlock userAnalytics;
  final MatchAnalyticsBlock matchAnalytics;
  final TournamentAnalyticsBlock tournamentAnalytics;
  final TeamAnalyticsBlock teamAnalytics;
  final PlayerAnalyticsBlock playerAnalytics;
  final StreamingAnalyticsBlock streamingAnalytics;
  final CommunityAnalyticsBlock communityAnalytics;
  final AdAnalyticsBlock adAnalytics;
  final RevenueAnalyticsBlock revenueAnalytics;
  final String? dataQualityNote;
  final bool fromCache;

  @override
  List<Object?> get props => [generatedAt, scoped, organizationId, fromCache];
}

class UserAnalyticsBlock extends Equatable {
  const UserAnalyticsBlock({
    this.kpis = const [],
    this.growthSeries = const [],
    this.byCountry = const [],
    this.byState = const [],
    this.byCity = const [],
    this.loginMethods = const [],
    this.platforms = const [],
    this.mostActive = const [],
    this.mostFollowedPlayers = const [],
    this.mostFollowedTeams = const [],
  });

  final List<AnalyticsKpi> kpis;
  final List<AnalyticsSeriesPoint> growthSeries;
  final List<AnalyticsNamedValue> byCountry;
  final List<AnalyticsNamedValue> byState;
  final List<AnalyticsNamedValue> byCity;
  final List<AnalyticsNamedValue> loginMethods;
  final List<AnalyticsNamedValue> platforms;
  final List<AnalyticsNamedValue> mostActive;
  final List<AnalyticsNamedValue> mostFollowedPlayers;
  final List<AnalyticsNamedValue> mostFollowedTeams;

  @override
  List<Object?> get props => [kpis, growthSeries];
}

class MatchAnalyticsBlock extends Equatable {
  const MatchAnalyticsBlock({
    this.kpis = const [],
    this.byStatus = const [],
    this.series = const [],
  });

  final List<AnalyticsKpi> kpis;
  final List<AnalyticsNamedValue> byStatus;
  final List<AnalyticsSeriesPoint> series;

  @override
  List<Object?> get props => [kpis];
}

class TournamentAnalyticsBlock extends Equatable {
  const TournamentAnalyticsBlock({
    this.kpis = const [],
    this.growthSeries = const [],
    this.topTournaments = const [],
  });

  final List<AnalyticsKpi> kpis;
  final List<AnalyticsSeriesPoint> growthSeries;
  final List<AnalyticsNamedValue> topTournaments;

  @override
  List<Object?> get props => [kpis];
}

class TeamAnalyticsBlock extends Equatable {
  const TeamAnalyticsBlock({
    this.kpis = const [],
    this.mostActive = const [],
    this.mostFollowed = const [],
    this.highestWinning = const [],
  });

  final List<AnalyticsKpi> kpis;
  final List<AnalyticsNamedValue> mostActive;
  final List<AnalyticsNamedValue> mostFollowed;
  final List<AnalyticsNamedValue> highestWinning;

  @override
  List<Object?> get props => [kpis];
}

class PlayerAnalyticsBlock extends Equatable {
  const PlayerAnalyticsBlock({
    this.kpis = const [],
    this.topRunScorers = const [],
    this.topWicketTakers = const [],
    this.mostFollowed = const [],
    this.note =
        'Career batting/bowling stats require BigQuery / warehouse joins; '
        'lists below use available profile signals.',
  });

  final List<AnalyticsKpi> kpis;
  final List<AnalyticsNamedValue> topRunScorers;
  final List<AnalyticsNamedValue> topWicketTakers;
  final List<AnalyticsNamedValue> mostFollowed;
  final String note;

  @override
  List<Object?> get props => [kpis];
}

class StreamingAnalyticsBlock extends Equatable {
  const StreamingAnalyticsBlock({
    this.kpis = const [],
    this.byPlatform = const [],
    this.series = const [],
  });

  final List<AnalyticsKpi> kpis;
  final List<AnalyticsNamedValue> byPlatform;
  final List<AnalyticsSeriesPoint> series;

  @override
  List<Object?> get props => [kpis];
}

class CommunityAnalyticsBlock extends Equatable {
  const CommunityAnalyticsBlock({
    this.kpis = const [],
    this.series = const [],
    this.topPosts = const [],
  });

  final List<AnalyticsKpi> kpis;
  final List<AnalyticsSeriesPoint> series;
  final List<AnalyticsNamedValue> topPosts;

  @override
  List<Object?> get props => [kpis];
}

class AdAnalyticsBlock extends Equatable {
  const AdAnalyticsBlock({
    this.kpis = const [],
    this.series = const [],
    this.topPlacements = const [],
    this.topAdvertisers = const [],
    this.note =
        'Impressions / CTR are future-ready for AdMob API; figures are '
        'campaign inventory estimates from admin ads collections.',
  });

  final List<AnalyticsKpi> kpis;
  final List<AnalyticsSeriesPoint> series;
  final List<AnalyticsNamedValue> topPlacements;
  final List<AnalyticsNamedValue> topAdvertisers;
  final String note;

  @override
  List<Object?> get props => [kpis];
}

class RevenueAnalyticsBlock extends Equatable {
  const RevenueAnalyticsBlock({
    this.kpis = const [],
    this.breakdown = const [],
    this.series = const [],
    this.note =
        'Revenue analytics is architecture-ready only — no payment gateway. '
        'Values are estimated placeholders for BI / Stripe / AdMob later.',
  });

  final List<AnalyticsKpi> kpis;
  final List<AnalyticsNamedValue> breakdown;
  final List<AnalyticsSeriesPoint> series;
  final String note;

  @override
  List<Object?> get props => [kpis];
}

class AnalyticsReportPreview extends Equatable {
  const AnalyticsReportPreview({
    required this.kind,
    required this.title,
    required this.summaryLines,
    required this.generatedAt,
  });

  final AnalyticsReportKind kind;
  final String title;
  final List<String> summaryLines;
  final DateTime generatedAt;

  @override
  List<Object?> get props => [kind, title, generatedAt];
}
