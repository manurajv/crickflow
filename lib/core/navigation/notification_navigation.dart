import 'dart:convert';

import '../../data/models/notification_model.dart';

/// Maps notification payloads to in-app routes.
class NotificationNavigation {
  NotificationNavigation._();

  static String? routeFor({
    String? type,
    String? teamId,
    String? matchId,
  }) {
    if (teamId != null &&
        teamId.isNotEmpty &&
        (type == 'team_join_request' ||
            type == 'team_join_accepted' ||
            type == 'team_join_rejected' ||
            type == 'team_member_removed' ||
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
    return routeFor(
      type: notification.type,
      teamId: notification.teamId,
      matchId: notification.matchId,
    );
  }

  static Map<String, String> dataFromRemote(Map<String, dynamic> raw) {
    return {
      if (raw['type'] != null) 'type': raw['type'].toString(),
      if (raw['teamId'] != null) 'teamId': raw['teamId'].toString(),
      if (raw['matchId'] != null) 'matchId': raw['matchId'].toString(),
      if (raw['playerId'] != null) 'playerId': raw['playerId'].toString(),
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
        'team_member_removed' => 'Team update',
        _ => 'Update',
      };

  bool get isJoinRequest => type == 'team_join_request';

  String? get actionLabel => switch (type) {
        'team_join_request' => 'Review request',
        'team_join_accepted' || 'team_join_rejected' => 'View team',
        _ => null,
      };
}
