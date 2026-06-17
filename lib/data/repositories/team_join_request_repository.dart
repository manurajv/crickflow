import 'package:cloud_firestore/cloud_firestore.dart';



import '../../core/constants/app_constants.dart';

import '../../core/utils/team_leadership_utils.dart';

import '../models/player_model.dart';

import '../models/team_join_request_model.dart';

import '../models/team_model.dart';

import '../models/user_model.dart';

import 'notification_repository.dart';

import 'player_repository.dart';



class TeamJoinRequestRepository {

  TeamJoinRequestRepository({

    FirebaseFirestore? firestore,

    PlayerRepository? playerRepository,

    NotificationRepository? notificationRepository,

  }) : _firestore = firestore ?? FirebaseFirestore.instance,

       _playerRepository = playerRepository ?? PlayerRepository(firestore: firestore),

       _notificationRepository =

           notificationRepository ?? NotificationRepository(firestore: firestore);



  final FirebaseFirestore _firestore;

  final PlayerRepository _playerRepository;

  final NotificationRepository _notificationRepository;



  CollectionReference<Map<String, dynamic>> get _teams =>

      _firestore.collection(AppConstants.teamsCollection);



  CollectionReference<Map<String, dynamic>> _requests(String teamId) =>

      _teams.doc(teamId).collection(AppConstants.teamJoinRequestsSubcollection);



  Stream<TeamJoinRequestModel?> watchRequest(String teamId, String userId) {

    return _requests(teamId).doc(userId).snapshots().map((doc) {

      if (!doc.exists) return null;

      return TeamJoinRequestModel.fromMap(doc.id, teamId, doc.data()!);

    });

  }



  Stream<List<TeamJoinRequestModel>> watchPendingForTeam(String teamId) {

    return _requests(teamId)

        .where('status', isEqualTo: TeamJoinRequestStatus.pending.name)

        .orderBy('createdAt', descending: true)

        .snapshots()

        .map(

          (snap) => snap.docs

              .map((d) => TeamJoinRequestModel.fromMap(d.id, teamId, d.data()))

              .toList(),

        );

  }



  Future<void> _assertCanRequest({

    required TeamModel team,

    required String userId,

    required PlayerModel player,

  }) async {

    if (TeamLeadershipUtils.isTeamOwner(userId, team)) {

      throw StateError('You already own this team');

    }

    if (TeamLeadershipUtils.isTeamCaptain(userId, team) ||

        TeamLeadershipUtils.isTeamViceCaptain(userId, team)) {

      throw StateError('You are already on this team leadership');

    }

    if (team.playerIds.contains(userId) || player.isOnTeam(team.id)) {

      throw StateError('You are already on this team');

    }



    final existing = await _requests(team.id).doc(userId).get();

    if (existing.exists) {

      final current = TeamJoinRequestModel.fromMap(

        existing.id,

        team.id,

        existing.data()!,

      );

      if (current.isPending) {

        throw StateError('You already have a pending join request');

      }

    }

  }



  Future<TeamJoinRequestModel> createRequest({

    required TeamModel team,

    required PlayerModel player,

    UserModel? profile,

  }) async {

    final userId = player.userId ?? player.id;

    await _assertCanRequest(team: team, userId: userId, player: player);



    final ref = _requests(team.id).doc(userId);

    final existing = await ref.get();

    if (existing.exists) {

      final current = TeamJoinRequestModel.fromMap(

        existing.id,

        team.id,

        existing.data()!,

      );

      if (current.isPending) return current;

      await ref.delete();

    }



    final now = DateTime.now();

    final request = TeamJoinRequestModel(

      id: userId,

      teamId: team.id,

      teamName: team.name,

      userId: userId,

      playerId: player.id,

      playerName: player.name,

      playerFullName: player.fullName.isNotEmpty

          ? player.fullName

          : (profile?.name ?? ''),

      playerPhotoUrl: player.photoUrl ?? profile?.photoUrl,

      cfPlayerId: player.playerId ?? profile?.playerId,

      status: TeamJoinRequestStatus.pending,

      createdAt: now,

      updatedAt: now,

    );



    await ref.set(request.toMap());



    final message = '${request.displayName} requested to join ${team.name}';

    await _notificationRepository.notifyTeamLeadership(

      team: team,

      title: 'Join request',

      body: message,

      type: 'team_join_request',

      playerId: userId,

      excludeUserId: userId,

    );



    return request;

  }



  Future<void> acceptRequest({

    required TeamModel team,

    required TeamJoinRequestModel request,

    required String resolverUid,

  }) async {

    if (!request.isPending) return;



    await _playerRepository.assignPlayerToTeam(

      playerId: request.playerId,

      teamId: team.id,

      addedByUserId: resolverUid,

      notifyPlayer: false,

    );



    final now = DateTime.now();

    await _requests(team.id).doc(request.userId).update({

      'status': TeamJoinRequestStatus.accepted.name,

      'updatedAt': now.toIso8601String(),

      'resolvedBy': resolverUid,

      'resolvedAt': now.toIso8601String(),

    });



    await _notificationRepository.createNotification(

      userId: request.userId,

      title: 'Join request accepted',

      body: 'You are now on ${team.name}',

      teamId: team.id,

      type: 'team_join_accepted',

    );

  }



  Future<void> rejectRequest({

    required TeamModel team,

    required TeamJoinRequestModel request,

    required String resolverUid,

  }) async {

    if (!request.isPending) return;



    final now = DateTime.now();

    await _requests(team.id).doc(request.userId).update({

      'status': TeamJoinRequestStatus.rejected.name,

      'updatedAt': now.toIso8601String(),

      'resolvedBy': resolverUid,

      'resolvedAt': now.toIso8601String(),

    });



    await _notificationRepository.createNotification(

      userId: request.userId,

      title: 'Join request declined',

      body: 'Your request to join ${team.name} was declined',

      teamId: team.id,

      type: 'team_join_rejected',

    );

  }

}


