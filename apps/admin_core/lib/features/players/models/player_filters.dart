import 'player_enums.dart';

class PlayerListFilters {
  const PlayerListFilters({
    this.query = '',
    this.statuses = const {},
    this.registeredOnly = false,
    this.walkInOnly = false,
    this.includeDeleted = false,
    this.includeArchived = false,
    this.country,
    this.city,
  });

  static const empty = PlayerListFilters();

  final String query;
  final Set<ManagedPlayerStatus> statuses;
  final bool registeredOnly;
  final bool walkInOnly;
  final bool includeDeleted;
  final bool includeArchived;
  final String? country;
  final String? city;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      registeredOnly ||
      walkInOnly ||
      includeDeleted ||
      includeArchived ||
      (country?.trim().isNotEmpty ?? false) ||
      (city?.trim().isNotEmpty ?? false);

  PlayerListFilters copyWith({
    String? query,
    Set<ManagedPlayerStatus>? statuses,
    bool? registeredOnly,
    bool? walkInOnly,
    bool? includeDeleted,
    bool? includeArchived,
    String? country,
    bool clearCountry = false,
    String? city,
    bool clearCity = false,
  }) {
    return PlayerListFilters(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      registeredOnly: registeredOnly ?? this.registeredOnly,
      walkInOnly: walkInOnly ?? this.walkInOnly,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      includeArchived: includeArchived ?? this.includeArchived,
      country: clearCountry ? null : (country ?? this.country),
      city: clearCity ? null : (city ?? this.city),
    );
  }
}
