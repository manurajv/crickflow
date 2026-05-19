import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/player_model.dart';
import '../../data/models/team_model.dart';
import 'providers.dart';

class MatchDualSquads {
  const MatchDualSquads({
    required this.teamAName,
    required this.teamBName,
    this.teamAId,
    this.teamBId,
    this.teamA,
    this.teamB,
    this.teamAPlayers = const [],
    this.teamBPlayers = const [],
  });

  final String teamAName;
  final String teamBName;
  final String? teamAId;
  final String? teamBId;
  final TeamModel? teamA;
  final TeamModel? teamB;
  final List<PlayerModel> teamAPlayers;
  final List<PlayerModel> teamBPlayers;
}

final matchDualSquadsProvider =
    FutureProvider.family<MatchDualSquads, String>((ref, matchId) async {
  final match = await ref.read(matchRepositoryProvider).getMatch(matchId);
  if (match == null) {
    return const MatchDualSquads(teamAName: 'Team A', teamBName: 'Team B');
  }

  final playerRepo = ref.read(playerRepositoryProvider);
  final teamRepo = ref.read(teamRepositoryProvider);

  TeamModel? teamA;
  TeamModel? teamB;
  if (match.teamAId != null && match.teamAId!.isNotEmpty) {
    teamA = await teamRepo.getTeam(match.teamAId!);
  }
  if (match.teamBId != null && match.teamBId!.isNotEmpty) {
    teamB = await teamRepo.getTeam(match.teamBId!);
  }

  final playersA = match.teamAId != null && match.teamAId!.isNotEmpty
      ? await playerRepo.getPlayersByTeam(match.teamAId!)
      : <PlayerModel>[];
  final playersB = match.teamBId != null && match.teamBId!.isNotEmpty
      ? await playerRepo.getPlayersByTeam(match.teamBId!)
      : <PlayerModel>[];

  return MatchDualSquads(
    teamAName: match.teamAName,
    teamBName: match.teamBName,
    teamAId: match.teamAId,
    teamBId: match.teamBId,
    teamA: teamA,
    teamB: teamB,
    teamAPlayers: playersA,
    teamBPlayers: playersB,
  );
});
