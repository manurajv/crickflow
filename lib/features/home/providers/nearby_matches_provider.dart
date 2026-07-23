import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo_distance.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/google_maps_location_service.dart';
import '../../../domain/scoring/match_lifecycle.dart';
import '../../../shared/providers/providers.dart';
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
    return _permissionDeniedFallback(ref: ref, candidates: candidates);
  }

  final coords = await locationService.getCurrentCoords();
  if (coords == null) {
    return _permissionDeniedFallback(ref: ref, candidates: candidates);
  }

  var regionLabel = '';
  var country = '';
  var city = '';
  try {
    final resolved = await locationService.reverseGeocode(coords);
    regionLabel = resolved.location.displayLabel;
    country = resolved.location.country;
    city = resolved.location.city.isNotEmpty
        ? resolved.location.city
        : (resolved.location.district.isNotEmpty
            ? resolved.location.district
            : resolved.location.stateProvince);
  } catch (_) {}

  // Primary: GPS distance only — never mix in far-away matches.
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

  // No geo-tagged hits in radius — include untagged matches only if they
  // match the *current* city/district (never country-wide).
  if (city.isNotEmpty) {
    final localOnly = candidates
        .where((m) => !m.location.hasCoordinates)
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
    if (localOnly.isNotEmpty) {
      return NearbyMatchesState(
        status: NearbyMatchesStatus.ready,
        items: localOnly,
        userCoords: coords,
        regionLabel: regionLabel,
        message: 'Showing matches in $city',
      );
    }
  }

  return NearbyMatchesState(
    status: NearbyMatchesStatus.empty,
    userCoords: coords,
    regionLabel: regionLabel,
    message: 'No matches are currently scheduled near you.',
  );
});

/// When GPS is unavailable, only show matches in the profile city — never
/// an entire country (that looked like "random" far-away matches).
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

/// Strict locality match — city/district must align; country alone is not enough.
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
