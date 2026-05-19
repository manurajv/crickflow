const { getMessaging } = require('firebase-admin/messaging');

async function notifyMatchTopic(matchId, title, body, data = {}) {
  try {
    await getMessaging().send({
      topic: `match_${matchId}`,
      notification: { title, body },
      data: { matchId, ...data },
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
    read: false,
    createdAt: new Date().toISOString(),
  });
}

module.exports = { notifyMatchTopic, createUserNotification };
