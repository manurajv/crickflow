import '../../../core/constants/enums.dart';
import '../../../core/constants/tournament_notification_types.dart';
import '../../../data/models/tournament/tournament_official_model.dart';
import '../../../data/models/tournament_model.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../data/repositories/tournament_sub_repositories.dart';

/// Invites tournament officials and handles accept/decline responses.
class TournamentOfficialInviteService {
  TournamentOfficialInviteService({
    TournamentOfficialRepository? officialRepository,
    NotificationRepository? notificationRepository,
  })  : _officials = officialRepository ?? TournamentOfficialRepository(),
        _notifications = notificationRepository ?? NotificationRepository();

  final TournamentOfficialRepository _officials;
  final NotificationRepository _notifications;

  Future<TournamentOfficialModel> inviteOfficial({
    required TournamentModel tournament,
    required String organizerId,
    required String organizerName,
    required String targetUserId,
    required TournamentOfficialRole role,
    required String displayName,
    String playerId = '',
    String? photoUrl,
  }) async {
    if (targetUserId.isEmpty) {
      throw StateError('Select a registered player with a linked account');
    }

    final existing = await _officials.getOfficials(tournament.id);
    final duplicate = existing.where(
      (o) =>
          o.userId == targetUserId &&
          o.role == role &&
          o.status != TournamentOfficialStatus.declined,
    );
    if (duplicate.isNotEmpty) {
      throw StateError('This person is already listed for this role');
    }

    final isSelf = targetUserId == organizerId;
    final roleLabel = _roleLabel(role);
    final official = TournamentOfficialModel(
      id: '',
      tournamentId: tournament.id,
      userId: targetUserId,
      role: role,
      displayName: displayName,
      playerId: playerId,
      photoUrl: photoUrl,
      status: isSelf
          ? TournamentOfficialStatus.active
          : TournamentOfficialStatus.pending,
      invitedByUserId: organizerId,
    );

    final id = await _officials.addOfficial(official);
    final saved = TournamentOfficialModel(
      id: id,
      tournamentId: tournament.id,
      userId: targetUserId,
      role: role,
      displayName: displayName,
      playerId: playerId,
      photoUrl: photoUrl,
      status: official.status,
      invitedByUserId: organizerId,
    );

    if (!isSelf) {
      await _notifications.createNotification(
        userId: targetUserId,
        title: '${tournament.name} — official invite',
        body:
            '$organizerName invited you to be $roleLabel for ${tournament.name}.',
        type: TournamentNotificationTypes.officialInvitation,
        tournamentId: tournament.id,
        requestId: id,
        addedByUserId: organizerId,
        playerId: playerId.isNotEmpty ? playerId : null,
      );
    }

    return saved;
  }

  Future<void> acceptInvitation({
    required TournamentOfficialModel official,
    required TournamentModel tournament,
    required String resolverUserId,
  }) async {
    if (official.userId != resolverUserId) {
      throw StateError('Only the invited official can accept');
    }
    if (!official.isPending) {
      throw StateError('Invitation is no longer pending');
    }

    await _officials.updateStatus(
      official.id,
      TournamentOfficialStatus.active,
    );

    final organizerId = official.invitedByUserId.isNotEmpty
        ? official.invitedByUserId
        : tournament.effectiveOrganizerId;
    if (organizerId.isNotEmpty) {
      await _notifications.createNotification(
        userId: organizerId,
        title: 'Official invite accepted',
        body:
            '${official.displayName} accepted the ${_roleLabel(official.role)} role for ${tournament.name}.',
        type: TournamentNotificationTypes.officialInvitationAccepted,
        tournamentId: tournament.id,
        requestId: official.id,
      );
    }
  }

  Future<void> declineInvitation({
    required TournamentOfficialModel official,
    required TournamentModel tournament,
    required String resolverUserId,
  }) async {
    if (official.userId != resolverUserId) {
      throw StateError('Only the invited official can decline');
    }
    if (!official.isPending) {
      throw StateError('Invitation is no longer pending');
    }

    await _officials.updateStatus(
      official.id,
      TournamentOfficialStatus.declined,
    );

    final organizerId = official.invitedByUserId.isNotEmpty
        ? official.invitedByUserId
        : tournament.effectiveOrganizerId;
    if (organizerId.isNotEmpty) {
      await _notifications.createNotification(
        userId: organizerId,
        title: 'Official invite declined',
        body:
            '${official.displayName} declined the ${_roleLabel(official.role)} role for ${tournament.name}.',
        type: TournamentNotificationTypes.officialInvitationRejected,
        tournamentId: tournament.id,
        requestId: official.id,
      );
    }
  }

  Future<TournamentOfficialModel?> findById(String officialId) =>
      _officials.getOfficial(officialId);

  String _roleLabel(TournamentOfficialRole role) => switch (role) {
        TournamentOfficialRole.scorer => 'scorer',
        TournamentOfficialRole.umpire => 'umpire',
        TournamentOfficialRole.commentator => 'commentator',
        TournamentOfficialRole.streamer => 'live streamer',
        TournamentOfficialRole.photographer => 'photographer',
        TournamentOfficialRole.videographer => 'videographer',
      };
}
