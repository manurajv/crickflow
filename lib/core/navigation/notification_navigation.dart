import 'dart:convert';

import '../../core/constants/tournament_notification_types.dart';
import '../../core/constants/team_notification_types.dart';
import '../../data/models/notification_model.dart';

/// Maps notification payloads to in-app routes.
class NotificationNavigation {
  NotificationNavigation._();

  static String? routeFor({
    String? type,
    String? teamId,
    String? matchId,
    String? tournamentId,
  }) {
    if (tournamentId != null &&
        tournamentId.isNotEmpty &&
        (type == TournamentNotificationTypes.joinRequest ||
            type == TournamentNotificationTypes.invitation ||
            type == TournamentNotificationTypes.joinApproved ||
            type == TournamentNotificationTypes.joinRejected ||
            type == TournamentNotificationTypes.invitationAccepted ||
            type == TournamentNotificationTypes.invitationRejected)) {
      return '/tournaments/$tournamentId/teams';
    }
    if (teamId != null &&
        teamId.isNotEmpty &&
        (type == TeamNotificationTypes.joinRequest ||
            type == TeamNotificationTypes.joinAccepted ||
            type == TeamNotificationTypes.joinRejected ||
            type == TeamNotificationTypes.memberRemoved ||
            type == TeamNotificationTypes.memberAdded ||
            type == TeamNotificationTypes.invitationAccepted ||
            type == TeamNotificationTypes.invitationRejected ||
            type == null)) {
      return '/teams/$teamId';
    }
    if (matchId != null && matchId.isNotEmpty) {
      return '/match/$matchId';
    }
    if (teamId != null && teamId.isNotEmpty) {
      return '/teams/$teamId';
    }
    return null;
  }

  static String? routeForNotification(NotificationModel notification) {
    if (notification.type == 'player_follow' ||
        notification.type == 'follower_milestone') {
      final playerId = notification.playerId;
      if (playerId != null && playerId.isNotEmpty) {
        return '/player/$playerId';
      }
    }
    // Tournament invitations are handled with Accept/Reject on the notifications
    // screen — do not route team leadership to the organiser dashboard.
    if (notification.type == TournamentNotificationTypes.invitation ||
        notification.type == TeamNotificationTypes.invitation) {
      return null;
    }
    return routeFor(
      type: notification.type,
      teamId: notification.teamId,
      matchId: notification.matchId,
      tournamentId: notification.tournamentId,
    );
  }

  static Map<String, String> dataFromRemote(Map<String, dynamic> raw) {
    return {
      if (raw['type'] != null) 'type': raw['type'].toString(),
      if (raw['teamId'] != null) 'teamId': raw['teamId'].toString(),
      if (raw['matchId'] != null) 'matchId': raw['matchId'].toString(),
      if (raw['playerId'] != null) 'playerId': raw['playerId'].toString(),
      if (raw['tournamentId'] != null)
        'tournamentId': raw['tournamentId'].toString(),
      if (raw['requestId'] != null) 'requestId': raw['requestId'].toString(),
    };
  }

  static String encodePayload(Map<String, String> data) => jsonEncode(data);

  static Map<String, String> decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
    } catch (_) {
      // Legacy payloads stored only teamId.
      return {'teamId': raw, 'type': 'team_join_request'};
    }
    return {};
  }
}

extension NotificationPresentation on NotificationModel {
  String get typeLabel => switch (type) {
        TeamNotificationTypes.joinRequest => 'Join request',
        TeamNotificationTypes.joinAccepted => 'Accepted',
        TeamNotificationTypes.joinRejected => 'Declined',
        TeamNotificationTypes.invitation => 'Team invite',
        TeamNotificationTypes.invitationAccepted => 'Invite accepted',
        TeamNotificationTypes.invitationRejected => 'Invite declined',
        TournamentNotificationTypes.invitation => 'Tournament invite',
        TournamentNotificationTypes.invitationAccepted => 'Invite accepted',
        TournamentNotificationTypes.invitationRejected => 'Invite declined',
        TournamentNotificationTypes.joinRequest => 'Tournament request',
        TournamentNotificationTypes.joinApproved => 'Join approved',
        TournamentNotificationTypes.joinRejected => 'Join declined',
        TeamNotificationTypes.memberRemoved => 'Team update',
        TeamNotificationTypes.memberAdded => 'Added to team',
        'player_follow' => 'New follower',
        'follower_milestone' => 'Milestone',
        'admin_roster_report' => 'Admin alert',
        _ => 'Update',
      };

  bool get isJoinRequest => type == TeamNotificationTypes.joinRequest;

  bool get isTeamActionable => type == TeamNotificationTypes.invitation;

  bool get isTournamentActionable =>
      type == TournamentNotificationTypes.invitation ||
      type == TournamentNotificationTypes.joinRequest ||
      type == TournamentNotificationTypes.officialInvitation;

  bool get isActionable => isTournamentActionable || isTeamActionable;

  bool get canReportUnauthorizedAdd => type == TeamNotificationTypes.memberAdded;

  String? get actionLabel => switch (type) {
        TeamNotificationTypes.joinRequest => 'Review request',
        TeamNotificationTypes.joinAccepted ||
        TeamNotificationTypes.joinRejected =>
          'View team',
        TeamNotificationTypes.invitation => 'Respond to invite',
        TeamNotificationTypes.memberAdded => 'View team',
        TournamentNotificationTypes.invitation => 'Respond to invite',
        TournamentNotificationTypes.joinRequest => 'Review request',
        TournamentNotificationTypes.officialInvitation => 'Respond to invite',
        TournamentNotificationTypes.joinApproved ||
        TournamentNotificationTypes.joinRejected ||
        TournamentNotificationTypes.invitationAccepted ||
        TournamentNotificationTypes.invitationRejected =>
          'View tournament',
        TournamentNotificationTypes.officialInvitationAccepted ||
        TournamentNotificationTypes.officialInvitationRejected =>
          'View tournament',
        _ => null,
      };
}
