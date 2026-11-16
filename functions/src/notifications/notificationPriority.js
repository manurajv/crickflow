/**
 * Notifications screen tabs: Priority (requests needing approve / reject /
 * respond, and the decisions on them) vs General (everything else).
 * Mirrors lib/domain/notifications/notification_priority.dart.
 */
const ACTION_TYPES = new Set([
  'team_join_request',
  'team_invitation',
  'tournament_invitation',
  'tournament_join_request',
  'tournament_official_invitation',
  'series_approval_pending',
  'series_club_join_request',
  'series_club_admin_invite',
  'admin_roster_report',
]);

const DECISION_TYPES = new Set([
  'team_join_accepted',
  'team_join_rejected',
  'team_invitation_accepted',
  'team_invitation_rejected',
  'tournament_invitation_accepted',
  'tournament_invitation_rejected',
  'tournament_join_approved',
  'tournament_join_rejected',
  'tournament_official_invitation_accepted',
  'tournament_official_invitation_rejected',
  'series_approval_approved',
  'series_approval_rejected',
  'series_club_admin_invite_accepted',
  'series_club_admin_invite_declined',
  'series_club_admin_invite_cancelled',
  'series_player_removal_requested',
  'series_member_removed',
]);

function isPriorityType(type) {
  return !!type && (ACTION_TYPES.has(type) || DECISION_TYPES.has(type));
}

const TOURNAMENT_REQUEST_TYPES = [
  'tournament_invitation',
  'tournament_join_request',
  'tournament_official_invitation',
];

/** Pure: which notification docs belong to a resolved request. */
function isTeamRequestNotification(n, { teamId, requestId }) {
  if (!n || n.teamId !== teamId) return false;
  if (n.type === 'team_invitation') return n.userId === requestId;
  if (n.type === 'team_join_request') {
    return n.playerId === requestId || n.requestId === requestId;
  }
  return false;
}

/** Marks unread docs read in batches; returns how many. */
async function markDocsRead(db, docs) {
  const unread = docs.filter((d) => d.data().read !== true);
  for (let i = 0; i < unread.length; i += 400) {
    const batch = db.batch();
    unread.slice(i, i + 400).forEach((d) => batch.update(d.ref, { read: true, isRead: true }));
    await batch.commit();
  }
  return unread.length;
}


function actionStatusFromRequestStatus(status) {
  const s = String(status || '').toLowerCase();
  if (['accepted', 'active', 'joined'].includes(s)) return 'accepted';
  if (s === 'declined') return 'declined';
  if (s === 'approved') return 'approved';
  if (['rejected', 'denied'].includes(s)) return 'rejected';
  if (['cancelled', 'canceled'].includes(s)) return 'cancelled';
  if (s === 'expired') return 'expired';
  return '';
}

function actionStatusLabel(status) {
  switch (String(status || '')) {
    case 'accepted': return 'You accepted';
    case 'declined': return 'You declined';
    case 'approved': return 'Approved';
    case 'rejected': return 'Rejected';
    case 'cancelled':
    case 'canceled': return 'Cancelled by sender';
    case 'expired': return 'Expired';
    default: return status || '';
  }
}

/** Marks actionable notification docs resolved: hide buttons, stamp outcome, mark read. */
async function markDocsResolved(db, docs, actionStatus) {
  if (!actionStatus || !docs?.length) return 0;
  const pending = docs.filter((d) => {
    const n = d.data() || {};
    return !n.actionStatus;
  });
  for (let i = 0; i < pending.length; i += 400) {
    const batch = db.batch();
    pending.slice(i, i + 400).forEach((d) => batch.update(d.ref, {
      actionStatus,
      read: true,
      isRead: true,
      actionResolvedAt: new Date().toISOString(),
    }));
    await batch.commit();
  }
  return pending.length;
}

/**
 * Find notifications for a resolved request and stamp [actionStatus].
 * Prefer requestId (set on series invites/approvals). Fall back to type+team/series filters.
 */
async function resolveActionableNotifications(db, {
  requestId,
  types,
  teamId,
  seriesId,
  clubId,
  actionStatus,
  reviewScope,
} = {}) {
  if (!db || !actionStatus) return 0;
  let snap = null;
  if (requestId) {
    snap = await db.collection('notifications').where('requestId', '==', requestId).get();
  } else if (teamId && types?.length) {
    snap = await db.collection('notifications').where('teamId', '==', teamId).where('type', 'in', types.slice(0, 10)).get();
  } else if (seriesId && types?.length) {
    snap = await db.collection('notifications').where('seriesId', '==', seriesId).where('type', 'in', types.slice(0, 10)).get();
  } else {
    return 0;
  }
  const typeSet = types && types.length ? new Set(types) : null;
  const docs = snap.docs.filter((d) => {
    const n = d.data() || {};
    if (typeSet && !typeSet.has(n.type)) return false;
    if (clubId && n.clubId && n.clubId !== clubId) return false;
    if (teamId && n.teamId && n.teamId !== teamId) return false;
    if (reviewScope && n.reviewScope && n.reviewScope !== reviewScope) return false;
    return true;
  });
  return markDocsResolved(db, docs, actionStatus);
}

module.exports = {
  ACTION_TYPES,
  DECISION_TYPES,
  TOURNAMENT_REQUEST_TYPES,
  isPriorityType,
  isTeamRequestNotification,
  markDocsRead,
  markDocsResolved,
  actionStatusFromRequestStatus,
  actionStatusLabel,
  resolveActionableNotifications,
};
