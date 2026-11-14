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

module.exports = {
  ACTION_TYPES,
  DECISION_TYPES,
  TOURNAMENT_REQUEST_TYPES,
  isPriorityType,
  isTeamRequestNotification,
  markDocsRead,
};
