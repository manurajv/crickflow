import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo_distance.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/google_maps_location_service.dart';
import '../../../domain/scoring/match_lifecycle.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/location_filter_bar.dart';
import '../domain/nearby_match_item.dart';

const double kNearbyMatchRadiusKm = kNearbyRadiusKm;

/// Cached nearby matches for the home "Matches Near You" section.
final nearbyMatchesProvider =
    FutureProvider.autoDispose<NearbyMatchesState>((ref) async {
  // Keep alive briefly so scroll rebuilds don't re-query GPS every time.
  final link = ref.keepAlive();
  final timer = Future<void>.delayed(const Duration(minutes: 5), link.close);
  ref.onDispose(() => timer.ignore());

  final locationService = ref.watch(googleMapsLocationServiceProvider);
  final access = await locationService.ensureLocationPermission();

  if (access == LocationAccessStatus.serviceDisabled) {
    return const NearbyMatchesState(
      status: NearbyMatchesStatus.serviceDisabled,
      message: 'Turn on location services to see matches near you.',
    );
  }

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

  if (access == LocationAccessStatus.denied ||
      access == LocationAccessStatus.deniedForever) {
    return _regionFallback(
      ref: ref,
      candidates: candidates,
      permissionDenied: true,
    );
  }

  final coords = await locationService.getCurrentCoords();
  if (coords == null) {
    return _regionFallback(
      ref: ref,
      candidates: candidates,
      permissionDenied: true,
    );
  }

  String regionLabel = '';
  try {
    final resolved = await locationService.reverseGeocode(coords);
    regionLabel = resolved.location.displayLabel;
  } catch (_) {}

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

  // No geo-tagged matches in radius — fall back to city/state region.
  final fallback = await _regionFallback(
    ref: ref,
    candidates: candidates,
    permissionDenied: false,
    userCoords: coords,
    regionLabel: regionLabel,
  );
  if (fallback.items.isNotEmpty) {
    return fallback;
  }

  return NearbyMatchesState(
    status: NearbyMatchesStatus.empty,
    userCoords: coords,
    regionLabel: regionLabel,
    message: 'No matches are currently scheduled near you.',
  );
});

Future<NearbyMatchesState> _regionFallback({
  required Ref ref,
  required List<MatchModel> candidates,
  required bool permissionDenied,
  GeoCoords? userCoords,
  String regionLabel = '',
}) async {
  // Prefer signed-in profile location, else reverse-geocode if we have coords.
  var country = '';
  var city = '';
  final profile = ref.read(currentUserProfileProvider).valueOrNull;
  if (profile != null && !profile.location.isEmpty) {
    country = profile.location.country;
    city = profile.location.city.isNotEmpty
        ? profile.location.city
        : profile.location.stateProvince;
    regionLabel = regionLabel.isNotEmpty
        ? regionLabel
        : profile.location.displayLabel;
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
    return NearbyMatchesState(
      status: permissionDenied
          ? NearbyMatchesStatus.permissionDenied
          : NearbyMatchesStatus.empty,
      message: permissionDenied
          ? 'Location permission denied. Enable location to discover nearby matches.'
          : 'No matches are currently scheduled near you.',
      regionLabel: regionLabel,
      userCoords: userCoords,
    );
  }

  final filtered = candidates
      .where((m) => locationMatchesFilter(m.location, country, city))
      .map(
        (m) => NearbyMatchItem(match: m, regionFallback: true),
      )
      .take(20)
      .toList();

  if (filtered.isEmpty) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.empty,
      message: 'No matches are currently scheduled near you.',
      regionLabel: regionLabel,
      userCoords: userCoords,
    );
  }

  return NearbyMatchesState(
    status: NearbyMatchesStatus.ready,
    items: filtered,
    regionLabel: regionLabel,
    userCoords: userCoords,
    message: permissionDenied
        ? 'Showing matches in $regionLabel (precise location unavailable).'
        : '',
  );
}
