import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AdminAuditLogEntry extends Equatable {
  const AdminAuditLogEntry({
    required this.id,
    required this.action,
    required this.actorUid,
    required this.actorEmail,
    required this.targetUid,
    required this.targetEmail,
    required this.timestamp,
    this.reason,
    this.metadata = const {},
  });

  final String id;
  final String action;
  final String actorUid;
  final String actorEmail;
  final String targetUid;
  final String targetEmail;
  final DateTime timestamp;
  final String? reason;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toMap() => {
        'action': action,
        'actorUid': actorUid,
        'actorEmail': actorEmail,
        'targetUid': targetUid,
        'targetEmail': targetEmail,
        'timestamp': timestamp.toIso8601String(),
        'reason': reason,
        'metadata': metadata,
      };

  factory AdminAuditLogEntry.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['timestamp'];
    DateTime time = DateTime.now();
    if (ts is Timestamp) {
      time = ts.toDate();
    } else if (ts is String) {
      time = DateTime.tryParse(ts) ?? time;
    }
    return AdminAuditLogEntry(
      id: id,
      action: map['action'] as String? ?? '',
      actorUid: map['actorUid'] as String? ?? '',
      actorEmail: map['actorEmail'] as String? ?? '',
      targetUid: map['targetUid'] as String? ?? '',
      targetEmail: map['targetEmail'] as String? ?? '',
      timestamp: time,
      reason: map['reason'] as String?,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? const {}),
    );
  }

  @override
  List<Object?> get props => [id, action, targetUid, timestamp];
}

/// Known audit action keys — extend freely.
abstract final class AdminAuditActions {
  static const userSuspended = 'user.suspended';
  static const userUnsuspended = 'user.unsuspended';
  static const userBanned = 'user.banned';
  static const userUnbanned = 'user.unbanned';
  static const userDeleted = 'user.soft_deleted';
  static const userRestored = 'user.restored';
  static const userVerified = 'user.verified';
  static const userUnverified = 'user.unverified';
  static const userEdited = 'user.edited';
  static const userPasswordReset = 'user.password_reset';
  static const userRoleChanged = 'user.role_changed';

  static const tournamentApproved = 'tournament.approved';
  static const tournamentRejected = 'tournament.rejected';
  static const tournamentFeatured = 'tournament.featured';
  static const tournamentUnfeatured = 'tournament.unfeatured';
  static const tournamentEdited = 'tournament.edited';
  static const tournamentCancelled = 'tournament.cancelled';
  static const tournamentSoftDeleted = 'tournament.soft_deleted';
  static const tournamentRestored = 'tournament.restored';
  static const tournamentArchived = 'tournament.archived';

  static const matchEdited = 'match.edited';
  static const matchPaused = 'match.paused';
  static const matchResumed = 'match.resumed';
  static const matchCancelled = 'match.cancelled';
  static const matchAbandoned = 'match.abandoned';
  static const matchFeatured = 'match.featured';
  static const matchUnfeatured = 'match.unfeatured';
  static const matchSoftDeleted = 'match.soft_deleted';
  static const matchRestored = 'match.restored';
  static const matchArchived = 'match.archived';

  static const teamEdited = 'team.edited';
  static const teamVerified = 'team.verified';
  static const teamUnverified = 'team.unverified';
  static const teamSuspended = 'team.suspended';
  static const teamUnsuspended = 'team.unsuspended';
  static const teamFeatured = 'team.featured';
  static const teamUnfeatured = 'team.unfeatured';
  static const teamSoftDeleted = 'team.soft_deleted';
  static const teamRestored = 'team.restored';
  static const teamArchived = 'team.archived';

  static const groundEdited = 'ground.edited';
  static const groundVerified = 'ground.verified';
  static const groundUnverified = 'ground.unverified';
  static const groundSuspended = 'ground.suspended';
  static const groundUnsuspended = 'ground.unsuspended';
  static const groundFeatured = 'ground.featured';
  static const groundUnfeatured = 'ground.unfeatured';
  static const groundSoftDeleted = 'ground.soft_deleted';
  static const groundRestored = 'ground.restored';
  static const groundArchived = 'ground.archived';
  static const groundCreated = 'ground.created';

  static const broadcastFeatured = 'broadcast.featured';
  static const broadcastUnfeatured = 'broadcast.unfeatured';
  static const broadcastSoftDeleted = 'broadcast.soft_deleted';
  static const broadcastRestored = 'broadcast.restored';
  static const broadcastArchived = 'broadcast.archived';

  static const communityHidden = 'community.hidden';
  static const communityUnhidden = 'community.unhidden';
  static const communityRemoved = 'community.removed';
  static const communityRestored = 'community.restored';
  static const communityFeatured = 'community.featured';
  static const communityUnfeatured = 'community.unfeatured';
  static const communityApproved = 'community.approved';
  static const communityArchived = 'community.archived';
  static const discoverRemoved = 'discover.removed';
  static const discoverRestored = 'discover.restored';
  static const discoverFeatured = 'discover.featured';
  static const discoverUnfeatured = 'discover.unfeatured';
  static const discoverPinned = 'discover.pinned';
  static const discoverUnpinned = 'discover.unpinned';
  static const reportResolved = 'report.resolved';
  static const reportDismissed = 'report.dismissed';

  static const notificationCreated = 'notification.created';
  static const notificationEdited = 'notification.edited';
  static const notificationScheduled = 'notification.scheduled';
  static const notificationCancelled = 'notification.cancelled';
  static const notificationSent = 'notification.sent';
  static const notificationQueued = 'notification.queued';
  static const notificationDuplicated = 'notification.duplicated';
  static const notificationArchived = 'notification.archived';
  static const notificationDeleted = 'notification.deleted';
  static const announcementCreated = 'announcement.created';
  static const announcementEdited = 'announcement.edited';
  static const announcementArchived = 'announcement.archived';
  static const announcementDeleted = 'announcement.deleted';
  static const templateCreated = 'notification_template.created';
  static const templateEdited = 'notification_template.edited';
  static const templateDeleted = 'notification_template.deleted';
  static const segmentCreated = 'notification_segment.created';
  static const segmentEdited = 'notification_segment.edited';
  static const segmentDeleted = 'notification_segment.deleted';

  static const adCreated = 'ad.created';
  static const adEdited = 'ad.edited';
  static const adApproved = 'ad.approved';
  static const adRejected = 'ad.rejected';
  static const adPaused = 'ad.paused';
  static const adResumed = 'ad.resumed';
  static const adArchived = 'ad.archived';
  static const adDeleted = 'ad.deleted';
  static const adScheduled = 'ad.scheduled';
  static const adFeatured = 'ad.featured';
  static const adDuplicated = 'ad.duplicated';
  static const advertiserCreated = 'advertiser.created';
  static const advertiserEdited = 'advertiser.edited';
  static const advertiserDeleted = 'advertiser.deleted';
  static const admobConfigUpdated = 'admob.config_updated';
  static const sponsoredCreated = 'sponsored.created';
  static const sponsoredEdited = 'sponsored.edited';
  static const sponsoredDeleted = 'sponsored.deleted';

  static const organizationCreated = 'organization.created';
  static const organizationEdited = 'organization.edited';
  static const organizationApproved = 'organization.approved';
  static const organizationVerified = 'organization.verified';
  static const organizationActivated = 'organization.activated';
  static const organizationDeactivated = 'organization.deactivated';
  static const organizationPending = 'organization.pending';
  static const organizationSuspended = 'organization.suspended';
  static const organizationArchived = 'organization.archived';
  static const organizationUnarchived = 'organization.unarchived';
  static const organizationSoftDeleted = 'organization.soft_deleted';
  static const organizationRestored = 'organization.restored';
  static const organizationFeatured = 'organization.featured';
  static const organizationUnfeatured = 'organization.unfeatured';
  static const organizationAdminLinked = 'organization.admin_linked';
  static const organizationAdminUnlinked = 'organization.admin_unlinked';
  static const organizationOwnershipTransferred =
      'organization.ownership_transferred';

  static const settingsUpdated = 'settings.updated';
  static const featureFlagEnabled = 'feature_flag.enabled';
  static const featureFlagDisabled = 'feature_flag.disabled';
  static const remoteConfigUpdated = 'remote_config.updated';
  static const remoteConfigDeleted = 'remote_config.deleted';
  static const appVersionUpdated = 'app_version.updated';
  static const maintenanceStarted = 'maintenance.started';
  static const maintenanceEnded = 'maintenance.ended';
  static const maintenanceUpdated = 'maintenance.updated';
  static const cmsPageUpdated = 'cms.page_updated';
  static const legalPageUpdated = 'legal.page_updated';

  // Auth / security (admin panel only — never logs secrets)
  static const adminLoginSuccess = 'auth.login_success';
  static const adminLoginFailed = 'auth.login_failed';
  static const adminLogout = 'auth.logout';
  static const adminPasswordResetRequested = 'auth.password_reset_requested';
  static const adminSessionBlocked = 'auth.session_blocked';
  static const securitySuspiciousLogin = 'security.suspicious_login';
  static const securityUnknownDevice = 'security.unknown_device';
  static const securityPermissionEscalation = 'security.permission_escalation';
  static const securityBlockedAccess = 'security.blocked_access';
  static const securityRoleCreated = 'security.role_created';
  static const securityRoleUpdated = 'security.role_updated';
  static const securityRoleDuplicated = 'security.role_duplicated';
  static const securityRoleRenamed = 'security.role_renamed';
  static const securityRoleArchived = 'security.role_archived';
  static const securityRoleDeleted = 'security.role_deleted';
  static const securityPermissionChanged = 'security.permission_changed';
  static const securitySessionTerminated = 'security.session_terminated';
  static const securitySessionsTerminatedAll = 'security.sessions_terminated_all';
  static const securityBlockAdded = 'security.block_added';
  static const securityIpBlocked = 'security.ip_blocked';
  static const securityIpUnblocked = 'security.ip_unblocked';
  static const securityIpRuleUpdated = 'security.ip_rule_updated';
  static const securityAccessGranted = 'security.access_granted';
  static const securityBackupCreated = 'security.backup_created';
  static const securityPolicyUpdated = 'security.policy_updated';

  // Support Center
  static const supportTicketCreated = 'support.ticket_created';
  static const supportTicketAssigned = 'support.ticket_assigned';
  static const supportTicketTransferred = 'support.ticket_transferred';
  static const supportTicketEscalated = 'support.ticket_escalated';
  static const supportTicketResolved = 'support.ticket_resolved';
  static const supportTicketClosed = 'support.ticket_closed';
  static const supportTicketReopened = 'support.ticket_reopened';
  static const supportInternalNoteAdded = 'support.internal_note_added';
  static const supportKbUpdated = 'support.kb_updated';
  static const supportFaqUpdated = 'support.faq_updated';
  static const supportAnnouncementUpdated = 'support.announcement_updated';
}

class UserActivityItem extends Equatable {
  const UserActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
    required this.iconKey,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime occurredAt;
  final String iconKey;

  @override
  List<Object?> get props => [id, occurredAt];
}
