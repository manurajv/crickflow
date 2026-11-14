import '../../core/constants/series_notification_types.dart';
import '../../core/constants/team_notification_types.dart';
import '../../core/constants/tournament_notification_types.dart';
import '../../data/models/notification_model.dart';

/// Notifications screen tabs.
enum NotificationTab { priority, general }

/// Which notifications go to the Priority tab.
///
/// Priority = requests that need someone to approve / reject / respond
/// (team join + invites, tournament join + invites, org approvals, org team
/// joins, roster reports) and the decisions on those requests.
/// Everything else (match updates, results, achievements, social) is General.
///
/// Mirrors `functions/src/notifications/notificationPriority.js`, which stamps
/// `priority` on every new notification. Old docs without the flag fall back
/// to this type mapping.
class NotificationPriority {
  NotificationPriority._();

  static const Set<String> actionTypes = {
    TeamNotificationTypes.joinRequest,
    TeamNotificationTypes.invitation,
    TournamentNotificationTypes.invitation,
    TournamentNotificationTypes.joinRequest,
    TournamentNotificationTypes.officialInvitation,
    SeriesNotificationTypes.approvalPending,
    SeriesNotificationTypes.clubJoinRequest,
    'admin_roster_report',
  };

  static const Set<String> decisionTypes = {
    TeamNotificationTypes.joinAccepted,
    TeamNotificationTypes.joinRejected,
    TeamNotificationTypes.invitationAccepted,
    TeamNotificationTypes.invitationRejected,
    TournamentNotificationTypes.invitationAccepted,
    TournamentNotificationTypes.invitationRejected,
    TournamentNotificationTypes.joinApproved,
    TournamentNotificationTypes.joinRejected,
    TournamentNotificationTypes.officialInvitationAccepted,
    TournamentNotificationTypes.officialInvitationRejected,
    SeriesNotificationTypes.approvalApproved,
    SeriesNotificationTypes.approvalRejected,
  };

  static bool isPriorityType(String? type) =>
      type != null &&
      (actionTypes.contains(type) || decisionTypes.contains(type));

  /// Server flag first; type mapping for older notifications.
  static bool isPriority(NotificationModel n) =>
      n.priority ?? isPriorityType(n.type);

  static NotificationTab tabOf(NotificationModel n) =>
      isPriority(n) ? NotificationTab.priority : NotificationTab.general;

  static List<NotificationModel> filter(
    Iterable<NotificationModel> items,
    NotificationTab tab,
  ) =>
      items.where((n) => tabOf(n) == tab).toList();

  static Map<NotificationTab, int> unreadCounts(
    Iterable<NotificationModel> items,
  ) {
    final out = {NotificationTab.priority: 0, NotificationTab.general: 0};
    for (final n in items) {
      if (n.read) continue;
      final tab = tabOf(n);
      out[tab] = out[tab]! + 1;
    }
    return out;
  }
}

/// What a set of notifications is about, so acting on one marks every
/// duplicate (same request / same match) read for the user.
class NotificationRelation {
  const NotificationRelation._(this.kind, {this.teamId, this.id});

  /// Join request from [requesterId] to team [teamId].
  const NotificationRelation.teamJoinRequest({
    required String teamId,
    required String requesterId,
  }) : this._(NotificationRelationKind.teamJoin, teamId: teamId, id: requesterId);

  /// Invitation to team [teamId] (one pending invite per user per team).
  const NotificationRelation.teamInvitation({required String teamId})
      : this._(NotificationRelationKind.teamInvite, teamId: teamId);

  /// Tournament team request / invitation / official invitation.
  const NotificationRelation.tournamentRequest({required String requestId})
      : this._(NotificationRelationKind.tournament, id: requestId);

  /// Org (series) approval request.
  const NotificationRelation.seriesApproval({required String approvalId})
      : this._(NotificationRelationKind.series, id: approvalId);

  /// Anything about match [matchId] (updates, results, …).
  const NotificationRelation.match({required String matchId})
      : this._(NotificationRelationKind.match, id: matchId);

  final NotificationRelationKind kind;
  final String? teamId;
  final String? id;

  static bool _has(String? s) => s != null && s.isNotEmpty;

  /// Relation for a tapped / acted-on notification, if it has one.
  static NotificationRelation? of(NotificationModel n) =>
      fromFields(
        type: n.type,
        teamId: n.teamId,
        playerId: n.playerId,
        requestId: n.requestId,
        matchId: n.matchId,
      );

  /// Same as [of] for raw push payload data.
  static NotificationRelation? fromFields({
    String? type,
    String? teamId,
    String? playerId,
    String? requestId,
    String? matchId,
  }) {
    if (type == TeamNotificationTypes.joinRequest && _has(teamId)) {
      final who = _has(requestId) ? requestId! : playerId;
      if (_has(who)) {
        return NotificationRelation.teamJoinRequest(
          teamId: teamId!,
          requesterId: who!,
        );
      }
    }
    if (type == TeamNotificationTypes.invitation && _has(teamId)) {
      return NotificationRelation.teamInvitation(teamId: teamId!);
    }
    if (_tournamentRequestTypes.contains(type) && _has(requestId)) {
      return NotificationRelation.tournamentRequest(requestId: requestId!);
    }
    if (type == SeriesNotificationTypes.approvalPending && _has(requestId)) {
      return NotificationRelation.seriesApproval(approvalId: requestId!);
    }
    if (_has(matchId)) return NotificationRelation.match(matchId: matchId!);
    return null;
  }

  static const _tournamentRequestTypes = {
    TournamentNotificationTypes.invitation,
    TournamentNotificationTypes.joinRequest,
    TournamentNotificationTypes.officialInvitation,
  };

  bool matches(NotificationModel n) => switch (kind) {
        NotificationRelationKind.teamJoin => n.type == TeamNotificationTypes.joinRequest &&
            n.teamId == teamId &&
            (n.playerId == id || n.requestId == id),
        NotificationRelationKind.teamInvite =>
          n.type == TeamNotificationTypes.invitation && n.teamId == teamId,
        NotificationRelationKind.tournament =>
          _tournamentRequestTypes.contains(n.type) && n.requestId == id,
        NotificationRelationKind.series => n.type == SeriesNotificationTypes.approvalPending &&
            n.requestId == id,
        NotificationRelationKind.match => n.matchId == id,
      };
}

enum NotificationRelationKind { teamJoin, teamInvite, tournament, series, match }
