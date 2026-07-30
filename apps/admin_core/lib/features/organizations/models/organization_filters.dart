import 'organization_enums.dart';

class OrganizationListFilters {
  const OrganizationListFilters({
    this.query = '',
    this.statuses = const {},
    this.types = const {},
    this.country,
    this.stateProvince,
    this.city,
    this.registrationDateFrom,
    this.registrationDateTo,
    this.includeDeleted = false,
    this.includeArchived = false,
  });

  final String query;
  final Set<ManagedOrganizationStatus> statuses;
  final Set<ManagedOrganizationType> types;
  final String? country;
  final String? stateProvince;
  final String? city;
  final DateTime? registrationDateFrom;
  final DateTime? registrationDateTo;
  final bool includeDeleted;
  final bool includeArchived;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      types.isNotEmpty ||
      (country?.isNotEmpty ?? false) ||
      (stateProvince?.isNotEmpty ?? false) ||
      (city?.isNotEmpty ?? false) ||
      registrationDateFrom != null ||
      registrationDateTo != null ||
      includeDeleted ||
      includeArchived;

  OrganizationListFilters copyWith({
    String? query,
    Set<ManagedOrganizationStatus>? statuses,
    Set<ManagedOrganizationType>? types,
    String? country,
    String? stateProvince,
    String? city,
    DateTime? registrationDateFrom,
    DateTime? registrationDateTo,
    bool? includeDeleted,
    bool? includeArchived,
  }) {
    return OrganizationListFilters(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      types: types ?? this.types,
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      registrationDateFrom: registrationDateFrom ?? this.registrationDateFrom,
      registrationDateTo: registrationDateTo ?? this.registrationDateTo,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }

  static const empty = OrganizationListFilters();
}

enum OrganizationSortField { createdAt, name, type, city, status }

class OrganizationSort {
  const OrganizationSort({
    this.field = OrganizationSortField.createdAt,
    this.descending = true,
  });

  final OrganizationSortField field;
  final bool descending;

  OrganizationSort toggle(OrganizationSortField next) => field == next
      ? OrganizationSort(field: next, descending: !descending)
      : OrganizationSort(field: next);
}
