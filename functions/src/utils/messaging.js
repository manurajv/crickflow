const { getMessaging } = require('firebase-admin/messaging');

/** High-priority match channel — must match Flutter PushNotificationHandler. */
const MATCH_CHANNEL_ID = 'crickflow_match';

async function notifyMatchTopic(matchId, title, body, data = {}) {
  try {
    await getMessaging().send({
      topic: `match_${matchId}`,
      notification: { title, body },
      data: {
        matchId,
        ...Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, v == null ? '' : String(v)]),
        ),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: MATCH_CHANNEL_ID,
          priority: 'high',
          defaultSound: true,
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
            'mutable-content': 1,
          },
        },
      },
    });
  } catch (err) {
    console.warn('FCM topic send failed:', err.message);
  }
}

async function createUserNotification(db, userId, payload) {
  if (!userId) return;
  await db.collection('notifications').add({
    userId,
    title: payload.title,
    body: payload.body,
    message: payload.body,
    matchTitle: payload.matchTitle || null,
    matchId: payload.matchId || null,
    teamId: payload.teamId || null,
    playerId: payload.playerId || null,
    tournamentId: payload.tournamentId || null,
    type: payload.type || null,
    category: payload.category || null,
    tab: payload.tab || null,
    actionStatus: payload.actionStatus || null,
    perspective: payload.perspective || null,
    pushSent: payload.pushSent === true,
    read: false,
    isRead: false,
    createdAt: new Date().toISOString(),
  });
}

module.exports = { notifyMatchTopic, createUserNotification, MATCH_CHANNEL_ID };
