import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/tournament_notification_types.dart';
import '../../core/utils/team_leadership_utils.dart';
import '../models/team_model.dart';
import '../models/tournament/tournament_member_model.dart';
import '../models/tournament/tournament_team_request_model.dart';
import '../models/tournament_model.dart';
import 'notification_repository.dart';
import 'player_repository.dart';
import 'team_repository.dart';
import 'tournament_repository.dart';
import 'tournament_sub_repositories.dart';

class TournamentTeamRequestRepository {
  TournamentTeamRequestRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notificationRepository,
    TeamRepository? teamRepository,
    TournamentRepository? tournamentRepository,
    TournamentMemberRepository? memberRepository,
    PlayerRepository? playerRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notifications =
            notificationRepository ?? NotificationRepository(firestore: firestore),
        _teams = teamRepository ?? TeamRepository(),
        _tournaments = tournamentRepository ?? TournamentRepository(),
        _members = memberRepository ?? TournamentMemberRepository(),
        _players = playerRepository ?? PlayerRepository();

  final FirebaseFirestore _firestore;
  final NotificationRepository _notifications;
  final TeamRepository _teams;
  final TournamentRepository _tournaments;
  final TournamentMemberRepository _members;
  final PlayerRepository _players;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.tournamentTeamRequestsCollection);

  static String docId(String tournamentId, String teamId) =>
      '${tournamentId}_$teamId';

  Stream<List<TournamentTeamRequestModel>> watchForTournament(
    String tournamentId,
  ) {
    return _col
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TournamentTeamRequestModel.fromMap(d.id, d.data()))
              .toList()
            ..sort(
              (a, b) => (b.createdAt ?? DateTime(0))
                  .compareTo(a.createdAt ?? DateTime(0)),
            ),
        );
  }

  Stream<TournamentTeamRequestModel?> watchRequest({
    required String tournamentId,
    required String teamId,
  }) {
    return _col.doc(docId(tournamentId, teamId)).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TournamentTeamRequestModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<TournamentTeamRequestModel?> getRequest({
    required String tournamentId,
    required String teamId,
  }) async {
    final doc = await _col.doc(docId(tournamentId, teamId)).get();
    if (!doc.exists) return null;
    return TournamentTeamRequestModel.fromMap(doc.id, doc.data()!);
  }

  Future<TournamentTeamRequestModel> createInvitation({
    required TournamentModel tournament,
    required TeamModel team,
    required String organizerUserId,
  }) async {
    await _assertCanInvite(tournament: tournament, team: team);

    if (TeamLeadershipUtils.isTeamOwner(organizerUserId, team)) {
      return addTeamDirectlyAsOrganizer(
        tournament: tournament,
        team: team,
        organizerUserId: organizerUserId,
      );
    }

    final ref = _col.doc(docId(tournament.id, team.id));
    final existing = await ref.get();
    if (existing.exists) {
      final current =
          TournamentTeamRequestModel.fromMap(existing.id, existing.data()!);
      if (current.isPending) return current;
      if (current.status == TournamentTeamRequestStatus.approved) {
        throw StateError('${team.name} is already in this tournament');
      }
    }

    final now = DateTime.now();
    final request = TournamentTeamRequestModel(
      id: ref.id,
      tournamentId: tournament.id,
      teamId: team.id,
      requestType: TournamentTeamRequestType.invitation,
      status: TournamentTeamRequestStatus.pending,
      requestedByUserId: organizerUserId,
      tournamentName: tournament.name,
      teamName: team.name,
      createdAt: now,
      updatedAt: now,
    );

    await ref.set(request.toMap());

    await _notifications.notifyTeamLeadership(
      team: team,
      title: 'Tournament invitation',
      body:
          '${tournament.name} has invited your team to participate.',
      type: TournamentNotificationTypes.invitation,
      excludeUserId: organizerUserId,
      tournamentId: tournament.id,
      requestId: request.id,
    );

    return request;
  }

  /// Adds a team to the tournament immediately (no invitation / notification).
  Future<TournamentTeamRequestModel> addTeamDirectlyAsOrganizer({
    required TournamentModel tournament,
    required TeamModel team,
    required String organizerUserId,
  }) async {
    if (!await _canManageTournament(tournament, organizerUserId)) {
      throw StateError('Not allowed to add teams to this tournament');
    }
    if (tournament.teamIds.contains(team.id)) {
      throw StateError('${team.name} is already in this tournament');
    }

    await _tournaments.addTeamToTournament(
      tournamentId: tournament.id,
      teamId: team.id,
      teamName: team.name,
    );

    final now = DateTime.now();
    final request = TournamentTeamRequestModel(
      id: docId(tournament.id, team.id),
      tournamentId: tournament.id,
      teamId: team.id,
      requestType: TournamentTeamRequestType.invitation,
      status: TournamentTeamRequestStatus.approved,
      requestedByUserId: organizerUserId,
      approvedByUserId: organizerUserId,
      tournamentName: tournament.name,
      teamName: team.name,
      createdAt: now,
      updatedAt: now,
    );

    await _col.doc(request.id).set(request.toMap());
    return request;
  }

  Future<TournamentTeamRequestModel> createJoinRequest({
    required TournamentModel tournament,
    required TeamModel team,
    required String requesterUserId,
  }) async {
    if (tournament.teamIds.contains(team.id)) {
      throw StateError('Your team is already in this tournament');
    }

    if (!await _canManageTeamJoinRequests(requesterUserId, team)) {
      throw StateError('Only team leadership can request to join');
    }

    final ref = _col.doc(docId(tournament.id, team.id));
    final existing = await ref.get();
    if (existing.exists) {
      final current =
          TournamentTeamRequestModel.fromMap(existing.id, existing.data()!);
      if (current.isPending) return current;
      if (current.status == TournamentTeamRequestStatus.approved) {
        throw StateError('Your team is already in this tournament');
      }
    }

    final now = DateTime.now();
    final request = TournamentTeamRequestModel(
      id: ref.id,
      tournamentId: tournament.id,
      teamId: team.id,
      requestType: TournamentTeamRequestType.joinRequest,
      status: TournamentTeamRequestStatus.pending,
      requestedByUserId: requesterUserId,
      tournamentName: tournament.name,
      teamName: team.name,
      createdAt: now,
      updatedAt: now,
    );

    await ref.set(request.toMap());

    await _notifyTournamentManagers(
      tournament: tournament,
      title: 'New team join request',
      body: '${team.name} wants to join ${tournament.name}.',
      type: TournamentNotificationTypes.joinRequest,
      teamId: team.id,
      requestId: request.id,
      excludeUserId: requesterUserId,
    );

    return request;
  }

  Future<void> acceptInvitation({
    required TournamentTeamRequestModel request,
    required TeamModel team,
    required String resolverUserId,
  }) async {
    if (request.requestType != TournamentTeamRequestType.invitation) {
      throw StateError('Not an invitation');
    }
    if (!request.isPending) return;
    if (!await _canManageTeamJoinRequests(resolverUserId, team)) {
      throw StateError('Not allowed to respond to this invitation');
    }

    await _approveAndAddTeam(
      request: request,
      resolverUserId: resolverUserId,
    );

    final tournament =
        await _tournaments.getTournament(request.tournamentId);
    if (tournament == null) return;

    await _notifyTournamentManagers(
      tournament: tournament,
      title: 'Invitation accepted',
      body: '${team.name} accepted the invitation to ${tournament.name}.',
      type: TournamentNotificationTypes.invitationAccepted,
      teamId: team.id,
      requestId: request.id,
    );
  }

  Future<void> rejectInvitation({
    required TournamentTeamRequestModel request,
    required TeamModel team,
    required String resolverUserId,
  }) async {
    if (request.requestType != TournamentTeamRequestType.invitation) {
      throw StateError('Not an invitation');
    }
    if (!request.isPending) return;
    if (!await _canManageTeamJoinRequests(resolverUserId, team)) {
      throw StateError('Not allowed to respond to this invitation');
    }

    await _rejectRequest(request: request, resolverUserId: resolverUserId);

    final tournament =
        await _tournaments.getTournament(request.tournamentId);
    if (tournament == null) return;

    await _notifyTournamentManagers(
      tournament: tournament,
      title: 'Invitation declined',
      body: '${team.name} declined the invitation to ${tournament.name}.',
      type: TournamentNotificationTypes.invitationRejected,
      teamId: team.id,
      requestId: request.id,
    );
  }

  Future<void> approveJoinRequest({
    required TournamentTeamRequestModel request,
    required TournamentModel tournament,
    required String resolverUserId,
  }) async {
    if (request.requestType != TournamentTeamRequestType.joinRequest) {
      throw StateError('Not a join request');
    }
    if (!request.isPending) return;
    if (!await _canManageTournament(tournament, resolverUserId)) {
      throw StateError('Not allowed to approve this request');
    }

    final team = await _teams.getTeam(request.teamId);
    if (team == null) throw StateError('Team not found');

    await _approveAndAddTeam(
      request: request,
      resolverUserId: resolverUserId,
    );

    await _notifications.notifyTeamLeadership(
      team: team,
      title: 'Tournament join approved',
      body:
          'Your team has been accepted into ${tournament.name}.',
      type: TournamentNotificationTypes.joinApproved,
      tournamentId: tournament.id,
      requestId: request.id,
    );
  }

  Future<void> rejectJoinRequest({
    required TournamentTeamRequestModel request,
    required TournamentModel tournament,
    required String resolverUserId,
  }) async {
    if (request.requestType != TournamentTeamRequestType.joinRequest) {
      throw StateError('Not a join request');
    }
    if (!request.isPending) return;
    if (!await _canManageTournament(tournament, resolverUserId)) {
      throw StateError('Not allowed to reject this request');
    }

    await _rejectRequest(request: request, resolverUserId: resolverUserId);

    final team = await _teams.getTeam(request.teamId);
    if (team == null) return;

    await _notifications.notifyTeamLeadership(
      team: team,
      title: 'Tournament join declined',
      body: 'Your team join request was declined for ${tournament.name}.',
      type: TournamentNotificationTypes.joinRejected,
      tournamentId: tournament.id,
      requestId: request.id,
    );
  }

  Future<void> withdrawJoinRequest({
    required TournamentTeamRequestModel request,
    required TeamModel team,
    required String userId,
  }) async {
    if (request.requestType != TournamentTeamRequestType.joinRequest) {
      throw StateError('Not a join request');
    }
    if (!request.isPending) return;
    if (!await _canManageTeamJoinRequests(userId, team)) {
      throw StateError('Not allowed to withdraw this request');
    }

    final now = DateTime.now();
    await _col.doc(request.id).update({
      'status': TournamentTeamRequestStatus.withdrawn.name,
      'updatedAt': now.toIso8601String(),
    });
  }

  Future<TournamentTeamRequestModel> resendInvitation({
    required TournamentModel tournament,
    required TeamModel team,
    required String organizerUserId,
  }) async {
    final ref = _col.doc(docId(tournament.id, team.id));
    await ref.delete();
    return createInvitation(
      tournament: tournament,
      team: team,
      organizerUserId: organizerUserId,
    );
  }

  Future<void> removeApprovedTeam({
    required TournamentModel tournament,
    required String teamId,
    required String resolverUserId,
  }) async {
    if (!await _canManageTournament(tournament, resolverUserId)) {
      throw StateError('Not allowed to remove teams');
    }

    await _tournaments.removeTeamFromTournament(
      tournamentId: tournament.id,
      teamId: teamId,
    );

    final ref = _col.doc(docId(tournament.id, teamId));
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update({
        'status': TournamentTeamRequestStatus.withdrawn.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _approveAndAddTeam({
    required TournamentTeamRequestModel request,
    required String resolverUserId,
  }) async {
    final team = await _teams.getTeam(request.teamId);
    if (team == null) throw StateError('Team not found');

    await _tournaments.addTeamToTournament(
      tournamentId: request.tournamentId,
      teamId: request.teamId,
      teamName: team.name,
    );

    final now = DateTime.now();
    await _col.doc(request.id).update({
      'status': TournamentTeamRequestStatus.approved.name,
      'approvedByUserId': resolverUserId,
      'updatedAt': now.toIso8601String(),
    });
  }

  Future<void> _rejectRequest({
    required TournamentTeamRequestModel request,
    required String resolverUserId,
  }) async {
    final now = DateTime.now();
    await _col.doc(request.id).update({
      'status': TournamentTeamRequestStatus.rejected.name,
      'rejectedByUserId': resolverUserId,
      'updatedAt': now.toIso8601String(),
    });
  }

  Future<void> _assertCanInvite({
    required TournamentModel tournament,
    required TeamModel team,
  }) async {
    if (tournament.teamIds.contains(team.id)) {
      throw StateError('${team.name} is already in this tournament');
    }

    final ref = _col.doc(docId(tournament.id, team.id));
    final existing = await ref.get();
    if (!existing.exists) return;

    final current =
        TournamentTeamRequestModel.fromMap(existing.id, existing.data()!);
    if (current.isPending) {
      throw StateError('An invitation or request is already pending');
    }
  }

  Future<bool> _canManageTournament(
    TournamentModel tournament,
    String userId,
  ) async {
    if (tournament.effectiveOrganizerId == userId) return true;
    final member = await _members.getMemberForUser(
      tournamentId: tournament.id,
      userId: userId,
    );
    return member?.role == TournamentRole.admin ||
        member?.role == TournamentRole.owner;
  }

  Future<bool> _canManageTeamJoinRequests(String userId, TeamModel team) async {
    final player = await _players.getPlayerByUserId(userId);
    return TeamLeadershipUtils.canManageJoinRequests(
      userId,
      team,
      player: player,
    );
  }

  Future<void> _notifyTournamentManagers({
    required TournamentModel tournament,
    required String title,
    required String body,
    required String type,
    String? teamId,
    String? requestId,
    String? excludeUserId,
  }) async {
    final recipients = <String>{tournament.effectiveOrganizerId};

    final members = await _members
        .watchMembers(tournament.id)
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => <TournamentMemberModel>[]);

    for (final member in members) {
      if (member.role == TournamentRole.admin ||
          member.role == TournamentRole.owner) {
        recipients.add(member.userId);
      }
    }

    for (final uid in recipients) {
      if (uid.isEmpty) continue;
      if (excludeUserId != null && uid == excludeUserId) continue;
      await _notifications.createNotification(
        userId: uid,
        title: title,
        body: body,
        type: type,
        teamId: teamId,
        tournamentId: tournament.id,
        requestId: requestId,
      );
    }
  }
}
