const { getMessaging } = require('firebase-admin/messaging');

/**
 * Resolves a player doc id or auth uid to the Firebase Auth uid used in users/{uid}.
 */
async function resolveAuthUid(db, playerOrUserId) {
  if (!playerOrUserId) return null;

  const userSnap = await db.collection('users').doc(playerOrUserId).get();
  if (userSnap.exists) return playerOrUserId;

  const playerSnap = await db.collection('players').doc(playerOrUserId).get();
  if (!playerSnap.exists) return playerOrUserId;

  const linkedUserId = playerSnap.data()?.userId;
  if (linkedUserId && linkedUserId.length > 0) return linkedUserId;
  return playerOrUserId;
}

/**
 * Prefers users/{uid}/private/fcm (owner-only). Falls back to legacy users.fcmToken.
 */
async function resolveFcmToken(db, uid) {
  const privateSnap = await db
    .collection('users')
    .doc(uid)
    .collection('private')
    .doc('fcm')
    .get();
  const privateToken = privateSnap.data()?.fcmToken;
  if (privateToken) return privateToken;

  const userSnap = await db.collection('users').doc(uid).get();
  return userSnap.data()?.fcmToken || null;
}

async function sendPushToUser(db, userId, { title, body, data = {} }) {
  const uid = await resolveAuthUid(db, userId);
  if (!uid) return false;

  const token = await resolveFcmToken(db, uid);
  if (!token) {
    console.warn(`sendPushToUser: no fcmToken for ${uid}`);
    return false;
  }

  const stringData = {};
  for (const [key, value] of Object.entries(data)) {
    stringData[key] = value == null ? '' : String(value);
  }

  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: stringData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'team_join_requests',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });
    return true;
  } catch (err) {
    console.warn(`FCM send failed for ${uid}:`, err.message);
    return false;
  }
}

module.exports = { resolveAuthUid, sendPushToUser, resolveFcmToken };
