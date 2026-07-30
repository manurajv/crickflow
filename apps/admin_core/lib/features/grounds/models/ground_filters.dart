import 'ground_enums.dart';

class GroundListFilters {
  const GroundListFilters({
    this.query = '',
    this.statuses = const {},
    this.groundTypes = const {},
    this.ballTypes = const {},
    this.pitchTypes = const {},
    this.availabilities = const {},
    this.country,
    this.stateProvince,
    this.city,
    this.includeDeleted = false,
    this.includeArchived = false,
  });

  final String query;
  final Set<ManagedGroundStatus> statuses;
  final Set<ManagedGroundType> groundTypes;
  final Set<ManagedGroundBallType> ballTypes;
  final Set<ManagedGroundPitchType> pitchTypes;
  final Set<ManagedGroundAvailability> availabilities;
  final String? country;
  final String? stateProvince;
  final String? city;
  final bool includeDeleted;
  final bool includeArchived;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      groundTypes.isNotEmpty ||
      ballTypes.isNotEmpty ||
      pitchTypes.isNotEmpty ||
      availabilities.isNotEmpty ||
      (country?.isNotEmpty ?? false) ||
      (stateProvince?.isNotEmpty ?? false) ||
      (city?.isNotEmpty ?? false) ||
      includeDeleted ||
      includeArchived;

  GroundListFilters copyWith({
    String? query,
    Set<ManagedGroundStatus>? statuses,
    Set<ManagedGroundType>? groundTypes,
    Set<ManagedGroundBallType>? ballTypes,
    Set<ManagedGroundPitchType>? pitchTypes,
    Set<ManagedGroundAvailability>? availabilities,
    String? country,
    String? stateProvince,
    String? city,
    bool? includeDeleted,
    bool? includeArchived,
  }) {
    return GroundListFilters(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      groundTypes: groundTypes ?? this.groundTypes,
      ballTypes: ballTypes ?? this.ballTypes,
      pitchTypes: pitchTypes ?? this.pitchTypes,
      availabilities: availabilities ?? this.availabilities,
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }

  static const empty = GroundListFilters();
}

enum GroundSortField { createdAt, name, city, matchesHosted, rating }

class GroundSort {
  const GroundSort({
    this.field = GroundSortField.createdAt,
    this.descending = true,
  });

  final GroundSortField field;
  final bool descending;

  GroundSort toggle(GroundSortField next) => field == next
      ? GroundSort(field: next, descending: !descending)
      : GroundSort(field: next);
}
