const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const {
  TOURNAMENT_REQUEST_TYPES,
  isTeamRequestNotification,
  markDocsRead,
} = require('./notificationPriority');

function resolved(event) {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  return !!before && !!after && before.status === 'pending' && after.status !== 'pending';
}

/**
 * Once a team join request / invitation is answered (by anyone), every
 * related notification (each leader's copy, duplicates) is marked read.
 */
exports.onTeamJoinRequestResolved = onDocumentUpdated(
  'teams/{teamId}/join_requests/{requestId}',
  async (event) => {
    if (!resolved(event)) return;
    const { teamId, requestId } = event.params;
    const db = getFirestore();
    const snap = await db.collection('notifications')
      .where('teamId', '==', teamId)
      .where('type', 'in', ['team_join_request', 'team_invitation'])
      .get();
    const docs = snap.docs.filter((d) => isTeamRequestNotification(d.data(), { teamId, requestId }));
    await markDocsRead(db, docs);
  },
);

/** Same for tournament team requests / invitations. */
exports.onTournamentTeamRequestResolved = onDocumentUpdated(
  'tournament_team_requests/{requestId}',
  async (event) => {
    if (!resolved(event)) return;
    const db = getFirestore();
    const snap = await db.collection('notifications')
      .where('requestId', '==', event.params.requestId)
      .where('type', 'in', TOURNAMENT_REQUEST_TYPES)
      .get();
    await markDocsRead(db, snap.docs);
  },
);
