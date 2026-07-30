import 'support_enums.dart';

class SupportListFilters {
  const SupportListFilters({
    this.query = '',
    this.statuses = const {},
    this.priorities = const {},
    this.categories = const {},
    this.kinds = const {},
    this.assignedToUid,
    this.organizationId,
    this.country,
    this.stateProvince,
    this.platform,
    this.from,
    this.to,
    this.unassignedOnly = false,
    this.overdueOnly = false,
  });

  final String query;
  final Set<SupportTicketStatus> statuses;
  final Set<SupportTicketPriority> priorities;
  final Set<SupportTicketCategory> categories;
  final Set<SupportTicketKind> kinds;
  final String? assignedToUid;
  final String? organizationId;
  final String? country;
  final String? stateProvince;
  final String? platform;
  final DateTime? from;
  final DateTime? to;
  final bool unassignedOnly;
  final bool overdueOnly;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      priorities.isNotEmpty ||
      categories.isNotEmpty ||
      kinds.isNotEmpty ||
      (assignedToUid?.isNotEmpty ?? false) ||
      (organizationId?.isNotEmpty ?? false) ||
      (country?.isNotEmpty ?? false) ||
      (stateProvince?.isNotEmpty ?? false) ||
      (platform?.isNotEmpty ?? false) ||
      from != null ||
      to != null ||
      unassignedOnly ||
      overdueOnly;

  SupportListFilters copyWith({
    String? query,
    Set<SupportTicketStatus>? statuses,
    Set<SupportTicketPriority>? priorities,
    Set<SupportTicketCategory>? categories,
    Set<SupportTicketKind>? kinds,
    String? assignedToUid,
    String? organizationId,
    String? country,
    String? stateProvince,
    String? platform,
    DateTime? from,
    DateTime? to,
    bool? unassignedOnly,
    bool? overdueOnly,
    bool clearAssigned = false,
    bool clearOrg = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return SupportListFilters(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      priorities: priorities ?? this.priorities,
      categories: categories ?? this.categories,
      kinds: kinds ?? this.kinds,
      assignedToUid:
          clearAssigned ? null : (assignedToUid ?? this.assignedToUid),
      organizationId:
          clearOrg ? null : (organizationId ?? this.organizationId),
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      platform: platform ?? this.platform,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      unassignedOnly: unassignedOnly ?? this.unassignedOnly,
      overdueOnly: overdueOnly ?? this.overdueOnly,
    );
  }

  static const empty = SupportListFilters();
}
