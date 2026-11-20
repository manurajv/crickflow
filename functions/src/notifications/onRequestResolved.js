const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const {
  TOURNAMENT_REQUEST_TYPES,
  isTeamRequestNotification,
  markDocsResolved,
  actionStatusFromRequestStatus,
  resolveActionableNotifications,
} = require('./notificationPriority');

function leftPending(event, field = 'status') {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  return !!before && !!after && before[field] === 'pending' && after[field] !== 'pending';
}

function leftInvited(event) {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  return !!before && !!after
    && (before.status === 'invited' || before.status === 'pending')
    && after.status !== before.status
    && after.status !== 'invited'
    && after.status !== 'pending';
}

/**
 * Once a team join request / invitation is answered (by anyone), every
 * related notification is stamped with the outcome and marked read.
 */
exports.onTeamJoinRequestResolved = onDocumentUpdated(
  'teams/{teamId}/join_requests/{requestId}',
  async (event) => {
    if (!leftPending(event)) return;
    const { teamId, requestId } = event.params;
    const status = actionStatusFromRequestStatus(event.data.after.data()?.status);
    if (!status) return;
    const db = getFirestore();
    const snap = await db.collection('notifications')
      .where('teamId', '==', teamId)
      .where('type', 'in', ['team_join_request', 'team_invitation'])
      .get();
    const docs = snap.docs.filter((d) => isTeamRequestNotification(d.data(), { teamId, requestId }));
    await markDocsResolved(db, docs, status);
    await resolveActionableNotifications(db, { requestId, actionStatus: status });
  },
);

/** Same for tournament team requests / invitations. */
exports.onTournamentTeamRequestResolved = onDocumentUpdated(
  'tournament_team_requests/{requestId}',
  async (event) => {
    if (!leftPending(event)) return;
    const status = actionStatusFromRequestStatus(event.data.after.data()?.status);
    if (!status) return;
    const db = getFirestore();
    const snap = await db.collection('notifications')
      .where('requestId', '==', event.params.requestId)
      .where('type', 'in', TOURNAMENT_REQUEST_TYPES)
      .get();
    await markDocsResolved(db, snap.docs, status);
  },
);

/** Team-admin invitations written on series_club_admins. */
exports.onSeriesClubAdminResolved = onDocumentUpdated(
  'series_club_admins/{adminId}',
  async (event) => {
    if (!leftInvited(event)) return;
    const after = event.data.after.data() || {};
    const status = actionStatusFromRequestStatus(after.status);
    if (!status) return;
    const db = getFirestore();
    await resolveActionableNotifications(db, {
      requestId: event.params.adminId,
      types: ['series_club_admin_invite'],
      seriesId: after.seriesId,
      clubId: after.clubId,
      actionStatus: status,
    });
  },
);

/**
 * Org / team approvals (join, registration, removal, match/tournament
 * proposals). Club-first-pass only resolves club-scoped cards; a final
 * status change resolves every related pending notification.
 */
exports.onSeriesApprovalResolved = onDocumentUpdated(
  'series_approvals/{approvalId}',
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;
    const db = getFirestore();
    const requestId = event.params.approvalId;
    const seriesId = after.seriesId;
    const clubId = after.clubId;
    const types = [
      'series_approval_pending',
      'series_club_join_request',
      'series_player_removal_requested',
    ];

    const beforeClub = (before.metadata || {}).clubReviewStatus;
    const afterClub = (after.metadata || {}).clubReviewStatus;
    if (beforeClub !== 'approved' && afterClub === 'approved' && after.status === 'pending') {
      await resolveActionableNotifications(db, {
        requestId,
        types,
        seriesId,
        clubId,
        actionStatus: 'approved',
        reviewScope: 'club',
      });
      return;
    }

    if (before.status === 'pending' && after.status !== 'pending') {
      if (after.status === 'merged' || after.status === 'superseded') return;
      const status = actionStatusFromRequestStatus(after.status);
      if (!status) return;
      await resolveActionableNotifications(db, {
        requestId,
        types,
        seriesId,
        clubId,
        actionStatus: status,
      });
    }
  },
);
