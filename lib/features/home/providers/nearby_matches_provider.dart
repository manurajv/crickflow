import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/location_text_filter.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/player_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/google_maps_location_service.dart';
import '../../../domain/scoring/match_lifecycle.dart';
import '../../../features/my_cricket/my_cricket_filters.dart';
import '../../../shared/providers/my_player_provider.dart';
import '../../../shared/providers/player_social_provider.dart';
import '../../../shared/providers/providers.dart';
import '../domain/nearby_match_item.dart';
import 'nearby_anchor_location_provider.dart';

/// Home "Matches Near You" / "Matches in {region}".
///
/// Live + upcoming matches in the selected/GPS region, excluding the user's
/// own. Includes Network and everyone else (same idea as My Cricket → All,
/// scoped by location).
final nearbyMatchesProvider =
    FutureProvider.autoDispose<NearbyMatchesState>((ref) async {
  final link = ref.keepAlive();
  final timer = Future<void>.delayed(const Duration(minutes: 5), link.close);
  ref.onDispose(() => timer.ignore());

  final locationService = ref.watch(googleMapsLocationServiceProvider);
  final anchor = ref.watch(nearbyAnchorLocationProvider);
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  final player = await _nearbyPlayer(ref);
  final userTeamIds = _nearbyUserTeamIds(ref, player);
  final following = await _nearbyFollowing(ref, uid);
  final followedPlayers = FollowedPlayerRefs.fromUsers(following);

  List<MatchModel> matches;
  try {
    matches =
        await ref.read(matchRepositoryProvider).fetchLiveAndUpcomingMatches();
  } catch (e) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.error,
      message: 'Could not load matches: $e',
    );
  }

  final candidates = matches.where((m) {
    if (!_isLiveOrUpcoming(m)) return false;
    return !_excludeOwnMatch(
      m,
      uid: uid,
      player: player,
      userTeamIds: userTeamIds,
    );
  }).toList();

  if (anchor != null && !anchor.isEmpty) {
    return _buildFromRegionFilter(
      candidates: candidates,
      filter: anchor,
      following: following,
      followedPlayers: followedPlayers,
    );
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
    return _permissionDeniedFallback(
      ref: ref,
      candidates: candidates,
      following: following,
      followedPlayers: followedPlayers,
    );
  }

  final coords = await locationService.getCurrentCoords();
  if (coords == null) {
    return _permissionDeniedFallback(
      ref: ref,
      candidates: candidates,
      following: following,
      followedPlayers: followedPlayers,
    );
  }

  try {
    final resolved = await locationService.reverseGeocode(coords);
    return _buildFromRegionFilter(
      candidates: candidates,
      filter: resolved.location,
      following: following,
      followedPlayers: followedPlayers,
    );
  } catch (_) {
    return _permissionDeniedFallback(
      ref: ref,
      candidates: candidates,
      following: following,
      followedPlayers: followedPlayers,
    );
  }
});

bool _isLiveOrUpcoming(MatchModel m) {
  return MatchLifecycle.isEffectivelyLive(m) || MatchLifecycle.isUpcoming(m);
}

Future<PlayerModel?> _nearbyPlayer(Ref ref) async {
  try {
    return await ref.watch(myPlayerProvider.future);
  } catch (_) {
    return ref.read(myPlayerProvider).valueOrNull;
  }
}

Future<List<UserModel>> _nearbyFollowing(Ref ref, String? uid) async {
  if (uid == null || uid.isEmpty) return const [];
  try {
    return await ref.watch(playerFollowingProvider(uid).future);
  } catch (_) {
    return ref.read(playerFollowingProvider(uid)).valueOrNull ?? const [];
  }
}

Set<String> _nearbyUserTeamIds(Ref ref, PlayerModel? player) {
  final created = ref.watch(teamsProvider).valueOrNull ?? [];
  return {
    ...created.map((t) => t.id),
    ...?player?.effectiveTeamIds,
  };
}

bool _excludeOwnMatch(
  MatchModel m, {
  required String? uid,
  required PlayerModel? player,
  required Set<String> userTeamIds,
}) {
  if (m.isTournamentMatch) {
    return userTeamParticipatedInMatch(
      m,
      player: player,
      userTeamIds: userTeamIds,
    );
  }
  return userParticipatedInMatch(
    m,
    uid: uid,
    player: player,
    userTeamIds: userTeamIds,
  );
}

NearbyMatchesState _buildFromRegionFilter({
  required List<MatchModel> candidates,
  required LocationModel filter,
  required List<UserModel> following,
  required FollowedPlayerRefs followedPlayers,
  String message = '',
}) {
  final region = nearbyRegionFilter(filter);
  final regionLabel = nearbyRegionLabel(region);

  if (region.country.isEmpty && region.stateProvince.isEmpty) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.empty,
      regionLabel: regionLabel,
      message: 'Choose a state or province to see matches.',
    );
  }

  final items = <NearbyMatchItem>[];
  for (final m in candidates) {
    // Hard location filter (country + state/province), same as tournaments.
    if (!locationMatchesTextFilter(m.location, region)) continue;

    final fromNetwork = matchInvolvesFollowedPlayer(m, followedPlayers);
    items.add(
      NearbyMatchItem(
        match: m,
        regionFallback: true,
        fromNetwork: fromNetwork,
        attributionLabel: fromNetwork
            ? networkMatchAttribution(m, following)
            : null,
      ),
    );
  }

  // Live first, then Network (visible), then other matches in the region.
  items.sort((a, b) {
    final aLive = MatchLifecycle.isEffectivelyLive(a.match) ? 0 : 1;
    final bLive = MatchLifecycle.isEffectivelyLive(b.match) ? 0 : 1;
    if (aLive != bLive) return aLive.compareTo(bLive);
    if (a.fromNetwork != b.fromNetwork) {
      return a.fromNetwork ? -1 : 1;
    }
    final aAt = a.match.scheduledAt ?? a.match.createdAt;
    final bAt = b.match.scheduledAt ?? b.match.createdAt;
    if (aAt == null && bAt == null) return 0;
    if (aAt == null) return 1;
    if (bAt == null) return -1;
    return aAt.compareTo(bAt);
  });

  if (items.isEmpty) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.empty,
      regionLabel: regionLabel,
      message: message.isNotEmpty
          ? message
          : (regionLabel.isNotEmpty
              ? 'No live or upcoming matches in $regionLabel.'
              : 'No matches found for this location.'),
    );
  }

  return NearbyMatchesState(
    status: NearbyMatchesStatus.ready,
    items: _takeWithNetworkAndOthers(items, limit: 20),
    regionLabel: regionLabel,
    message: message,
  );
}

/// Prefer Network early, but always leave room for other regional matches.
List<NearbyMatchItem> _takeWithNetworkAndOthers(
  List<NearbyMatchItem> sorted, {
  required int limit,
}) {
  if (sorted.length <= limit) return List<NearbyMatchItem>.from(sorted);

  final live = sorted
      .where((i) => MatchLifecycle.isEffectivelyLive(i.match))
      .toList();
  final rest = sorted
      .where((i) => !MatchLifecycle.isEffectivelyLive(i.match))
      .toList();

  final selected = <NearbyMatchItem>[];
  final used = <String>{};

  void add(NearbyMatchItem item) {
    if (selected.length >= limit) return;
    if (used.add(item.match.id)) selected.add(item);
  }

  for (final item in live) {
    add(item);
  }

  final network = rest.where((i) => i.fromNetwork).toList();
  final others = rest.where((i) => !i.fromNetwork).toList();

  if (others.isEmpty || network.isEmpty) {
    for (final item in rest) {
      add(item);
    }
    return selected;
  }

  var i = 0;
  var j = 0;
  while (selected.length < limit &&
      (i < network.length || j < others.length)) {
    if (i < network.length) add(network[i++]);
    if (selected.length >= limit) break;
    if (j < others.length) add(others[j++]);
  }

  return selected;
}

NearbyMatchesState _permissionDeniedFallback({
  required Ref ref,
  required List<MatchModel> candidates,
  required List<UserModel> following,
  required FollowedPlayerRefs followedPlayers,
}) {
  final profile = ref.read(currentUserProfileProvider).valueOrNull;
  final loc = profile?.location;

  if (loc == null || loc.isEmpty) {
    return const NearbyMatchesState(
      status: NearbyMatchesStatus.permissionDenied,
      message:
          'Location permission denied. Enable location to discover matches near you.',
    );
  }

  final region = nearbyRegionFilter(loc);
  if (region.country.isEmpty && region.stateProvince.isEmpty) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.permissionDenied,
      message:
          'Location permission denied. Enable location to discover matches near you.',
      regionLabel: loc.displayLabel,
    );
  }

  final result = _buildFromRegionFilter(
    candidates: candidates,
    filter: region,
    following: following,
    followedPlayers: followedPlayers,
    message:
        'Showing matches in ${nearbyRegionLabel(region)} (precise location unavailable).',
  );

  if (result.status == NearbyMatchesStatus.ready) {
    return result;
  }

  return NearbyMatchesState(
    status: NearbyMatchesStatus.permissionDenied,
    message:
        'Location permission denied. Enable location to discover matches near you.',
    regionLabel: result.regionLabel,
  );
}
