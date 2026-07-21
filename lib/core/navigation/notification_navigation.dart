import 'dart:convert';

import 'package:flutter/material.dart';

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
    String? playerId,
    String? tab,
    String? requestId,
  }) {
    if (type == 'badge_unlock' && playerId != null && playerId.isNotEmpty) {
      return '/player/$playerId/cricket';
    }
    if (type == 'player_follow' || type == 'follower_milestone') {
      if (playerId != null && playerId.isNotEmpty) {
        return '/player/$playerId';
      }
    }
    if (type == 'community_like' ||
        type == 'community_comment' ||
        type == 'community_mention') {
      if (requestId != null && requestId.isNotEmpty) {
        return '/community?postId=$requestId';
      }
      return '/community';
    }
    if (tournamentId != null &&
        tournamentId.isNotEmpty &&
        (type == TournamentNotificationTypes.joinRequest ||
            type == TournamentNotificationTypes.invitation ||
            type == TournamentNotificationTypes.joinApproved ||
            type == TournamentNotificationTypes.joinRejected ||
            type == TournamentNotificationTypes.invitationAccepted ||
            type == TournamentNotificationTypes.invitationRejected ||
            type == TournamentNotificationTypes.officialInvitation ||
            type == TournamentNotificationTypes.officialInvitationAccepted ||
            type == TournamentNotificationTypes.officialInvitationRejected ||
            type == 'tournament_completed')) {
      if (type == 'tournament_completed') {
        return '/tournaments/$tournamentId';
      }
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
      final resolvedTab = tab ?? _defaultMatchTab(type);
      if (resolvedTab != null && resolvedTab.isNotEmpty) {
        return '/match/$matchId?tab=$resolvedTab';
      }
      return '/match/$matchId';
    }
    if (teamId != null && teamId.isNotEmpty) {
      return '/teams/$teamId';
    }
    if (tournamentId != null && tournamentId.isNotEmpty) {
      return '/tournaments/$tournamentId';
    }
    return null;
  }

  static String? _defaultMatchTab(String? type) => switch (type) {
        'wicket' ||
        'hat_trick' ||
        'team_milestone' ||
        'player_milestone' ||
        'bowling_milestone' ||
        'match_started' ||
        'first_innings_complete' ||
        'second_innings_started' ||
        'match_break_started' ||
        'match_break_ended' ||
        'stream_started' =>
          'live',
        'match_result' ||
        'match_drawn' ||
        'match_abandoned' ||
        'hero_of_match' ||
        'stream_ended' =>
          'summary',
        _ => null,
      };

  static String? routeForNotification(NotificationModel notification) {
    if (notification.type == TournamentNotificationTypes.invitation ||
        notification.type == TeamNotificationTypes.invitation ||
        notification.type == TournamentNotificationTypes.officialInvitation) {
      // Stay on notifications when actions are still pending.
      if (!notification.hasActionStatus) return null;
    }
    return routeFor(
      type: notification.type,
      teamId: notification.teamId,
      matchId: notification.matchId,
      tournamentId: notification.tournamentId,
      playerId: notification.playerId,
      tab: notification.tab,
      requestId: notification.requestId,
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
      if (raw['category'] != null) 'category': raw['category'].toString(),
      if (raw['tab'] != null) 'tab': raw['tab'].toString(),
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
      return {'teamId': raw, 'type': 'team_join_request'};
    }
    return {};
  }
}

extension NotificationPresentation on NotificationModel {
  String get categoryKey {
    if (category != null && category!.isNotEmpty) return category!;
    return switch (type) {
      TeamNotificationTypes.joinRequest ||
      TeamNotificationTypes.joinAccepted ||
      TeamNotificationTypes.joinRejected ||
      TeamNotificationTypes.invitation ||
      TeamNotificationTypes.invitationAccepted ||
      TeamNotificationTypes.invitationRejected ||
      TeamNotificationTypes.memberAdded ||
      TeamNotificationTypes.memberRemoved =>
        'team',
      TournamentNotificationTypes.invitation ||
      TournamentNotificationTypes.invitationAccepted ||
      TournamentNotificationTypes.invitationRejected ||
      TournamentNotificationTypes.joinRequest ||
      TournamentNotificationTypes.joinApproved ||
      TournamentNotificationTypes.joinRejected ||
      TournamentNotificationTypes.officialInvitation ||
      TournamentNotificationTypes.officialInvitationAccepted ||
      TournamentNotificationTypes.officialInvitationRejected ||
      'tournament_completed' =>
        'tournament',
      'player_follow' || 'follower_milestone' => 'social',
      'community_like' || 'community_comment' || 'community_mention' =>
        'community',
      'badge_unlock' => 'badge',
      'hero_of_match' => 'achievement',
      'wicket' ||
      'hat_trick' ||
      'team_milestone' ||
      'player_milestone' ||
      'bowling_milestone' =>
        'live_match',
      'stream_started' || 'stream_ended' => 'streaming',
      'match_started' ||
      'first_innings_complete' ||
      'second_innings_started' ||
      'match_result' ||
      'match_drawn' ||
      'match_abandoned' ||
      'match_break_started' ||
      'match_break_ended' ||
      'dls_applied' ||
      'target_revised' ||
      'penalty_runs' =>
        'match',
      'admin_roster_report' => 'system',
      _ => matchId != null ? 'match' : 'system',
    };
  }

  IconData get categoryIcon => switch (categoryKey) {
        'match' => Icons.sports_cricket,
        'live_match' => Icons.flash_on_rounded,
        'tournament' => Icons.emoji_events_outlined,
        'team' => Icons.groups_outlined,
        'friend' || 'social' => Icons.person_add_alt_1_outlined,
        'community' => Icons.forum_outlined,
        'achievement' => Icons.star_outline_rounded,
        'badge' => Icons.military_tech_outlined,
        'streaming' => Icons.videocam_outlined,
        'invitation' => Icons.mail_outline,
        'system' => Icons.info_outline,
        _ => Icons.notifications_outlined,
      };

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
        TournamentNotificationTypes.officialInvitation => 'Official invite',
        TeamNotificationTypes.memberRemoved => 'Team update',
        TeamNotificationTypes.memberAdded => 'Added to team',
        'player_follow' => 'New follower',
        'follower_milestone' => 'Milestone',
        'community_like' => 'Post liked',
        'community_comment' => 'New comment',
        'community_mention' => 'Mention',
        'admin_roster_report' => 'Admin alert',
        'match_started' => 'Match started',
        'first_innings_complete' => 'Innings break',
        'second_innings_started' => 'Second innings',
        'wicket' => 'Wicket',
        'hat_trick' => 'Hat-trick',
        'team_milestone' => 'Team milestone',
        'player_milestone' => 'Milestone',
        'bowling_milestone' => 'Bowling',
        'match_result' || 'match_drawn' || 'match_abandoned' => 'Result',
        'hero_of_match' => 'Hero',
        'badge_unlock' => 'Badge',
        'stream_started' || 'stream_ended' => 'Stream',
        'tournament_completed' => 'Tournament',
        _ => categoryKey.replaceAll('_', ' '),
      };

  String? get actionStatusLabel => switch (actionStatus) {
        'accepted' => 'Accepted',
        'rejected' || 'declined' => 'Rejected',
        'joined' => 'Joined',
        'expired' => 'Expired',
        'cancelled' => 'Cancelled',
        _ => actionStatus,
      };

  bool get isJoinRequest => type == TeamNotificationTypes.joinRequest;

  bool get isTeamActionable =>
      type == TeamNotificationTypes.invitation && !hasActionStatus;

  bool get isTournamentActionable =>
      (type == TournamentNotificationTypes.invitation ||
          type == TournamentNotificationTypes.joinRequest ||
          type == TournamentNotificationTypes.officialInvitation) &&
      !hasActionStatus;

  bool get isActionable => isTournamentActionable || isTeamActionable;

  bool get canReportUnauthorizedAdd =>
      type == TeamNotificationTypes.memberAdded;

  /// Display header — match title when available.
  String? get displayMatchHeader {
    if (matchTitle != null && matchTitle!.trim().isNotEmpty) {
      return matchTitle!.trim();
    }
    return null;
  }

  String? get actionLabel => switch (type) {
        TeamNotificationTypes.joinRequest => 'Review request',
        TeamNotificationTypes.joinAccepted ||
        TeamNotificationTypes.joinRejected =>
          'View team',
        TeamNotificationTypes.invitation =>
          hasActionStatus ? 'View team' : 'Respond to invite',
        TeamNotificationTypes.memberAdded => 'View team',
        TournamentNotificationTypes.invitation =>
          hasActionStatus ? 'View tournament' : 'Respond to invite',
        TournamentNotificationTypes.joinRequest => 'Review request',
        TournamentNotificationTypes.officialInvitation =>
          hasActionStatus ? 'View tournament' : 'Respond to invite',
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
