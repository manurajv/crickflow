import 'match_enums.dart';

class MatchListFilters {
  const MatchListFilters({
    this.query = '',
    this.statuses = const {},
    this.ballTypes = const {},
    this.matchTypes = const {},
    this.formats = const {},
    this.streaming,
    this.platforms = const {},
    this.country,
    this.stateProvince,
    this.city,
    this.from,
    this.to,
    this.includeDeleted = false,
    this.includeArchived = false,
  });

  final String query;
  final Set<ManagedMatchStatus> statuses;
  final Set<ManagedBallType> ballTypes;
  final Set<ManagedMatchType> matchTypes;
  final Set<ManagedCricketType> formats;
  final bool? streaming;
  final Set<ManagedStreamPlatform> platforms;
  final String? country;
  final String? stateProvince;
  final String? city;
  final DateTime? from;
  final DateTime? to;
  final bool includeDeleted;
  final bool includeArchived;

  bool get hasActiveFilters => query.trim().isNotEmpty || statuses.isNotEmpty || ballTypes.isNotEmpty || matchTypes.isNotEmpty || formats.isNotEmpty || streaming != null || platforms.isNotEmpty || (country?.isNotEmpty ?? false) || (stateProvince?.isNotEmpty ?? false) || (city?.isNotEmpty ?? false) || from != null || to != null || includeDeleted || includeArchived;

  MatchListFilters copyWith({
    String? query,
    Set<ManagedMatchStatus>? statuses,
    Set<ManagedBallType>? ballTypes,
    Set<ManagedMatchType>? matchTypes,
    Set<ManagedCricketType>? formats,
    bool? streaming,
    bool clearStreaming = false,
    Set<ManagedStreamPlatform>? platforms,
    String? country,
    String? stateProvince,
    String? city,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    bool? includeDeleted,
    bool? includeArchived,
  }) => MatchListFilters(
    query: query ?? this.query,
    statuses: statuses ?? this.statuses,
    ballTypes: ballTypes ?? this.ballTypes,
    matchTypes: matchTypes ?? this.matchTypes,
    formats: formats ?? this.formats,
    streaming: clearStreaming ? null : (streaming ?? this.streaming),
    platforms: platforms ?? this.platforms,
    country: country ?? this.country,
    stateProvince: stateProvince ?? this.stateProvince,
    city: city ?? this.city,
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
    includeDeleted: includeDeleted ?? this.includeDeleted,
    includeArchived: includeArchived ?? this.includeArchived,
  );

  static const empty = MatchListFilters();
}

enum MatchSortField { createdAt, title, scheduledAt, startedAt, status }

class MatchSort {
  const MatchSort({this.field = MatchSortField.createdAt, this.descending = true});
  final MatchSortField field;
  final bool descending;
  MatchSort toggle(MatchSortField next) => field == next ? MatchSort(field: next, descending: !descending) : MatchSort(field: next, descending: true);
}
