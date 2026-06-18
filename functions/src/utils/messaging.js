const { getMessaging } = require('firebase-admin/messaging');

async function notifyMatchTopic(matchId, title, body, data = {}) {
  try {
    await getMessaging().send({
      topic: `match_${matchId}`,
      notification: { title, body },
      data: { matchId, ...Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, v == null ? '' : String(v)]),
      ) },
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
    matchId: payload.matchId || null,
    teamId: payload.teamId || null,
    type: payload.type || null,
    read: false,
    isRead: false,
    createdAt: new Date().toISOString(),
  });
}

module.exports = { notifyMatchTopic, createUserNotification };
