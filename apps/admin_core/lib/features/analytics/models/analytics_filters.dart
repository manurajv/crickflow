import 'analytics_enums.dart';

class AnalyticsFilters {
  const AnalyticsFilters({
    this.period = AnalyticsPeriod.monthly,
    this.from,
    this.to,
    this.country,
    this.stateProvince,
    this.city,
    this.organizationId,
    this.tournamentId,
    this.matchType,
    this.ballType,
    this.streamingPlatform,
  });

  final AnalyticsPeriod period;
  final DateTime? from;
  final DateTime? to;
  final String? country;
  final String? stateProvince;
  final String? city;
  /// Super Admin may filter to one org; Org Admin is always forced to their org.
  final String? organizationId;
  final String? tournamentId;
  final String? matchType;
  final String? ballType;
  final String? streamingPlatform;

  bool get hasActiveFilters =>
      period != AnalyticsPeriod.monthly ||
      from != null ||
      to != null ||
      (country?.isNotEmpty ?? false) ||
      (stateProvince?.isNotEmpty ?? false) ||
      (city?.isNotEmpty ?? false) ||
      (organizationId?.isNotEmpty ?? false) ||
      (tournamentId?.isNotEmpty ?? false) ||
      (matchType?.isNotEmpty ?? false) ||
      (ballType?.isNotEmpty ?? false) ||
      (streamingPlatform?.isNotEmpty ?? false);

  /// Resolved inclusive date window for the selected period.
  ({DateTime start, DateTime end}) resolveRange({DateTime? now}) {
    final n = now ?? DateTime.now();
    final end = to ?? DateTime(n.year, n.month, n.day, 23, 59, 59);
    if (period == AnalyticsPeriod.custom && from != null) {
      return (start: from!, end: end);
    }
    final start = switch (period) {
      AnalyticsPeriod.daily => DateTime(n.year, n.month, n.day),
      AnalyticsPeriod.weekly => n.subtract(const Duration(days: 7)),
      AnalyticsPeriod.monthly => n.subtract(const Duration(days: 30)),
      AnalyticsPeriod.yearly => n.subtract(const Duration(days: 365)),
      AnalyticsPeriod.custom => from ?? n.subtract(const Duration(days: 30)),
    };
    return (start: start, end: end);
  }

  ({DateTime start, DateTime end}) previousRange() {
    final current = resolveRange();
    final duration = current.end.difference(current.start);
    final prevEnd = current.start.subtract(const Duration(seconds: 1));
    final prevStart = prevEnd.subtract(duration);
    return (start: prevStart, end: prevEnd);
  }

  AnalyticsFilters copyWith({
    AnalyticsPeriod? period,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
    String? country,
    String? stateProvince,
    String? city,
    String? organizationId,
    String? tournamentId,
    String? matchType,
    String? ballType,
    String? streamingPlatform,
    bool clearOrganizationId = false,
  }) {
    return AnalyticsFilters(
      period: period ?? this.period,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      organizationId: clearOrganizationId
          ? null
          : (organizationId ?? this.organizationId),
      tournamentId: tournamentId ?? this.tournamentId,
      matchType: matchType ?? this.matchType,
      ballType: ballType ?? this.ballType,
      streamingPlatform: streamingPlatform ?? this.streamingPlatform,
    );
  }

  static const empty = AnalyticsFilters();
}
