import '../../matches/models/match_enums.dart';
import 'broadcast_enums.dart';

class BroadcastListFilters {
  const BroadcastListFilters({
    this.query = '',
    this.statuses = const {},
    this.platforms = const {},
    this.health = const {},
    this.visibilities = const {},
    this.liveOnly = false,
    this.country,
    this.stateProvince,
    this.city,
    this.from,
    this.to,
    this.includeDeleted = false,
    this.includeArchived = false,
  });

  static const empty = BroadcastListFilters();

  final String query;
  final Set<ManagedBroadcastStatus> statuses;
  final Set<ManagedStreamPlatform> platforms;
  final Set<ManagedBroadcastHealth> health;
  final Set<ManagedBroadcastVisibility> visibilities;
  final bool liveOnly;
  final String? country;
  final String? stateProvince;
  final String? city;
  final DateTime? from;
  final DateTime? to;
  final bool includeDeleted;
  final bool includeArchived;

  bool get hasActiveFilters =>
      statuses.isNotEmpty ||
      platforms.isNotEmpty ||
      health.isNotEmpty ||
      visibilities.isNotEmpty ||
      liveOnly ||
      (country?.trim().isNotEmpty ?? false) ||
      (stateProvince?.trim().isNotEmpty ?? false) ||
      (city?.trim().isNotEmpty ?? false) ||
      from != null ||
      to != null ||
      includeDeleted ||
      includeArchived;

  BroadcastListFilters copyWith({
    String? query,
    Set<ManagedBroadcastStatus>? statuses,
    Set<ManagedStreamPlatform>? platforms,
    Set<ManagedBroadcastHealth>? health,
    Set<ManagedBroadcastVisibility>? visibilities,
    bool? liveOnly,
    String? country,
    String? stateProvince,
    String? city,
    DateTime? from,
    DateTime? to,
    bool? includeDeleted,
    bool? includeArchived,
    bool clearCountry = false,
    bool clearState = false,
    bool clearCity = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return BroadcastListFilters(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      platforms: platforms ?? this.platforms,
      health: health ?? this.health,
      visibilities: visibilities ?? this.visibilities,
      liveOnly: liveOnly ?? this.liveOnly,
      country: clearCountry ? null : (country ?? this.country),
      stateProvince: clearState ? null : (stateProvince ?? this.stateProvince),
      city: clearCity ? null : (city ?? this.city),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      includeDeleted: includeDeleted ?? this.includeDeleted,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }
}
