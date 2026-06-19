import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/lineup_player.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_setup_draft_models.dart';
import '../../domain/scoring/toss_team_policy.dart';
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
  final match = await ref.watch(matchProvider(matchId).future);
  if (match == null) {
    return const MatchLineupSquads(batting: [], bowling: []);
  }

  final playerRepo = ref.read(playerRepositoryProvider);
  final teamRepo = ref.read(teamRepositoryProvider);

  final inn = match.currentInnings ?? match.innings.firstOrNull;
  final teams = inn != null
      ? (
          battingTeamId: inn.battingTeamId,
          bowlingTeamId: inn.bowlingTeamId,
        )
      : TossTeamPolicy.firstInningsTeams(match);
  final battingTeamId = teams.battingTeamId;
  final bowlingTeamId = teams.bowlingTeamId;

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

  final batting = _matchPlayingSquad(
    match: match,
    teamId: battingTeamId,
    loaded: await loadSquad(battingTeamId, battingName),
  );
  final bowling = _matchPlayingSquad(
    match: match,
    teamId: bowlingTeamId,
    loaded: await loadSquad(bowlingTeamId, bowlingName),
  );

  return MatchLineupSquads(batting: batting, bowling: bowling);
});

/// Only players picked in match setup squads may bat or bowl in this match.
List<LineupPlayer> _matchPlayingSquad({
  required MatchModel match,
  required String? teamId,
  required List<LineupPlayer> loaded,
}) {
  final setup = match.setup;
  if (setup == null || teamId == null || teamId.isEmpty) return loaded;

  final isTeamA = teamId == match.teamAId;
  final ids = setup.squadIdsForTeam(isTeamA);
  if (ids.isEmpty) return loaded;

  final names = setup.squadNamesForTeam(isTeamA);
  return [
    for (final id in ids)
      _resolveLineupPlayer(
        id: id,
        fallbackName: names[id] ?? 'Player',
        loaded: loaded,
        setup: setup,
        isTeamA: isTeamA,
      ),
  ];
}

LineupPlayer _resolveLineupPlayer({
  required String id,
  required String fallbackName,
  required List<LineupPlayer> loaded,
  required MatchSetupData setup,
  required bool isTeamA,
}) {
  final snapshot = setup.findPlayingSnapshot(isTeamA, id);
  final fromLoaded = loaded.where((p) => p.id == id).firstOrNull;
  if (fromLoaded != null) {
    final photo = fromLoaded.photoUrl ?? snapshot?.photoUrl;
    if (photo != fromLoaded.photoUrl) {
      return LineupPlayer(
        id: fromLoaded.id,
        name: fromLoaded.name,
        photoUrl: photo,
      );
    }
    return fromLoaded;
  }
  return LineupPlayer(
    id: id,
    name: snapshot?.name ?? fallbackName,
    photoUrl: snapshot?.photoUrl,
  );
}

String _teamDisplayName(MatchModel match, String? teamId, {required bool isA}) {
  if (teamId == match.teamAId) return match.teamAName;
  if (teamId == match.teamBId) return match.teamBName;
  return isA ? match.teamAName : match.teamBName;
}
