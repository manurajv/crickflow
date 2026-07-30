import 'moderation_enums.dart';

class ModerationListFilters {
  const ModerationListFilters({
    this.query = '',
    this.statuses = const {},
    this.sources = const {},
    this.hasMedia,
    this.mediaType,
    this.country,
    this.stateProvince,
    this.city,
    this.from,
    this.to,
    this.tournamentOnly = false,
    this.includeRemoved = false,
  });

  static const empty = ModerationListFilters();

  final String query;
  final Set<ManagedPostAdminStatus> statuses;
  final Set<ModerationSource> sources;
  final bool? hasMedia;
  final String? mediaType; // image | video | none
  final String? country;
  final String? stateProvince;
  final String? city;
  final DateTime? from;
  final DateTime? to;
  final bool tournamentOnly;
  final bool includeRemoved;

  bool get hasActiveFilters =>
      statuses.isNotEmpty ||
      sources.isNotEmpty ||
      hasMedia != null ||
      (mediaType?.isNotEmpty ?? false) ||
      (country?.trim().isNotEmpty ?? false) ||
      (stateProvince?.trim().isNotEmpty ?? false) ||
      (city?.trim().isNotEmpty ?? false) ||
      from != null ||
      to != null ||
      tournamentOnly ||
      includeRemoved;

  ModerationListFilters copyWith({
    String? query,
    Set<ManagedPostAdminStatus>? statuses,
    Set<ModerationSource>? sources,
    bool? hasMedia,
    bool clearHasMedia = false,
    String? mediaType,
    bool clearMediaType = false,
    String? country,
    bool clearCountry = false,
    String? stateProvince,
    bool clearState = false,
    String? city,
    bool clearCity = false,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    bool? tournamentOnly,
    bool? includeRemoved,
  }) {
    return ModerationListFilters(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      sources: sources ?? this.sources,
      hasMedia: clearHasMedia ? null : (hasMedia ?? this.hasMedia),
      mediaType: clearMediaType ? null : (mediaType ?? this.mediaType),
      country: clearCountry ? null : (country ?? this.country),
      stateProvince: clearState ? null : (stateProvince ?? this.stateProvince),
      city: clearCity ? null : (city ?? this.city),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      tournamentOnly: tournamentOnly ?? this.tournamentOnly,
      includeRemoved: includeRemoved ?? this.includeRemoved,
    );
  }
}
