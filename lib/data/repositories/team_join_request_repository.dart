import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/team_notification_types.dart';
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
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _playerRepository =
            playerRepository ?? PlayerRepository(firestore: firestore),
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

  Future<TeamJoinRequestModel?> getRequest(String teamId, String userId) async {
    final doc = await _requests(teamId).doc(userId).get();
    if (!doc.exists) return null;
    return TeamJoinRequestModel.fromMap(doc.id, teamId, doc.data()!);
  }

  Stream<List<TeamJoinRequestModel>> watchPendingForTeam(String teamId) {
    return _requests(teamId)
        .where('status', isEqualTo: TeamJoinRequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TeamJoinRequestModel.fromMap(d.id, teamId, d.data()))
              .where((r) => r.requestType == TeamJoinRequestType.joinRequest)
              .toList(),
        );
  }

  Future<Set<String>> getPendingInvitationPlayerIds(String teamId) async {
    final snap = await _requests(teamId)
        .where('status', isEqualTo: TeamJoinRequestStatus.pending.name)
        .get();
    return snap.docs
        .map((d) => TeamJoinRequestModel.fromMap(d.id, teamId, d.data()))
        .where((r) => r.requestType == TeamJoinRequestType.invitation)
        .map((r) => r.playerId)
        .toSet();
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
        if (current.isInvitation) {
          throw StateError('This player already has a pending invitation');
        }
        throw StateError('You already have a pending join request');
      }
    }
  }

  Future<void> _assertCanInvite({
    required TeamModel team,
    required PlayerModel player,
    required String invitedByUserId,
  }) async {
    final userId = player.userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Only registered players can be invited');
    }
    if (userId == invitedByUserId) {
      throw StateError('You cannot invite yourself');
    }
    if (team.playerIds.contains(userId) || player.isOnTeam(team.id)) {
      throw StateError('Player is already on this team');
    }

    final existing = await _requests(team.id).doc(userId).get();
    if (existing.exists) {
      final current = TeamJoinRequestModel.fromMap(
        existing.id,
        team.id,
        existing.data()!,
      );
      if (current.isPending) {
        if (current.isInvitation) {
          return;
        }
        throw StateError('Player already has a pending join request');
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
      requestType: TeamJoinRequestType.joinRequest,
      status: TeamJoinRequestStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    await ref.set(request.toMap());

    final message = '${request.displayName} requested to join ${team.name}.';
    await _notificationRepository.notifyTeamLeadership(
      team: team,
      title: 'Join Request',
      body: message,
      type: TeamNotificationTypes.joinRequest,
      playerId: userId,
      excludeUserId: userId,
      category: 'team',
    );

    return request;
  }

  Future<TeamJoinRequestModel> createInvitation({
    required TeamModel team,
    required PlayerModel player,
    required String invitedByUserId,
    String? inviterName,
  }) async {
    final userId = player.userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Only registered players can be invited');
    }

    await _assertCanInvite(
      team: team,
      player: player,
      invitedByUserId: invitedByUserId,
    );

    final ref = _requests(team.id).doc(userId);
    final existing = await ref.get();
    if (existing.exists) {
      final current = TeamJoinRequestModel.fromMap(
        existing.id,
        team.id,
        existing.data()!,
      );
      if (current.isPending && current.isInvitation) return current;
      await ref.delete();
    }

    final now = DateTime.now();
    final inviter = inviterName?.trim();
    final request = TeamJoinRequestModel(
      id: userId,
      teamId: team.id,
      teamName: team.name,
      userId: userId,
      playerId: player.id,
      playerName: player.name,
      playerFullName: player.fullName,
      playerPhotoUrl: player.photoUrl,
      cfPlayerId: player.playerId,
      requestType: TeamJoinRequestType.invitation,
      invitedByUserId: invitedByUserId,
      status: TeamJoinRequestStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    await ref.set(request.toMap());

    final body = inviter != null && inviter.isNotEmpty
        ? '$inviter invited you to Team ${team.name}.'
        : 'You have been invited to Team ${team.name}.';

    await _notificationRepository.createNotification(
      userId: userId,
      title: 'Team Invitation',
      body: body,
      teamId: team.id,
      playerId: player.id,
      type: TeamNotificationTypes.invitation,
      category: 'invitation',
      addedByUserId: invitedByUserId,
      requestId: userId,
    );

    return request;
  }

  Future<void> acceptRequest({
    required TeamModel team,
    required TeamJoinRequestModel request,
    required String resolverUid,
  }) async {
    if (!request.isPending || request.isInvitation) return;

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
      title: 'Request Accepted',
      body: 'You are now a member of Team ${team.name}.',
      teamId: team.id,
      type: TeamNotificationTypes.joinAccepted,
      category: 'team',
    );
  }

  Future<void> rejectRequest({
    required TeamModel team,
    required TeamJoinRequestModel request,
    required String resolverUid,
  }) async {
    if (!request.isPending || request.isInvitation) return;

    final now = DateTime.now();
    await _requests(team.id).doc(request.userId).update({
      'status': TeamJoinRequestStatus.rejected.name,
      'updatedAt': now.toIso8601String(),
      'resolvedBy': resolverUid,
      'resolvedAt': now.toIso8601String(),
    });

    await _notificationRepository.createNotification(
      userId: request.userId,
      title: 'Request Declined',
      body: 'Your request to join Team ${team.name} was declined.',
      teamId: team.id,
      type: TeamNotificationTypes.joinRejected,
      category: 'team',
    );
  }

  Future<void> acceptInvitation({
    required TeamModel team,
    required TeamJoinRequestModel request,
    required String playerUid,
  }) async {
    if (!request.isPending || !request.isInvitation) {
      throw StateError('Invitation is no longer pending');
    }
    if (request.userId != playerUid) {
      throw StateError('Not allowed to respond to this invitation');
    }

    await _playerRepository.assignPlayerToTeam(
      playerId: request.playerId,
      teamId: team.id,
      addedByUserId: request.invitedByUserId,
      notifyPlayer: false,
    );

    final now = DateTime.now();
    await _requests(team.id).doc(request.userId).update({
      'status': TeamJoinRequestStatus.accepted.name,
      'updatedAt': now.toIso8601String(),
      'resolvedBy': playerUid,
      'resolvedAt': now.toIso8601String(),
    });

    await _notificationRepository.notifyTeamLeadership(
      team: team,
      title: 'Invitation Accepted',
      body: '${request.displayName} joined Team ${team.name}.',
      type: TeamNotificationTypes.invitationAccepted,
      playerId: playerUid,
      excludeUserId: playerUid,
      category: 'team',
    );

    await _notificationRepository.createNotification(
      userId: playerUid,
      title: 'Welcome',
      body: 'You joined Team ${team.name}.',
      teamId: team.id,
      type: TeamNotificationTypes.joinAccepted,
      category: 'team',
    );
  }

  Future<void> rejectInvitation({
    required TeamModel team,
    required TeamJoinRequestModel request,
    required String playerUid,
  }) async {
    if (!request.isPending || !request.isInvitation) {
      throw StateError('Invitation is no longer pending');
    }
    if (request.userId != playerUid) {
      throw StateError('Not allowed to respond to this invitation');
    }

    final now = DateTime.now();
    await _requests(team.id).doc(request.userId).update({
      'status': TeamJoinRequestStatus.rejected.name,
      'updatedAt': now.toIso8601String(),
      'resolvedBy': playerUid,
      'resolvedAt': now.toIso8601String(),
    });

    await _notificationRepository.notifyTeamLeadership(
      team: team,
      title: 'Invitation Declined',
      body: '${request.displayName} declined to join Team ${team.name}.',
      type: TeamNotificationTypes.invitationRejected,
      playerId: playerUid,
      excludeUserId: playerUid,
      category: 'team',
    );
  }
}
