import 'team_enums.dart';

class TeamListFilters {
  const TeamListFilters({
    this.query = '',
    this.statuses = const {},
    this.ballTypes = const {},
    this.categories = const {},
    this.country,
    this.stateProvince,
    this.city,
    this.createdFrom,
    this.createdTo,
    this.minMembers,
    this.maxMembers,
    this.includeDeleted = false,
    this.includeArchived = false,
  });

  final String query;
  final Set<ManagedTeamStatus> statuses;
  final Set<ManagedTeamBallType> ballTypes;
  final Set<ManagedTeamCategory> categories;
  final String? country;
  final String? stateProvince;
  final String? city;
  final DateTime? createdFrom;
  final DateTime? createdTo;
  final int? minMembers;
  final int? maxMembers;
  final bool includeDeleted;
  final bool includeArchived;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      ballTypes.isNotEmpty ||
      categories.isNotEmpty ||
      (country?.isNotEmpty ?? false) ||
      (stateProvince?.isNotEmpty ?? false) ||
      (city?.isNotEmpty ?? false) ||
      createdFrom != null ||
      createdTo != null ||
      minMembers != null ||
      maxMembers != null ||
      includeDeleted ||
      includeArchived;

  TeamListFilters copyWith({
    String? query,
    Set<ManagedTeamStatus>? statuses,
    Set<ManagedTeamBallType>? ballTypes,
    Set<ManagedTeamCategory>? categories,
    String? country,
    String? stateProvince,
    String? city,
    DateTime? createdFrom,
    DateTime? createdTo,
    bool clearDates = false,
    int? minMembers,
    int? maxMembers,
    bool clearMembers = false,
    bool? includeDeleted,
    bool? includeArchived,
  }) {
    return TeamListFilters(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      ballTypes: ballTypes ?? this.ballTypes,
      categories: categories ?? this.categories,
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      createdFrom: clearDates ? null : (createdFrom ?? this.createdFrom),
      createdTo: clearDates ? null : (createdTo ?? this.createdTo),
      minMembers: clearMembers ? null : (minMembers ?? this.minMembers),
      maxMembers: clearMembers ? null : (maxMembers ?? this.maxMembers),
      includeDeleted: includeDeleted ?? this.includeDeleted,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }

  static const empty = TeamListFilters();
}

enum TeamSortField { createdAt, name, members, matches, winPct }

class TeamSort {
  const TeamSort({
    this.field = TeamSortField.createdAt,
    this.descending = true,
  });

  final TeamSortField field;
  final bool descending;

  TeamSort toggle(TeamSortField next) => field == next
      ? TeamSort(field: next, descending: !descending)
      : TeamSort(field: next);
}
