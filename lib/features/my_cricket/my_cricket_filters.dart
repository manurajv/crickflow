import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../data/models/player_model.dart';
import '../../data/models/tournament_model.dart';

/// Your · Played · All filters for My Cricket tabs.
enum MyCricketListScope { yours, played, all }

bool userOwnsOrScoresMatch(MatchModel m, String? uid) {
  if (uid == null) return false;
  return m.createdBy == uid || m.scorerIds.contains(uid);
}

bool userParticipatedInMatch(
  MatchModel m, {
  String? uid,
  PlayerModel? player,
  Set<String> userTeamIds = const {},
}) {
  if (userOwnsOrScoresMatch(m, uid)) return true;
  final teamId = player?.teamId;
  if (teamId != null && teamId.isNotEmpty) {
    if (m.teamAId == teamId || m.teamBId == teamId) return true;
  }
  if (m.teamAId != null && userTeamIds.contains(m.teamAId)) return true;
  if (m.teamBId != null && userTeamIds.contains(m.teamBId)) return true;
  return false;
}

bool filterMatchByScope(
  MatchModel m,
  MyCricketListScope scope, {
  String? uid,
  PlayerModel? player,
  Set<String> userTeamIds = const {},
}) {
  switch (scope) {
    case MyCricketListScope.all:
      return true;
    case MyCricketListScope.yours:
      return userParticipatedInMatch(
        m,
        uid: uid,
        player: player,
        userTeamIds: userTeamIds,
      );
    case MyCricketListScope.played:
      return m.status == MatchStatus.completed &&
          userParticipatedInMatch(
            m,
            uid: uid,
            player: player,
            userTeamIds: userTeamIds,
          );
  }
}

bool userHostsTournament(TournamentModel t, String? uid) {
  return uid != null && t.createdBy == uid;
}

bool userParticipatedInTournament(
  TournamentModel t, {
  String? uid,
  Set<String> userTeamIds = const {},
}) {
  if (userHostsTournament(t, uid)) return true;
  return t.teamIds.any(userTeamIds.contains);
}

bool filterTournamentByScope(
  TournamentModel t,
  MyCricketListScope scope, {
  String? uid,
  Set<String> userTeamIds = const {},
}) {
  switch (scope) {
    case MyCricketListScope.all:
      return true;
    case MyCricketListScope.yours:
      return userParticipatedInTournament(t, uid: uid, userTeamIds: userTeamIds);
    case MyCricketListScope.played:
      return t.status == TournamentStatus.completed &&
          userParticipatedInTournament(t, uid: uid, userTeamIds: userTeamIds);
  }
}
