import '../../data/models/innings_model.dart';
import '../../data/models/lineup_player.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_player_snapshot.dart';
import '../../data/models/match_setup_draft_models.dart';
import 'cricket_math.dart';

const _typedTeamAId = 'team_a';
const _typedTeamBId = 'team_b';

/// Whether [teamId] is team A in this match (handles typed `team_a` / `team_b` ids).
bool matchTeamIsTeamA(MatchModel match, String? teamId) {
  if (teamId == null || teamId.isEmpty) return true;
  final a = match.teamAId;
  final b = match.teamBId;
  if (a != null && a.isNotEmpty && teamId == a) return true;
  if (b != null && b.isNotEmpty && teamId == b) return false;
  if (teamId == _typedTeamAId) return true;
  if (teamId == _typedTeamBId) return false;
  return true;
}

String quickMatchTeamLabel(MatchModel match, String? teamId) {
  if (teamId == null || teamId.isEmpty) return match.teamAName;
  if (matchTeamIsTeamA(match, teamId)) {
    return match.teamAName.isNotEmpty ? match.teamAName : 'Team A';
  }
  return match.teamBName.isNotEmpty ? match.teamBName : 'Team B';
}

/// Quick Match squad for one side: roster + setup + anyone already used for that team.
List<LineupPlayer> buildQuickMatchTeamSquad({
  required MatchModel match,
  required String? teamId,
  required List<LineupPlayer> loadedRoster,
}) {
  if (teamId == null || teamId.isEmpty) return const [];

  final isTeamA = matchTeamIsTeamA(match, teamId);
  final byId = <String, LineupPlayer>{};

  void add(String id, String name, {String? photoUrl}) {
    if (id.isEmpty || name.isEmpty) return;
    byId[id] = LineupPlayer(id: id, name: name, photoUrl: photoUrl);
  }

  for (final p in loadedRoster) {
    add(p.id, p.name, photoUrl: p.photoUrl);
  }

  final setup = match.setup;
  if (setup != null) {
    for (final snap in _setupPlayersForTeam(setup, isTeamA)) {
      add(snap.id, snap.name, photoUrl: snap.photoUrl);
    }
  }

  for (final inn in match.innings) {
    if (inn.battingTeamId != teamId && inn.bowlingTeamId != teamId) {
      continue;
    }
    if (inn.battingTeamId == teamId) {
      for (final b in inn.batsmen) {
        add(b.playerId, b.playerName);
      }
    }
    if (inn.bowlingTeamId == teamId) {
      for (final b in inn.bowlers) {
        add(b.playerId, b.playerName);
      }
      for (final f in inn.fielders) {
        add(f.playerId, f.playerName);
      }
      final keeperId = inn.currentWicketKeeperId;
      final keeperName = inn.currentWicketKeeperName;
      if (keeperId != null &&
          keeperId.isNotEmpty &&
          keeperName != null &&
          keeperName.isNotEmpty) {
        add(keeperId, keeperName);
      }
    }
  }

  final players = byId.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return players;
}

Iterable<MatchPlayerSnapshot> _setupPlayersForTeam(
  MatchSetupData setup,
  bool isTeamA,
) {
  return [
    ...setup.playingPlayersForTeam(isTeamA),
    ...setup.substitutePlayersForTeam(isTeamA),
  ];
}

/// Walk-in / match-only players for [teamId] not already listed in [teamPlayers].
List<LineupPlayer> quickMatchWalkInsForTeam({
  required MatchModel match,
  required String? teamId,
  required List<LineupPlayer> teamPlayers,
}) {
  final setup = match.setup;
  if (setup == null || teamId == null || teamId.isEmpty) return const [];

  final isTeamA = matchTeamIsTeamA(match, teamId);
  final listed = teamPlayers.map((p) => p.id).toSet();
  return [
    for (final p in _setupPlayersForTeam(setup, isTeamA))
      if (p.isMatchOnlyPlayer && !listed.contains(p.id))
        LineupPlayer(id: p.id, name: p.name, photoUrl: p.photoUrl),
  ];
}

/// Bowler figures for the picker list (current innings).
Map<String, String> buildBowlerPickerSubtitles(
  InningsModel inn,
  int ballsPerOver,
) {
  final subtitles = <String, String>{};
  for (final b in inn.bowlers) {
    if (b.playerId.isEmpty) continue;
    final overs = CricketMath.formatOvers(b.oversBowledBalls, ballsPerOver);
    subtitles[b.playerId] =
        '$overs overs · ${b.runsConceded} runs · ${b.wickets} wkts';
  }
  return subtitles;
}
