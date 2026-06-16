const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const { sendPushToUser } = require('./pushUtils');

/**
 * Sends FCM push for in-app notification docs (except join requests — those
 * are handled by onTeamJoinRequestCreated to avoid duplicate pushes).
 */
exports.onNotificationCreated = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    if (data.type === 'team_join_request') {
      return;
    }

    const userId = data.userId;
    if (!userId) return;

    const db = getFirestore();
    const title = data.title || 'CrickFlow';
    const body = data.body || data.message || '';

    await sendPushToUser(db, userId, {
      title,
      body,
      data: {
        type: data.type || '',
        teamId: data.teamId || '',
        matchId: data.matchId || '',
        playerId: data.playerId || '',
      },
    });
  },
);
