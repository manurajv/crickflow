import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo_distance.dart';
import '../../../core/utils/location_text_filter.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/tournament_model.dart';
import '../../../data/services/google_maps_location_service.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/location_filter_bar.dart';
import '../domain/nearby_tournament_item.dart';
import 'nearby_anchor_location_provider.dart';
import 'nearby_matches_provider.dart';

/// Nearby tournaments for Home (GPS radius, or rankings-style location filter).
final nearbyTournamentsProvider =
    FutureProvider.autoDispose<NearbyTournamentsState>((ref) async {
  final link = ref.keepAlive();
  final timer = Future<void>.delayed(const Duration(minutes: 5), link.close);
  ref.onDispose(() => timer.ignore());

  final locationService = ref.watch(googleMapsLocationServiceProvider);
  final anchor = ref.watch(nearbyAnchorLocationProvider);

  List<TournamentModel> tournaments;
  try {
    tournaments = await ref.watch(tournamentsProvider.future);
  } catch (e) {
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.error,
      message: 'Could not load tournaments: $e',
    );
  }

  // Custom location filter.
  // City → 50 km radius + city text fallback. Country/state only → text match.
  if (anchor != null && !anchor.isEmpty) {
    if (anchor.city.trim().isNotEmpty) {
      return _buildFromCityFilter(
        tournaments: tournaments,
        filter: anchor,
        locationService: locationService,
      );
    }
    return _buildFromTextFilter(tournaments: tournaments, filter: anchor);
  }

  final access = await locationService.ensureLocationPermission();

  if (access == LocationAccessStatus.serviceDisabled) {
    return const NearbyTournamentsState(
      status: NearbyTournamentsStatus.serviceDisabled,
      message: 'Turn on location services to see tournaments near you.',
    );
  }

  if (access == LocationAccessStatus.denied ||
      access == LocationAccessStatus.deniedForever) {
    return _permissionDeniedFallback(ref: ref, candidates: tournaments);
  }

  final coords = await locationService.getCurrentCoords();
  if (coords == null) {
    return _permissionDeniedFallback(ref: ref, candidates: tournaments);
  }

  var regionLabel = '';
  try {
    final resolved = await locationService.reverseGeocode(coords);
    regionLabel = resolved.location.displayLabel;
  } catch (_) {}

  return _buildFromCoords(
    tournaments: tournaments,
    coords: coords,
    regionLabel: regionLabel,
  );
});

NearbyTournamentsState _buildFromTextFilter({
  required List<TournamentModel> tournaments,
  required LocationModel filter,
}) {
  final regionLabel = locationFilterSummaryLabel(filter);
  final filtered = tournaments
      .where((t) => locationMatchesTextFilter(t.location, filter))
      .map((t) => NearbyTournamentItem(tournament: t, regionFallback: true))
      .take(12)
      .toList();

  if (filtered.isEmpty) {
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.empty,
      regionLabel: regionLabel,
      message: regionLabel.isNotEmpty
          ? 'No tournaments in $regionLabel.'
          : 'No tournaments found for this location.',
    );
  }

  return NearbyTournamentsState(
    status: NearbyTournamentsStatus.ready,
    items: filtered,
    regionLabel: regionLabel,
  );
}

Future<NearbyTournamentsState> _buildFromCityFilter({
  required List<TournamentModel> tournaments,
  required LocationModel filter,
  required GoogleMapsLocationService locationService,
}) async {
  final regionLabel = locationFilterSummaryLabel(filter);
  final coords = await resolveNearbyAnchorCoords(locationService, filter);
  final items = <NearbyTournamentItem>[];
  final seen = <String>{};

  if (coords != null) {
    for (final t in tournaments) {
      final loc = t.location;
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
        items.add(NearbyTournamentItem(tournament: t, distanceKm: km));
        seen.add(t.id);
      }
    }
  }

  for (final t in tournaments) {
    if (seen.contains(t.id)) continue;
    if (!locationMatchesCityFilter(t.location, filter)) continue;
    items.add(NearbyTournamentItem(tournament: t, regionFallback: true));
    seen.add(t.id);
  }

  items.sort((a, b) {
    final da = a.distanceKm ?? double.infinity;
    final db = b.distanceKm ?? double.infinity;
    return da.compareTo(db);
  });

  if (items.isNotEmpty) {
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.ready,
      items: items.take(12).toList(),
      userCoords: coords,
      regionLabel: regionLabel,
    );
  }

  return NearbyTournamentsState(
    status: NearbyTournamentsStatus.empty,
    userCoords: coords,
    regionLabel: regionLabel,
    message: regionLabel.isNotEmpty
        ? (coords != null
            ? 'No tournaments within ${kNearbyMatchRadiusKm.round()} km of $regionLabel.'
            : 'No tournaments in $regionLabel.')
        : 'No tournaments found for this location.',
  );
}

NearbyTournamentsState _buildFromCoords({
  required List<TournamentModel> tournaments,
  required GeoCoords coords,
  required String regionLabel,
}) {
  final withDistance = <NearbyTournamentItem>[];
  for (final t in tournaments) {
    final loc = t.location;
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
      withDistance.add(NearbyTournamentItem(tournament: t, distanceKm: km));
    }
  }

  withDistance.sort((a, b) {
    final da = a.distanceKm ?? double.infinity;
    final db = b.distanceKm ?? double.infinity;
    return da.compareTo(db);
  });

  if (withDistance.isNotEmpty) {
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.ready,
      items: withDistance.take(12).toList(),
      userCoords: coords,
      regionLabel: regionLabel,
    );
  }

  return NearbyTournamentsState(
    status: NearbyTournamentsStatus.empty,
    userCoords: coords,
    regionLabel: regionLabel,
    message: regionLabel.isNotEmpty
        ? 'No tournaments within ${kNearbyMatchRadiusKm.round()} km of $regionLabel.'
        : 'No tournaments near you right now.',
  );
}

Future<NearbyTournamentsState> _permissionDeniedFallback({
  required Ref ref,
  required List<TournamentModel> candidates,
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
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.permissionDenied,
      message:
          'Location permission denied. Enable location to discover nearby tournaments.',
      regionLabel: regionLabel,
    );
  }

  final filtered = candidates
      .where((t) => locationMatchesFilter(t.location, country, city))
      .map((t) => NearbyTournamentItem(tournament: t, regionFallback: true))
      .take(12)
      .toList();

  if (filtered.isEmpty) {
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.permissionDenied,
      message:
          'Location permission denied. Enable location to discover nearby tournaments.',
      regionLabel: regionLabel,
    );
  }

  return NearbyTournamentsState(
    status: NearbyTournamentsStatus.ready,
    items: filtered,
    regionLabel: regionLabel,
    message: 'Showing tournaments in $city (precise location unavailable).',
  );
}
