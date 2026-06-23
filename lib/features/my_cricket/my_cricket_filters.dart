import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_player_snapshot.dart';
import '../../data/models/player_model.dart';
import '../../data/models/tournament_model.dart';
import '../../data/models/user_model.dart';

/// Your · Played · Network · All filters for My Cricket tabs.
enum MyCricketListScope { yours, played, network, all }

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
  for (final teamId in player?.effectiveTeamIds ?? const <String>[]) {
    if (m.teamAId == teamId || m.teamBId == teamId) return true;
  }
  if (m.teamAId != null && userTeamIds.contains(m.teamAId)) return true;
  if (m.teamBId != null && userTeamIds.contains(m.teamBId)) return true;
  return false;
}

/// Firebase uids / player doc ids and CF player ids for people you follow.
class FollowedPlayerRefs {
  const FollowedPlayerRefs({
    this.linkedIds = const {},
    this.cfPlayerIds = const {},
  });

  final Set<String> linkedIds;
  final Set<String> cfPlayerIds;

  bool get isEmpty => linkedIds.isEmpty && cfPlayerIds.isEmpty;

  factory FollowedPlayerRefs.fromUsers(Iterable<UserModel> users) {
    final linked = <String>{};
    final cf = <String>{};
    for (final user in users) {
      if (user.id.isNotEmpty) linked.add(user.id);
      final cfId = user.playerId;
      if (cfId != null && cfId.isNotEmpty) cf.add(cfId);
    }
    return FollowedPlayerRefs(linkedIds: linked, cfPlayerIds: cf);
  }

  bool matches({String? docId, String? cfPlayerId}) {
    if (docId != null && docId.isNotEmpty && linkedIds.contains(docId)) {
      return true;
    }
    if (cfPlayerId != null &&
        cfPlayerId.isNotEmpty &&
        cfPlayerIds.contains(cfPlayerId)) {
      return true;
    }
    return false;
  }
}

bool matchInvolvesFollowedPlayer(MatchModel m, FollowedPlayerRefs refs) {
  if (refs.isEmpty) return false;

  for (final followedUid in refs.linkedIds) {
    if (m.createdBy == followedUid) return true;
    if (m.scorerIds.contains(followedUid)) return true;
    if (m.scorer1UserId == followedUid ||
        m.scorer2UserId == followedUid ||
        m.currentScorerId == followedUid) {
      return true;
    }
  }

  if (refs.matches(docId: m.playerOfMatchId)) return true;
  final hero = m.matchHero;
  if (hero != null && refs.matches(docId: hero.playerId)) return true;

  final setup = m.setup;
  if (setup != null) {
    for (final snapshot in <MatchPlayerSnapshot>[
      ...setup.teamAPlayingPlayers,
      ...setup.teamASubstitutePlayers,
      ...setup.teamBPlayingPlayers,
      ...setup.teamBSubstitutePlayers,
    ]) {
      if (refs.matches(docId: snapshot.id, cfPlayerId: snapshot.playerId)) {
        return true;
      }
    }

    for (final official in <String?>[
      setup.teamACaptainId,
      setup.teamAViceCaptainId,
      setup.teamAWicketKeeperId,
      setup.teamBCaptainId,
      setup.teamBViceCaptainId,
      setup.teamBWicketKeeperId,
    ]) {
      if (refs.matches(docId: official)) return true;
    }
  }

  for (final innings in m.innings) {
    for (final id in <String?>[
      innings.strikerId,
      innings.nonStrikerId,
      innings.currentBowlerId,
      innings.currentWicketKeeperId,
    ]) {
      if (refs.matches(docId: id)) return true;
    }
    for (final batter in innings.batsmen) {
      if (refs.matches(docId: batter.playerId)) return true;
    }
    for (final bowler in innings.bowlers) {
      if (refs.matches(docId: bowler.playerId)) return true;
    }
    for (final fielder in innings.fielders) {
      if (refs.matches(docId: fielder.playerId)) return true;
    }
    for (final fow in innings.fallOfWickets) {
      if (refs.matches(docId: fow.batsmanId)) return true;
    }
  }

  return false;
}

bool filterMatchByScope(
  MatchModel m,
  MyCricketListScope scope, {
  String? uid,
  PlayerModel? player,
  Set<String> userTeamIds = const {},
  FollowedPlayerRefs followedPlayers = const FollowedPlayerRefs(),
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
    case MyCricketListScope.network:
      if (userParticipatedInMatch(
        m,
        uid: uid,
        player: player,
        userTeamIds: userTeamIds,
      )) {
        return false;
      }
      return matchInvolvesFollowedPlayer(m, followedPlayers);
  }
}

bool userHostsTournament(TournamentModel t, String? uid) {
  return uid != null && t.effectiveOrganizerId == uid;
}

bool userParticipatedInTournament(
  TournamentModel t, {
  String? uid,
  Set<String> userTeamIds = const {},
}) {
  if (userHostsTournament(t, uid)) return true;
  return t.teamIds.any(userTeamIds.contains);
}

bool tournamentInvolvesFollowedUser(
  TournamentModel t,
  FollowedPlayerRefs refs,
) {
  if (refs.isEmpty) return false;
  return refs.linkedIds.contains(t.effectiveOrganizerId);
}

bool filterTournamentByScope(
  TournamentModel t,
  MyCricketListScope scope, {
  String? uid,
  Set<String> userTeamIds = const {},
  FollowedPlayerRefs followedPlayers = const FollowedPlayerRefs(),
}) {
  switch (scope) {
    case MyCricketListScope.all:
      return true;
    case MyCricketListScope.yours:
      return userParticipatedInTournament(t, uid: uid, userTeamIds: userTeamIds);
    case MyCricketListScope.played:
      return t.status == TournamentStatus.completed &&
          userParticipatedInTournament(t, uid: uid, userTeamIds: userTeamIds);
    case MyCricketListScope.network:
      if (userParticipatedInTournament(
        t,
        uid: uid,
        userTeamIds: userTeamIds,
      )) {
        return false;
      }
      return tournamentInvolvesFollowedUser(t, followedPlayers);
  }
}
