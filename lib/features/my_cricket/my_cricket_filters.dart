import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../domain/scoring/match_lifecycle.dart';
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

bool userTeamParticipatedInMatch(
  MatchModel m, {
  PlayerModel? player,
  Set<String> userTeamIds = const {},
}) {
  for (final teamId in player?.effectiveTeamIds ?? const <String>[]) {
    if (m.teamAId == teamId || m.teamBId == teamId) return true;
  }
  if (m.teamAId != null && userTeamIds.contains(m.teamAId)) return true;
  if (m.teamBId != null && userTeamIds.contains(m.teamBId)) return true;
  return false;
}

bool userParticipatedInMatch(
  MatchModel m, {
  String? uid,
  PlayerModel? player,
  Set<String> userTeamIds = const {},
}) {
  if (userOwnsOrScoresMatch(m, uid)) return true;
  return userTeamParticipatedInMatch(
    m,
    player: player,
    userTeamIds: userTeamIds,
  );
}

bool userTeamParticipatedInTournament(
  TournamentModel t, {
  Set<String> userTeamIds = const {},
}) {
  return t.teamIds.any(userTeamIds.contains);
}

bool userParticipatedInTournament(
  TournamentModel t, {
  String? uid,
  Set<String> userTeamIds = const {},
}) {
  if (userHostsTournament(t, uid)) return true;
  return userTeamParticipatedInTournament(t, userTeamIds: userTeamIds);
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
      return userTeamParticipatedInMatch(
        m,
        player: player,
        userTeamIds: userTeamIds,
      );
    case MyCricketListScope.played:
      return MatchLifecycle.isCompleted(m) &&
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

bool tournamentInvolvesFollowedUser(
  TournamentModel t,
  FollowedPlayerRefs refs,
) {
  if (refs.isEmpty) return false;
  return refs.linkedIds.contains(t.effectiveOrganizerId);
}

/// Resolves which followed person made this match appear in Network.
/// Prefer creator → scorer → playing player.
String? networkMatchAttribution(
  MatchModel m,
  List<UserModel> following,
) {
  if (following.isEmpty) return null;

  final byUid = <String, UserModel>{
    for (final u in following)
      if (u.id.isNotEmpty) u.id: u,
  };
  final byCfId = <String, UserModel>{
    for (final u in following)
      if (u.playerId != null && u.playerId!.isNotEmpty) u.playerId!: u,
  };

  String labelFor(UserModel u) => "${u.effectiveName}'s match";

  UserModel? byDocOrCf({String? docId, String? cfPlayerId}) {
    if (docId != null && docId.isNotEmpty) {
      final u = byUid[docId];
      if (u != null) return u;
    }
    if (cfPlayerId != null && cfPlayerId.isNotEmpty) {
      return byCfId[cfPlayerId];
    }
    return null;
  }

  final creator = byUid[m.createdBy];
  if (creator != null) return labelFor(creator);

  for (final uid in m.scorerIds) {
    final u = byUid[uid];
    if (u != null) return labelFor(u);
  }
  for (final uid in [
    m.scorer1UserId,
    m.scorer2UserId,
    m.currentScorerId,
  ]) {
    if (uid == null || uid.isEmpty) continue;
    final u = byUid[uid];
    if (u != null) return labelFor(u);
  }

  if (m.playerOfMatchId != null) {
    final u = byDocOrCf(docId: m.playerOfMatchId);
    if (u != null) return labelFor(u);
  }
  final hero = m.matchHero;
  if (hero != null) {
    final u = byDocOrCf(docId: hero.playerId);
    if (u != null) return labelFor(u);
  }

  final setup = m.setup;
  if (setup != null) {
    for (final snapshot in <MatchPlayerSnapshot>[
      ...setup.teamAPlayingPlayers,
      ...setup.teamASubstitutePlayers,
      ...setup.teamBPlayingPlayers,
      ...setup.teamBSubstitutePlayers,
    ]) {
      final u = byDocOrCf(docId: snapshot.id, cfPlayerId: snapshot.playerId);
      if (u != null) return labelFor(u);
      // Snapshot name fallback when follow graph matches by id but user list miss
      if (FollowedPlayerRefs.fromUsers(following)
          .matches(docId: snapshot.id, cfPlayerId: snapshot.playerId)) {
        final name = snapshot.name.trim();
        if (name.isNotEmpty) return "$name's match";
      }
    }
  }

  for (final innings in m.innings) {
    for (final id in <String?>[
      innings.strikerId,
      innings.nonStrikerId,
      innings.currentBowlerId,
      innings.currentWicketKeeperId,
    ]) {
      final u = byDocOrCf(docId: id);
      if (u != null) return labelFor(u);
    }
    for (final batter in innings.batsmen) {
      final u = byDocOrCf(docId: batter.playerId);
      if (u != null) return labelFor(u);
    }
    for (final bowler in innings.bowlers) {
      final u = byDocOrCf(docId: bowler.playerId);
      if (u != null) return labelFor(u);
    }
  }

  return null;
}

/// Organizer attribution for Network tournament cards.
String? networkTournamentAttribution(
  TournamentModel t,
  List<UserModel> following,
) {
  if (following.isEmpty) return null;
  final organizerId = t.effectiveOrganizerId;
  if (organizerId.isEmpty) return null;
  for (final u in following) {
    if (u.id == organizerId) return "${u.effectiveName}'s tournament";
  }
  return null;
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
      return userTeamParticipatedInTournament(t, userTeamIds: userTeamIds);
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
