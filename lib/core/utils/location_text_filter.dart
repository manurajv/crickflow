import '../../data/models/location_model.dart';

/// Rankings-style filter: AND of non-empty country / state / city
/// (case-insensitive contains). Coordinates are ignored.
bool locationMatchesTextFilter(LocationModel location, LocationModel filter) {
  final country = filter.country.trim();
  final state = filter.stateProvince.trim();
  final city = filter.city.trim();
  if (country.isEmpty && state.isEmpty && city.isEmpty) return true;

  if (country.isNotEmpty &&
      !location.country.toLowerCase().contains(country.toLowerCase())) {
    return false;
  }
  if (state.isNotEmpty &&
      !location.stateProvince.toLowerCase().contains(state.toLowerCase())) {
    return false;
  }
  if (city.isNotEmpty &&
      !location.city.toLowerCase().contains(city.toLowerCase())) {
    return false;
  }
  return true;
}

/// City filter with looser matching for match/tournament venues.
///
/// Checks [LocationModel.city] first, then district / placeName / optional
/// [venue], and still respects country/state when set on both sides.
bool locationMatchesCityFilter(
  LocationModel location,
  LocationModel filter, {
  String venue = '',
}) {
  final country = filter.country.trim();
  final state = filter.stateProvince.trim();
  final city = filter.city.trim();
  if (city.isEmpty) {
    return locationMatchesTextFilter(location, filter);
  }

  if (country.isNotEmpty &&
      location.country.trim().isNotEmpty &&
      !location.country.toLowerCase().contains(country.toLowerCase())) {
    return false;
  }
  if (state.isNotEmpty &&
      location.stateProvince.trim().isNotEmpty &&
      !location.stateProvince.toLowerCase().contains(state.toLowerCase())) {
    return false;
  }

  final q = city.toLowerCase();
  for (final part in [
    location.city,
    location.district,
    location.placeName,
    venue,
    location.displayLabel,
  ]) {
    final h = part.trim().toLowerCase();
    if (h.isEmpty) continue;
    // Bidirectional: "Colombo" ↔ "Colombo Municipal Council"
    if (h.contains(q) || q.contains(h)) return true;
  }
  return false;
}

/// Country + state/province matching for home nearby sections.
///
/// Looser than [locationMatchesTextFilter]:
/// - empty match sub-region still passes when country matches
/// - state is checked against district/city/placeName too
/// - venues that omit state/province still pass once country matches
///   (common for tournament/match docs)
bool locationMatchesNearbyRegion(LocationModel location, LocationModel filter) {
  final country = filter.country.trim();
  final state = filter.stateProvince.trim();
  if (country.isEmpty && state.isEmpty) return true;

  final locCountry = location.country.trim();
  if (country.isNotEmpty && locCountry.isNotEmpty) {
    final c = country.toLowerCase();
    final lc = locCountry.toLowerCase();
    if (!lc.contains(c) && !c.contains(lc)) return false;
  }

  if (state.isEmpty) return true;

  final locState = location.stateProvince.trim();
  if (locState.isEmpty) {
    // Prefer a soft hit on city/district/place when state was never stored.
    final soft = <String>[
      location.district,
      location.city,
      location.placeName,
      location.displayLabel,
    ]
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    final q = state.toLowerCase();
    for (final h in soft) {
      if (h.contains(q) || q.contains(h)) return true;
    }
    // Country already aligned and no state on the doc — keep in the feed.
    return true;
  }

  final haystacks = <String>[
    locState,
    location.district,
    location.city,
    location.placeName,
    location.displayLabel,
  ]
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toList();

  final q = state.toLowerCase();
  for (final h in haystacks) {
    if (h.contains(q) || q.contains(h)) return true;
  }
  return false;
}

/// Most-specific place label: city → state → country (same as rankings).
String locationFilterSummaryLabel(LocationModel location) {
  final city = location.city.trim();
  if (city.isNotEmpty) return city;
  final state = location.stateProvince.trim();
  if (state.isNotEmpty) return state;
  final country = location.country.trim();
  if (country.isNotEmpty) return country;
  return '';
}
