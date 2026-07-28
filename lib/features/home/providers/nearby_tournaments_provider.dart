import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/utils/location_text_filter.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/tournament_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/google_maps_location_service.dart';
import '../../../features/my_cricket/my_cricket_filters.dart';
import '../../../shared/providers/player_social_provider.dart';
import '../../../shared/providers/providers.dart';
import '../domain/nearby_tournament_item.dart';
import 'nearby_anchor_location_provider.dart';

/// Home nearby tournaments — region text filter (country + state/province).
final nearbyTournamentsProvider =
    FutureProvider.autoDispose<NearbyTournamentsState>((ref) async {
  final link = ref.keepAlive();
  final timer = Future<void>.delayed(const Duration(minutes: 5), link.close);
  ref.onDispose(() => timer.ignore());

  final locationService = ref.watch(googleMapsLocationServiceProvider);
  final anchor = ref.watch(nearbyAnchorLocationProvider);
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  final following = await _nearbyFollowing(ref, uid);
  final followedPlayers = FollowedPlayerRefs.fromUsers(following);

  List<TournamentModel> tournaments;
  try {
    tournaments = await ref.watch(tournamentsProvider.future);
  } catch (e) {
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.error,
      message: 'Could not load tournaments: $e',
    );
  }

  // Public feed: hide drafts/cancelled. Keep the viewer's own tournaments
  // (unlike matches) so Home isn't empty when you only host local events.
  tournaments = tournaments
      .where(
        (t) =>
            t.status != TournamentStatus.draft &&
            t.status != TournamentStatus.cancelled,
      )
      .toList();

  if (anchor != null && !anchor.isEmpty) {
    return _buildFromRegionFilter(
      tournaments: tournaments,
      filter: anchor,
      following: following,
      followedPlayers: followedPlayers,
    );
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
    return _permissionDeniedFallback(
      ref: ref,
      candidates: tournaments,
      following: following,
      followedPlayers: followedPlayers,
    );
  }

  final coords = await locationService.getCurrentCoords();
  if (coords == null) {
    return _permissionDeniedFallback(
      ref: ref,
      candidates: tournaments,
      following: following,
      followedPlayers: followedPlayers,
    );
  }

  try {
    final resolved = await locationService.reverseGeocode(coords);
    return _buildFromRegionFilter(
      tournaments: tournaments,
      filter: resolved.location,
      following: following,
      followedPlayers: followedPlayers,
    );
  } catch (_) {
    return _permissionDeniedFallback(
      ref: ref,
      candidates: tournaments,
      following: following,
      followedPlayers: followedPlayers,
    );
  }
});

Future<List<UserModel>> _nearbyFollowing(Ref ref, String? uid) async {
  if (uid == null || uid.isEmpty) return const [];
  try {
    return await ref.watch(playerFollowingProvider(uid).future);
  } catch (_) {
    return ref.read(playerFollowingProvider(uid)).valueOrNull ?? const [];
  }
}

NearbyTournamentsState _buildFromRegionFilter({
  required List<TournamentModel> tournaments,
  required LocationModel filter,
  required List<UserModel> following,
  required FollowedPlayerRefs followedPlayers,
}) {
  final region = nearbyRegionFilter(filter);
  final regionLabel = nearbyRegionLabel(region);

  if (region.country.isEmpty && region.stateProvince.isEmpty) {
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.empty,
      regionLabel: regionLabel,
      message: 'Choose a country or state to see tournaments.',
    );
  }

  var items = _collectItems(
    tournaments: tournaments,
    region: region,
    following: following,
    followedPlayers: followedPlayers,
  );

  // State/city labels from GPS or the filter sheet often don't match stored
  // venue text — fall back to country so the section isn't empty.
  if (items.isEmpty &&
      region.country.isNotEmpty &&
      region.stateProvince.isNotEmpty) {
    items = _collectItems(
      tournaments: tournaments,
      region: LocationModel(country: region.country),
      following: following,
      followedPlayers: followedPlayers,
    );
  }

  if (items.isEmpty) {
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
    items: items.take(12).toList(),
    regionLabel: regionLabel,
  );
}

List<NearbyTournamentItem> _collectItems({
  required List<TournamentModel> tournaments,
  required LocationModel region,
  required List<UserModel> following,
  required FollowedPlayerRefs followedPlayers,
}) {
  final items = <NearbyTournamentItem>[];
  for (final t in tournaments) {
    if (!locationMatchesNearbyRegion(t.location, region)) continue;
    final fromNetwork = tournamentInvolvesFollowedUser(t, followedPlayers);
    items.add(
      NearbyTournamentItem(
        tournament: t,
        regionFallback: true,
        fromNetwork: fromNetwork,
        attributionLabel: fromNetwork
            ? networkTournamentAttribution(t, following)
            : null,
      ),
    );
  }

  items.sort((a, b) {
    final aRank = _statusSortRank(a.tournament.status);
    final bRank = _statusSortRank(b.tournament.status);
    if (aRank != bRank) return aRank.compareTo(bRank);
    if (a.fromNetwork != b.fromNetwork) {
      return a.fromNetwork ? -1 : 1;
    }
    final aStart = a.tournament.startDate ?? a.tournament.createdAt;
    final bStart = b.tournament.startDate ?? b.tournament.createdAt;
    if (aStart == null && bStart == null) return 0;
    if (aStart == null) return 1;
    if (bStart == null) return -1;
    return bStart.compareTo(aStart);
  });

  return items;
}

int _statusSortRank(TournamentStatus status) => switch (status) {
      TournamentStatus.live => 0,
      TournamentStatus.upcoming => 1,
      TournamentStatus.completed => 2,
      TournamentStatus.cancelled => 3,
      TournamentStatus.draft => 4,
    };

NearbyTournamentsState _permissionDeniedFallback({
  required Ref ref,
  required List<TournamentModel> candidates,
  required List<UserModel> following,
  required FollowedPlayerRefs followedPlayers,
}) {
  final profile = ref.read(currentUserProfileProvider).valueOrNull;
  final loc = profile?.location;

  if (loc == null || loc.isEmpty) {
    // Last resort: show recent public tournaments so Home isn't blank.
    if (candidates.isEmpty) {
      return const NearbyTournamentsState(
        status: NearbyTournamentsStatus.permissionDenied,
        message:
            'Location permission denied. Enable location to discover tournaments near you.',
      );
    }
    final items = _collectItems(
      tournaments: candidates,
      region: const LocationModel(),
      following: following,
      followedPlayers: followedPlayers,
    );
    if (items.isEmpty) {
      return const NearbyTournamentsState(
        status: NearbyTournamentsStatus.permissionDenied,
        message:
            'Location permission denied. Enable location to discover tournaments near you.',
      );
    }
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.ready,
      items: items.take(12).toList(),
      message: 'Enable location to personalize tournaments near you.',
    );
  }

  final region = nearbyRegionFilter(loc);
  if (region.country.isEmpty && region.stateProvince.isEmpty) {
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.permissionDenied,
      message:
          'Location permission denied. Enable location to discover tournaments near you.',
      regionLabel: loc.displayLabel,
    );
  }

  final result = _buildFromRegionFilter(
    tournaments: candidates,
    filter: region,
    following: following,
    followedPlayers: followedPlayers,
  );
  if (result.status == NearbyTournamentsStatus.ready) {
    return NearbyTournamentsState(
      status: NearbyTournamentsStatus.ready,
      items: result.items,
      regionLabel: result.regionLabel,
      message:
          'Showing tournaments in ${result.regionLabel} (precise location unavailable).',
    );
  }

  return NearbyTournamentsState(
    status: NearbyTournamentsStatus.permissionDenied,
    message:
        'Location permission denied. Enable location to discover tournaments near you.',
    regionLabel: result.regionLabel,
  );
}
