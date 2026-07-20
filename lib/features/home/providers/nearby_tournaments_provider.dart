import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo_distance.dart';
import '../../../data/models/tournament_model.dart';
import '../../../data/services/google_maps_location_service.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/location_filter_bar.dart';
import '../domain/nearby_tournament_item.dart';
import 'nearby_matches_provider.dart';

/// Nearby tournaments for Home (~30 km or city/state fallback).
final nearbyTournamentsProvider =
    FutureProvider.autoDispose<NearbyTournamentsState>((ref) async {
  final link = ref.keepAlive();
  final timer = Future<void>.delayed(const Duration(minutes: 5), link.close);
  ref.onDispose(() => timer.ignore());

  final locationService = ref.watch(googleMapsLocationServiceProvider);
  final access = await locationService.ensureLocationPermission();

  if (access == LocationAccessStatus.serviceDisabled) {
    return const NearbyTournamentsState(
      status: NearbyTournamentsStatus.serviceDisabled,
      message: 'Turn on location services to see tournaments near you.',
    );
  }

  List<TournamentModel> tournaments;
  try {
    tournaments = await ref.watch(tournamentsProvider.future);
  } catch (e) {
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.error,
      message: 'Could not load tournaments: $e',
    );
  }

  if (access == LocationAccessStatus.denied ||
      access == LocationAccessStatus.deniedForever) {
    return _regionFallback(
      ref: ref,
      candidates: tournaments,
      permissionDenied: true,
    );
  }

  final coords = await locationService.getCurrentCoords();
  if (coords == null) {
    return _regionFallback(
      ref: ref,
      candidates: tournaments,
      permissionDenied: true,
    );
  }

  var regionLabel = '';
  try {
    final resolved = await locationService.reverseGeocode(coords);
    regionLabel = resolved.location.displayLabel;
  } catch (_) {}

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

  final fallback = await _regionFallback(
    ref: ref,
    candidates: tournaments,
    permissionDenied: false,
    userCoords: coords,
    regionLabel: regionLabel,
  );
  if (fallback.items.isNotEmpty) return fallback;

  return NearbyTournamentsState(
    status: NearbyTournamentsStatus.empty,
    userCoords: coords,
    regionLabel: regionLabel,
    message: 'No tournaments near you right now.',
  );
});

Future<NearbyTournamentsState> _regionFallback({
  required Ref ref,
  required List<TournamentModel> candidates,
  required bool permissionDenied,
  GeoCoords? userCoords,
  String regionLabel = '',
}) async {
  var country = '';
  var city = '';
  final profile = ref.read(currentUserProfileProvider).valueOrNull;
  if (profile != null && !profile.location.isEmpty) {
    country = profile.location.country;
    city = profile.location.city.isNotEmpty
        ? profile.location.city
        : profile.location.stateProvince;
    regionLabel =
        regionLabel.isNotEmpty ? regionLabel : profile.location.displayLabel;
  } else if (userCoords != null && regionLabel.isEmpty) {
    try {
      final resolved = await ref
          .read(googleMapsLocationServiceProvider)
          .reverseGeocode(userCoords);
      country = resolved.location.country;
      city = resolved.location.city.isNotEmpty
          ? resolved.location.city
          : resolved.location.stateProvince;
      regionLabel = resolved.location.displayLabel;
    } catch (_) {}
  }

  if (country.isEmpty && city.isEmpty) {
    return NearbyTournamentsState(
      status: permissionDenied
          ? NearbyTournamentsStatus.permissionDenied
          : NearbyTournamentsStatus.empty,
      message: permissionDenied
          ? 'Location permission denied. Enable location to discover nearby tournaments.'
          : 'No tournaments near you right now.',
      regionLabel: regionLabel,
      userCoords: userCoords,
    );
  }

  final filtered = candidates
      .where((t) => locationMatchesFilter(t.location, country, city))
      .map((t) => NearbyTournamentItem(tournament: t, regionFallback: true))
      .take(12)
      .toList();

  if (filtered.isEmpty) {
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.empty,
      message: 'No tournaments near you right now.',
      regionLabel: regionLabel,
      userCoords: userCoords,
    );
  }

  return NearbyTournamentsState(
    status: NearbyTournamentsStatus.ready,
    items: filtered,
    regionLabel: regionLabel,
    userCoords: userCoords,
    message: permissionDenied
        ? 'Showing tournaments in $regionLabel (precise location unavailable).'
        : '',
  );
}
