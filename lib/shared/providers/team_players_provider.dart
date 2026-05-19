import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/player_model.dart';
import 'providers.dart';

/// Stable stream of players for a team (by `teamId` query + `team.playerIds` fallback).
final teamPlayersProvider =
    StreamProvider.family<List<PlayerModel>, String>((ref, teamId) {
  return ref.watch(playerRepositoryProvider).watchPlayersForTeam(teamId);
});
