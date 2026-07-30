import 'ads_enums.dart';

class AdsListFilters {
  const AdsListFilters({
    this.query = '',
    this.statuses = const {},
    this.placements = const {},
    this.mediaTypes = const {},
    this.campaignTypes = const {},
    this.from,
    this.to,
    this.pendingOnly = false,
    this.includeArchived = false,
  });

  static const empty = AdsListFilters();

  final String query;
  final Set<ManagedAdStatus> statuses;
  final Set<ManagedAdPlacement> placements;
  final Set<ManagedAdMediaType> mediaTypes;
  final Set<ManagedAdCampaignType> campaignTypes;
  final DateTime? from;
  final DateTime? to;
  final bool pendingOnly;
  final bool includeArchived;

  bool get hasActiveFilters =>
      statuses.isNotEmpty ||
      placements.isNotEmpty ||
      mediaTypes.isNotEmpty ||
      campaignTypes.isNotEmpty ||
      from != null ||
      to != null ||
      pendingOnly ||
      includeArchived;

  AdsListFilters copyWith({
    String? query,
    Set<ManagedAdStatus>? statuses,
    Set<ManagedAdPlacement>? placements,
    Set<ManagedAdMediaType>? mediaTypes,
    Set<ManagedAdCampaignType>? campaignTypes,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    bool? pendingOnly,
    bool? includeArchived,
  }) {
    return AdsListFilters(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      placements: placements ?? this.placements,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      campaignTypes: campaignTypes ?? this.campaignTypes,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      pendingOnly: pendingOnly ?? this.pendingOnly,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }
}
