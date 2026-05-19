import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../data/models/player_model.dart';
import 'providers.dart';

/// Linked player profile for the signed-in user (doc id = auth uid).
final myPlayerProvider = FutureProvider<PlayerModel?>((ref) async {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return null;

  final repo = ref.watch(playerRepositoryProvider);
  var player = await repo.getPlayerByUserId(uid);
  if (player != null) return player;

  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  if (profile == null || profile.role == UserRole.viewer) return null;

  return repo.ensurePlayerProfileForUser(
    userId: uid,
    displayName: profile.displayName,
    photoUrl: profile.photoUrl,
    email: profile.email,
  );
});
