import 'tournament_enums.dart';

class TournamentListFilters {
  const TournamentListFilters({
    this.query = '',
    this.statuses = const {},
    this.formats = const {},
    this.ballTypes = const {},
    this.featured,
    this.paidEntry,
    this.country,
    this.stateProvince,
    this.city,
    this.startFrom,
    this.startTo,
    this.includeDeleted = false,
    this.includeArchived = false,
    this.approvals = const {},
  });

  final String query;
  final Set<ManagedTournamentStatus> statuses;
  final Set<ManagedTournamentFormat> formats;
  final Set<ManagedBallType> ballTypes;
  final bool? featured;
  /// null = any, true = paid, false = free
  final bool? paidEntry;
  final String? country;
  final String? stateProvince;
  final String? city;
  final DateTime? startFrom;
  final DateTime? startTo;
  final bool includeDeleted;
  final bool includeArchived;
  final Set<AdminTournamentApproval> approvals;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      formats.isNotEmpty ||
      ballTypes.isNotEmpty ||
      featured != null ||
      paidEntry != null ||
      (country?.isNotEmpty ?? false) ||
      (stateProvince?.isNotEmpty ?? false) ||
      (city?.isNotEmpty ?? false) ||
      startFrom != null ||
      startTo != null ||
      includeDeleted ||
      includeArchived ||
      approvals.isNotEmpty;

  TournamentListFilters copyWith({
    String? query,
    Set<ManagedTournamentStatus>? statuses,
    Set<ManagedTournamentFormat>? formats,
    Set<ManagedBallType>? ballTypes,
    bool? featured,
    bool clearFeatured = false,
    bool? paidEntry,
    bool clearPaid = false,
    String? country,
    String? stateProvince,
    String? city,
    DateTime? startFrom,
    DateTime? startTo,
    bool clearDates = false,
    bool? includeDeleted,
    bool? includeArchived,
    Set<AdminTournamentApproval>? approvals,
  }) {
    return TournamentListFilters(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      formats: formats ?? this.formats,
      ballTypes: ballTypes ?? this.ballTypes,
      featured: clearFeatured ? null : (featured ?? this.featured),
      paidEntry: clearPaid ? null : (paidEntry ?? this.paidEntry),
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      startFrom: clearDates ? null : (startFrom ?? this.startFrom),
      startTo: clearDates ? null : (startTo ?? this.startTo),
      includeDeleted: includeDeleted ?? this.includeDeleted,
      includeArchived: includeArchived ?? this.includeArchived,
      approvals: approvals ?? this.approvals,
    );
  }

  static const empty = TournamentListFilters();
}

enum TournamentSortField {
  createdAt,
  name,
  startDate,
  endDate,
  status,
}

class TournamentSort {
  const TournamentSort({
    this.field = TournamentSortField.createdAt,
    this.descending = true,
  });

  final TournamentSortField field;
  final bool descending;

  TournamentSort toggle(TournamentSortField next) {
    if (field == next) {
      return TournamentSort(field: next, descending: !descending);
    }
    return TournamentSort(field: next, descending: true);
  }
}
