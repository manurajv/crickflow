import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo_distance.dart';
import '../../../core/utils/location_text_filter.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/google_maps_location_service.dart';
import '../../../domain/scoring/match_lifecycle.dart';
import '../../../shared/providers/providers.dart';
import '../domain/nearby_match_item.dart';
import 'nearby_anchor_location_provider.dart';

const double kNearbyMatchRadiusKm = 50;

/// Cached nearby matches for the home "Matches Near You" section.
final nearbyMatchesProvider =
    FutureProvider.autoDispose<NearbyMatchesState>((ref) async {
  // Keep alive briefly so scroll rebuilds don't re-query GPS every time.
  final link = ref.keepAlive();
  final timer = Future<void>.delayed(const Duration(minutes: 5), link.close);
  ref.onDispose(() => timer.ignore());

  final locationService = ref.watch(googleMapsLocationServiceProvider);
  final anchor = ref.watch(nearbyAnchorLocationProvider);

  List<MatchModel> matches;
  try {
    matches = await ref.watch(matchesProvider.future);
  } catch (e) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.error,
      message: 'Could not load matches: $e',
    );
  }

  // Prefer live / upcoming, then recent completed.
  final candidates = matches.where((m) {
    if (MatchLifecycle.isEffectivelyLive(m)) return true;
    if (MatchLifecycle.isUpcoming(m)) return true;
    if (MatchLifecycle.isCompleted(m)) {
      final completed = m.completedAt;
      if (completed == null) return true;
      return DateTime.now().difference(completed).inDays <= 7;
    }
    return false;
  }).toList();

  // Custom location filter.
  // City → 50 km radius + city text fallback. Country/state only → text match.
  if (anchor != null && !anchor.isEmpty) {
    if (anchor.city.trim().isNotEmpty) {
      return _buildFromCityFilter(
        candidates: candidates,
        filter: anchor,
        locationService: locationService,
      );
    }
    return _buildFromTextFilter(candidates: candidates, filter: anchor);
  }

  final access = await locationService.ensureLocationPermission();

  if (access == LocationAccessStatus.serviceDisabled) {
    return const NearbyMatchesState(
      status: NearbyMatchesStatus.serviceDisabled,
      message: 'Turn on location services to see matches near you.',
    );
  }

  if (access == LocationAccessStatus.denied ||
      access == LocationAccessStatus.deniedForever) {
    return _permissionDeniedFallback(ref: ref, candidates: candidates);
  }

  final coords = await locationService.getCurrentCoords();
  if (coords == null) {
    return _permissionDeniedFallback(ref: ref, candidates: candidates);
  }

  var regionLabel = '';
  try {
    final resolved = await locationService.reverseGeocode(coords);
    regionLabel = resolved.location.displayLabel;
  } catch (_) {}

  return _buildFromCoords(
    candidates: candidates,
    coords: coords,
    regionLabel: regionLabel,
  );
});

Future<GeoCoords?> resolveNearbyAnchorCoords(
  GoogleMapsLocationService locationService,
  LocationModel anchor,
) async {
  // Prefer geocoding the city so radius centers on the selected city — not a
  // stale device GPS pin that may still be attached to the LocationModel.
  final query = [
    anchor.city,
    anchor.stateProvince,
    anchor.country,
  ].where((e) => e.trim().isNotEmpty).join(', ');
  if (query.isNotEmpty) {
    try {
      final suggestions = await locationService.searchCities(query);
      if (suggestions.isNotEmpty) {
        final resolved = await locationService.resolvePlace(
          suggestions.first.placeId,
          fallbackDescription: suggestions.first.description,
        );
        if (resolved.location.hasCoordinates) {
          return GeoCoords(
            latitude: resolved.location.latitude!,
            longitude: resolved.location.longitude!,
          );
        }
      }
    } catch (_) {}
  }

  if (anchor.hasCoordinates) {
    return GeoCoords(
      latitude: anchor.latitude!,
      longitude: anchor.longitude!,
    );
  }
  return null;
}

Future<NearbyMatchesState> _buildFromCityFilter({
  required List<MatchModel> candidates,
  required LocationModel filter,
  required GoogleMapsLocationService locationService,
}) async {
  final regionLabel = locationFilterSummaryLabel(filter);
  final coords = await resolveNearbyAnchorCoords(locationService, filter);
  final items = <NearbyMatchItem>[];
  final seen = <String>{};

  if (coords != null) {
    for (final match in candidates) {
      final loc = match.location;
      if (!loc.hasCoordinates) continue;
      final lat = loc.latitude!;
      final lng = loc.longitude!;
      if (!withinApproxBoundingBox(
        origin: coords,
        lat: lat,
        lng: lng,
        radiusKm: kNearbyMatchRadiusKm,
      )) {
        continue;
      }
      final km = distanceKmBetween(
        coords,
        GeoCoords(latitude: lat, longitude: lng),
      );
      if (km <= kNearbyMatchRadiusKm) {
        items.add(NearbyMatchItem(match: match, distanceKm: km));
        seen.add(match.id);
      }
    }
  }

  // Many matches only have city/venue text (no lat/lng). Include those too.
  for (final match in candidates) {
    if (seen.contains(match.id)) continue;
    if (!locationMatchesCityFilter(
      match.location,
      filter,
      venue: match.venue,
    )) {
      continue;
    }
    items.add(NearbyMatchItem(match: match, regionFallback: true));
    seen.add(match.id);
  }

  items.sort((a, b) {
    final da = a.distanceKm ?? double.infinity;
    final db = b.distanceKm ?? double.infinity;
    return da.compareTo(db);
  });

  if (items.isNotEmpty) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.ready,
      items: items.take(20).toList(),
      userCoords: coords,
      regionLabel: regionLabel,
    );
  }

  return NearbyMatchesState(
    status: NearbyMatchesStatus.empty,
    userCoords: coords,
    regionLabel: regionLabel,
    message: regionLabel.isNotEmpty
        ? (coords != null
            ? 'No matches within ${kNearbyMatchRadiusKm.round()} km of $regionLabel.'
            : 'No matches in $regionLabel.')
        : 'No matches found for this location.',
  );
}

NearbyMatchesState _buildFromTextFilter({
  required List<MatchModel> candidates,
  required LocationModel filter,
}) {
  final regionLabel = locationFilterSummaryLabel(filter);
  final filtered = candidates
      .where((m) => locationMatchesTextFilter(m.location, filter))
      .map((m) => NearbyMatchItem(match: m, regionFallback: true))
      .take(20)
      .toList();

  if (filtered.isEmpty) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.empty,
      regionLabel: regionLabel,
      message: regionLabel.isNotEmpty
          ? 'No matches in $regionLabel.'
          : 'No matches found for this location.',
    );
  }

  return NearbyMatchesState(
    status: NearbyMatchesStatus.ready,
    items: filtered,
    regionLabel: regionLabel,
  );
}

NearbyMatchesState _buildFromCoords({
  required List<MatchModel> candidates,
  required GeoCoords coords,
  required String regionLabel,
}) {
  final withDistance = <NearbyMatchItem>[];
  for (final match in candidates) {
    final loc = match.location;
    if (!loc.hasCoordinates) continue;
    final lat = loc.latitude!;
    final lng = loc.longitude!;
    if (!withinApproxBoundingBox(
      origin: coords,
      lat: lat,
      lng: lng,
      radiusKm: kNearbyMatchRadiusKm,
    )) {
      continue;
    }
    final km = distanceKmBetween(
      coords,
      GeoCoords(latitude: lat, longitude: lng),
    );
    if (km <= kNearbyMatchRadiusKm) {
      withDistance.add(NearbyMatchItem(match: match, distanceKm: km));
    }
  }

  withDistance.sort((a, b) {
    final da = a.distanceKm ?? double.infinity;
    final db = b.distanceKm ?? double.infinity;
    return da.compareTo(db);
  });

  if (withDistance.isNotEmpty) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.ready,
      items: withDistance.take(20).toList(),
      userCoords: coords,
      regionLabel: regionLabel,
    );
  }

  return NearbyMatchesState(
    status: NearbyMatchesStatus.empty,
    userCoords: coords,
    regionLabel: regionLabel,
    message: regionLabel.isNotEmpty
        ? 'No matches within ${kNearbyMatchRadiusKm.round()} km of $regionLabel.'
        : 'No matches are currently scheduled near you.',
  );
}

Future<NearbyMatchesState> _permissionDeniedFallback({
  required Ref ref,
  required List<MatchModel> candidates,
}) async {
  final profile = ref.read(currentUserProfileProvider).valueOrNull;
  final loc = profile?.location;
  final country = loc?.country ?? '';
  final city = (loc == null || loc.isEmpty)
      ? ''
      : (loc.city.isNotEmpty
          ? loc.city
          : (loc.district.isNotEmpty ? loc.district : loc.stateProvince));
  final regionLabel = loc?.displayLabel ?? '';

  if (city.isEmpty) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.permissionDenied,
      message:
          'Location permission denied. Enable location to discover nearby matches.',
      regionLabel: regionLabel,
    );
  }

  final filtered = candidates
      .where(
        (m) => _matchesCurrentLocality(
          m.location,
          country: country,
          locality: city,
        ),
      )
      .map((m) => NearbyMatchItem(match: m, regionFallback: true))
      .take(20)
      .toList();

  if (filtered.isEmpty) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.permissionDenied,
      message:
          'Location permission denied. Enable location to discover nearby matches.',
      regionLabel: regionLabel,
    );
  }

  return NearbyMatchesState(
    status: NearbyMatchesStatus.ready,
    items: filtered,
    regionLabel: regionLabel,
    message: 'Showing matches in $city (precise location unavailable).',
  );
}

bool _matchesCurrentLocality(
  LocationModel location, {
  required String country,
  required String locality,
}) {
  final q = locality.trim().toLowerCase();
  if (q.isEmpty) return false;

  final city = location.city.toLowerCase();
  final district = location.district.toLowerCase();
  final state = location.stateProvince.toLowerCase();
  final localityHit = city == q ||
      district == q ||
      city.contains(q) ||
      district.contains(q) ||
      (city.isEmpty && district.isEmpty && state == q);

  if (!localityHit) return false;

  if (country.trim().isNotEmpty) {
    final c = country.trim().toLowerCase();
    final matchCountry = location.country.toLowerCase();
    if (matchCountry.isNotEmpty &&
        matchCountry != c &&
        !matchCountry.contains(c) &&
        !c.contains(matchCountry)) {
      return false;
    }
  }
  return true;
}
