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

/// Home "Matches Near You" — region text filter (country + state/province).
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
    matches = await ref.watch(matchesProvider.future);
  } catch (e) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.error,
      message: 'Could not load matches: $e',
    );
  }

  // Discover others nearby. User's own friendlies stay in My Cricket.
  // Tournament fixtures: hide only when the user's team is playing that match
  // (still show other fixtures from a tournament their team is entered in).
  final candidates = matches.where((m) {
    if (_excludeFromNearbyMatches(
      m,
      uid: uid,
      player: player,
      userTeamIds: userTeamIds,
    )) {
      return false;
    }
    if (MatchLifecycle.isEffectivelyLive(m)) return true;
    if (MatchLifecycle.isUpcoming(m)) return true;
    if (MatchLifecycle.isCompleted(m)) {
      final completed = m.completedAt;
      if (completed == null) return true;
      return DateTime.now().difference(completed).inDays <= 7;
    }
    return false;
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

/// Tournament matches: exclude only if user's team is in this fixture.
/// Standalone matches: exclude creator / scorer / team involvement.
bool _excludeFromNearbyMatches(
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

  // Network matches first (same people as My Cricket → Network).
  items.sort((a, b) {
    if (a.fromNetwork != b.fromNetwork) {
      return a.fromNetwork ? -1 : 1;
    }
    return 0;
  });

  if (items.isEmpty) {
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
    items: items.take(20).toList(),
    regionLabel: regionLabel,
  );
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
  );
  if (result.status == NearbyMatchesStatus.ready) {
    return NearbyMatchesState(
      status: NearbyMatchesStatus.ready,
      items: result.items,
      regionLabel: result.regionLabel,
      message:
          'Showing matches in ${result.regionLabel} (precise location unavailable).',
    );
  }

  return NearbyMatchesState(
    status: NearbyMatchesStatus.permissionDenied,
    message:
        'Location permission denied. Enable location to discover matches near you.',
    regionLabel: result.regionLabel,
  );
}
