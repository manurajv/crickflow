import '../../data/models/player_model.dart';

import '../../data/models/team_model.dart';



/// Shared team leadership helpers (used by repositories and UI).

class TeamLeadershipUtils {

  TeamLeadershipUtils._();



  static bool isTeamOwner(String? uid, TeamModel team) =>

      uid != null && uid.isNotEmpty && team.createdBy == uid;



  static bool isTeamCaptain(String? uid, TeamModel team) {

    if (uid == null || uid.isEmpty) return false;

    final capId = team.captainId;

    return capId != null && capId.isNotEmpty && capId == uid;

  }



  static bool isTeamViceCaptain(String? uid, TeamModel team) {

    if (uid == null || uid.isEmpty) return false;

    final vcId = team.viceCaptainId;

    return vcId != null && vcId.isNotEmpty && vcId == uid;

  }



  static bool canManageJoinRequests(String? uid, TeamModel team) =>

      isTeamOwner(uid, team) ||

      isTeamCaptain(uid, team) ||

      isTeamViceCaptain(uid, team);



  static bool isPlayerOwner(PlayerModel player, TeamModel team) {

    final ownerId = team.createdBy;

    if (ownerId == null || ownerId.isEmpty) return false;

    return player.id == ownerId || player.userId == ownerId;

  }



  static bool isCaptain(PlayerModel player, TeamModel team) =>

      team.captainId == player.id;



  static bool isViceCaptain(PlayerModel player, TeamModel team) =>

      team.viceCaptainId == player.id;



  static bool canRemoveMember({

    required String? actorUid,

    required TeamModel team,

    required PlayerModel target,

  }) {

    if (actorUid == null || actorUid.isEmpty) return false;

    if (isPlayerOwner(target, team)) return false;

    if (target.id == actorUid || target.userId == actorUid) return false;



    if (isTeamOwner(actorUid, team)) return true;



    final targetIsCaptain = isCaptain(target, team);

    final targetIsVc = isViceCaptain(target, team);



    if (isTeamCaptain(actorUid, team)) {

      return !targetIsCaptain && !targetIsVc;

    }



    if (isTeamViceCaptain(actorUid, team)) {

      return !targetIsCaptain;

    }



    return false;

  }



  static PlayerModel? pickNextOwner(TeamModel team, List<PlayerModel> others) {
    if (others.isEmpty) return null;

    final sorted = List<PlayerModel>.from(others)
      ..sort((a, b) => a.effectiveJoinedAt.compareTo(b.effectiveJoinedAt));
    return sorted.first;
  }

}


