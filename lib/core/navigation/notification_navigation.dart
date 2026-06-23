import 'dart:convert';

import '../../core/constants/tournament_notification_types.dart';
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
        (type == 'team_join_request' ||
            type == 'team_join_accepted' ||
            type == 'team_join_rejected' ||
            type == 'team_member_removed' ||
            type == 'team_member_added' ||
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
        'team_join_request' => 'Join request',
        'team_join_accepted' => 'Accepted',
        'team_join_rejected' => 'Declined',
        TournamentNotificationTypes.invitation => 'Tournament invite',
        TournamentNotificationTypes.invitationAccepted => 'Invite accepted',
        TournamentNotificationTypes.invitationRejected => 'Invite declined',
        TournamentNotificationTypes.joinRequest => 'Tournament request',
        TournamentNotificationTypes.joinApproved => 'Join approved',
        TournamentNotificationTypes.joinRejected => 'Join declined',
        'team_member_removed' => 'Team update',
        'team_member_added' => 'Added to team',
        'player_follow' => 'New follower',
        'follower_milestone' => 'Milestone',
        'admin_roster_report' => 'Admin alert',
        _ => 'Update',
      };

  bool get isJoinRequest => type == 'team_join_request';

  bool get isTournamentActionable =>
      type == TournamentNotificationTypes.invitation ||
      type == TournamentNotificationTypes.joinRequest;

  bool get canReportUnauthorizedAdd => type == 'team_member_added';

  String? get actionLabel => switch (type) {
        'team_join_request' => 'Review request',
        'team_join_accepted' || 'team_join_rejected' => 'View team',
        'team_member_added' => 'View team',
        TournamentNotificationTypes.invitation => 'Respond to invite',
        TournamentNotificationTypes.joinRequest => 'Review request',
        TournamentNotificationTypes.joinApproved ||
        TournamentNotificationTypes.joinRejected ||
        TournamentNotificationTypes.invitationAccepted ||
        TournamentNotificationTypes.invitationRejected =>
          'View tournament',
        _ => null,
      };
}
