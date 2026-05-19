import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/badge_model.dart';
import '../../data/models/player_model.dart';
import '../../data/repositories/badge_repository.dart';
import 'providers.dart';

final badgeRepositoryProvider = Provider((ref) => BadgeRepository());

final userBadgesProvider =
    FutureProvider.family<List<BadgeModel>, List<String>>((ref, badgeIds) {
  return ref.watch(badgeRepositoryProvider).getBadgesByIds(badgeIds);
});

final playerDetailProvider =
    FutureProvider.family<PlayerModel?, String>((ref, playerId) {
  return ref.watch(playerRepositoryProvider).getPlayer(playerId);
});
