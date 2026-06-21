import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../../data/models/player_social_stats_model.dart';
import '../../data/repositories/player_discovery_repository.dart';
import '../../data/repositories/player_follow_repository.dart';
import 'providers.dart';

final playerFollowRepositoryProvider = Provider<PlayerFollowRepository>((ref) {
  return PlayerFollowRepository(
    notificationRepository: ref.watch(notificationRepositoryProvider),
  );
});

final playerDiscoveryRepositoryProvider =
    Provider<PlayerDiscoveryRepository>((ref) {
  return PlayerDiscoveryRepository(
    followRepository: ref.watch(playerFollowRepositoryProvider),
  );
});

/// Resolve a public player ID (CF000001) to a user profile stream.
final userByPlayerIdProvider =
    StreamProvider.family<UserModel?, String>((ref, playerId) {
  final repo = ref.watch(userRepositoryProvider);
  return repo.watchUserByPlayerId(playerId);
});

final playerSocialStatsProvider =
    StreamProvider.family<PlayerSocialStatsModel, String>((ref, userId) {
  return ref.watch(playerFollowRepositoryProvider).watchSocialStats(userId);
});

final isFollowingPlayerProvider =
    StreamProvider.family<bool, ({String followerId, String followedId})>(
  (ref, ids) {
    return ref.watch(playerFollowRepositoryProvider).watchIsFollowing(
          followerUserId: ids.followerId,
          followedUserId: ids.followedId,
        );
  },
);

final playerFollowersProvider =
    StreamProvider.family<List<UserModel>, String>((ref, userId) {
  return ref
      .watch(playerFollowRepositoryProvider)
      .watchFollowers(userId: userId);
});

final playerFollowingProvider =
    StreamProvider.family<List<UserModel>, String>((ref, userId) {
  return ref
      .watch(playerFollowRepositoryProvider)
      .watchFollowing(userId: userId);
});

final suggestedPlayersProvider = FutureProvider<List<UserModel>>((ref) async {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return [];
  return ref.read(playerDiscoveryRepositoryProvider).searchPlayers(
        query: '',
        currentUserId: uid,
        filter: FindCricketersFilter.suggested,
        currentUser: ref.read(currentUserProfileProvider).valueOrNull,
      );
});
