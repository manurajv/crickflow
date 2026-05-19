import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/lineup_player.dart';
import '../../data/models/match_model.dart';
import 'providers.dart';

class MatchLineupSquads {
  const MatchLineupSquads({
    required this.batting,
    required this.bowling,
  });

  final List<LineupPlayer> batting;
  final List<LineupPlayer> bowling;
}

final matchLineupSquadsProvider =
    FutureProvider.family<MatchLineupSquads, String>((ref, matchId) async {
  final match = await ref.read(matchRepositoryProvider).getMatch(matchId);
  if (match == null) {
    return const MatchLineupSquads(batting: [], bowling: []);
  }

  final playerRepo = ref.read(playerRepositoryProvider);
  final teamRepo = ref.read(teamRepositoryProvider);

  final inn = match.currentInnings;
  final battingTeamId = inn?.battingTeamId ?? match.teamAId;
  final bowlingTeamId = inn?.bowlingTeamId ?? match.teamBId;

  Future<List<LineupPlayer>> loadSquad(String? teamId, String fallbackName) async {
    if (teamId == null || teamId.isEmpty || teamId.startsWith('team_')) {
      return [LineupPlayer(id: 'guest_${fallbackName.hashCode}', name: fallbackName)];
    }
    final players = await playerRepo.getPlayersByTeam(teamId);
    if (players.isNotEmpty) {
      return players.map(LineupPlayer.fromPlayer).toList();
    }
    final team = await teamRepo.getTeam(teamId);
    if (team != null) {
      return [LineupPlayer(id: team.id, name: team.name)];
    }
    return [LineupPlayer(id: 'guest_$teamId', name: fallbackName)];
  }

  final battingName = _teamDisplayName(match, battingTeamId, isA: true);
  final bowlingName = _teamDisplayName(match, bowlingTeamId, isA: false);

  final batting = await loadSquad(battingTeamId, battingName);
  final bowling = await loadSquad(bowlingTeamId, bowlingName);

  return MatchLineupSquads(batting: batting, bowling: bowling);
});

String _teamDisplayName(MatchModel match, String? teamId, {required bool isA}) {
  if (teamId == match.teamAId) return match.teamAName;
  if (teamId == match.teamBId) return match.teamBName;
  return isA ? match.teamAName : match.teamBName;
}
