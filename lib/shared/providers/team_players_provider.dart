import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/player_model.dart';
import 'providers.dart';

/// Stable stream of players for a team (by `teamId` query + `team.playerIds` fallback).
final teamPlayersProvider =
    StreamProvider.family<List<PlayerModel>, String>((ref, teamId) {
  return ref.watch(playerRepositoryProvider).watchPlayersForTeam(teamId);
});

/// Full legal name for squad UI — uses [PlayerModel.fullName] or user profile fallback.
final playerSquadFullNameProvider =
    FutureProvider.family<String, PlayerModel>((ref, player) async {
  if (player.fullName.isNotEmpty) return player.fullName;
  final uid = player.userId ?? player.id;
  final user = await ref.read(userRepositoryProvider).getUser(uid);
  if (user != null && user.name.isNotEmpty) return user.name;
  return player.name;
});
