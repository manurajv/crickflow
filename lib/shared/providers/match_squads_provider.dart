import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match_player_snapshot.dart';
import '../../data/models/match_setup_draft_models.dart';
import '../../data/models/player_model.dart';
import '../../data/models/team_model.dart';
import '../../data/repositories/player_repository.dart';
import 'providers.dart';

/// One team's frozen match squad from [MatchSetupData].
class MatchSquadSide {
  const MatchSquadSide({
    required this.teamName,
    this.teamLogoUrl,
    this.playing = const [],
    this.substitutes = const [],
    this.restOfTeam = const [],
    this.captainId,
    this.viceCaptainId,
    this.wicketKeeperId,
  });

  final String teamName;
  final String? teamLogoUrl;
  final List<MatchPlayerSnapshot> playing;
  final List<MatchPlayerSnapshot> substitutes;
  /// Team roster players not selected in playing XI or substitutes.
  final List<MatchPlayerSnapshot> restOfTeam;
  final String? captainId;
  final String? viceCaptainId;
  final String? wicketKeeperId;

  List<MatchPlayerSnapshot> get allPlayers =>
      [...playing, ...substitutes, ...restOfTeam];

  bool get hasPlaying => playing.isNotEmpty;
  bool get hasSubstitutes => substitutes.isNotEmpty;
  bool get hasRestOfTeam => restOfTeam.isNotEmpty;
}

class MatchDualSquads {
  const MatchDualSquads({
    required this.teamA,
    required this.teamB,
  });

  final MatchSquadSide teamA;
  final MatchSquadSide teamB;

  String get teamAName => teamA.teamName;
  String get teamBName => teamB.teamName;

  /// All frozen squad players (playing + substitutes) for lookups.
  List<MatchPlayerSnapshot> get teamAPlayers => teamA.allPlayers;
  List<MatchPlayerSnapshot> get teamBPlayers => teamB.allPlayers;

  bool get hasData => teamA.hasPlaying || teamB.hasPlaying;
}

extension MatchPlayerSnapshotLookup on MatchPlayerSnapshot {
  PlayerModel toPlayerModel() => PlayerModel(
        id: id,
        name: name,
        role: playingRole,
        battingStyle: battingStyle,
        bowlingStyle: bowlingStyle,
        photoUrl: photoUrl,
        playerId: playerId,
      );
}

final matchDualSquadsProvider =
    FutureProvider.family<MatchDualSquads, String>((ref, matchId) async {
  final match = await ref.watch(matchProvider(matchId).future);
  if (match == null) {
    return const MatchDualSquads(
      teamA: MatchSquadSide(teamName: 'Team A'),
      teamB: MatchSquadSide(teamName: 'Team B'),
    );
  }

  final teamRepo = ref.read(teamRepositoryProvider);
  final playerRepo = ref.read(playerRepositoryProvider);
  TeamModel? teamA;
  TeamModel? teamB;
  if (match.teamAId != null && match.teamAId!.isNotEmpty) {
    teamA = await teamRepo.getTeam(match.teamAId!);
  }
  if (match.teamBId != null && match.teamBId!.isNotEmpty) {
    teamB = await teamRepo.getTeam(match.teamBId!);
  }

  final setup = match.setup;
  if (setup == null) {
    return MatchDualSquads(
      teamA: MatchSquadSide(
        teamName: match.teamAName,
        teamLogoUrl: teamA?.profileImageUrl,
      ),
      teamB: MatchSquadSide(
        teamName: match.teamBName,
        teamLogoUrl: teamB?.profileImageUrl,
      ),
    );
  }

  return MatchDualSquads(
    teamA: await _sideFromSetup(
      setup: setup,
      isTeamA: true,
      teamId: match.teamAId,
      teamName: match.teamAName,
      teamLogoUrl: teamA?.profileImageUrl,
      playerRepo: playerRepo,
    ),
    teamB: await _sideFromSetup(
      setup: setup,
      isTeamA: false,
      teamId: match.teamBId,
      teamName: match.teamBName,
      teamLogoUrl: teamB?.profileImageUrl,
      playerRepo: playerRepo,
    ),
  );
});

Future<MatchSquadSide> _sideFromSetup({
  required MatchSetupData setup,
  required bool isTeamA,
  required String? teamId,
  required String teamName,
  String? teamLogoUrl,
  required PlayerRepository playerRepo,
}) async {
  final playing = setup.playingPlayersForTeam(isTeamA);
  final substitutes = setup.substitutePlayersForTeam(isTeamA);
  final restOfTeam = await _restOfTeamPlayers(
    teamId: teamId,
    playing: playing,
    substitutes: substitutes,
    playerRepo: playerRepo,
  );

  return MatchSquadSide(
    teamName: teamName,
    teamLogoUrl: teamLogoUrl,
    playing: playing,
    substitutes: substitutes,
    restOfTeam: restOfTeam,
    captainId: isTeamA ? setup.teamACaptainId : setup.teamBCaptainId,
    viceCaptainId:
        isTeamA ? setup.teamAViceCaptainId : setup.teamBViceCaptainId,
    wicketKeeperId:
        isTeamA ? setup.teamAWicketKeeperId : setup.teamBWicketKeeperId,
  );
}

Future<List<MatchPlayerSnapshot>> _restOfTeamPlayers({
  required String? teamId,
  required List<MatchPlayerSnapshot> playing,
  required List<MatchPlayerSnapshot> substitutes,
  required PlayerRepository playerRepo,
}) async {
  if (teamId == null || teamId.isEmpty) return [];

  final squadIds = <String>{
    for (final p in playing) p.id,
    for (final p in substitutes) p.id,
    for (final p in playing)
      if (p.playerId != null && p.playerId!.isNotEmpty) p.playerId!,
    for (final p in substitutes)
      if (p.playerId != null && p.playerId!.isNotEmpty) p.playerId!,
  };

  final roster = await playerRepo.getPlayersByTeam(teamId);
  return roster
      .where((p) => !squadIds.contains(p.id))
      .map(MatchPlayerSnapshot.fromPlayer)
      .toList();
}
