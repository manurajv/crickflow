const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const { sendPushToUser } = require('./pushUtils');

/**
 * Sends FCM immediately when a pending team join request is created.
 * This is the primary push path for join requests (works background + foreground).
 */
exports.onTeamJoinRequestCreated = onDocumentCreated(
  'teams/{teamId}/join_requests/{requestId}',
  async (event) => {
    const data = event.data?.data();
    if (!data || data.status !== 'pending') return;

    const teamId = event.params.teamId;
    const requestId = event.params.requestId;
    const db = getFirestore();

    const teamSnap = await db.collection('teams').doc(teamId).get();
    if (!teamSnap.exists) return;

    const team = teamSnap.data();
    const requesterUid = data.userId || requestId;
    const playerName =
      data.playerFullName || data.playerName || 'A player';
    const teamName = data.teamName || team.name || 'your team';

    const title = 'Join request';
    const body = `${playerName} requested to join ${teamName}`;

    const leadershipIds = new Set();
    if (team.createdBy) leadershipIds.add(team.createdBy);
    if (team.captainId) leadershipIds.add(team.captainId);
    if (team.viceCaptainId) leadershipIds.add(team.viceCaptainId);

    for (const leadershipId of leadershipIds) {
      if (leadershipId === requesterUid) continue;
      await sendPushToUser(db, leadershipId, {
        title,
        body,
        data: {
          type: 'team_join_request',
          teamId,
          playerId: requesterUid,
        },
      });
    }
  },
);
