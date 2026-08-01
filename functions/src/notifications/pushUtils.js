const { getMessaging } = require('firebase-admin/messaging');
const { MATCH_CHANNEL_ID } = require('../utils/messaging');

const JOIN_CHANNEL_ID = 'team_join_requests';
const DEFAULT_CHANNEL_ID = 'crickflow_default';

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

function androidChannelForData(data = {}) {
  const type = String(data.type || '');
  const category = String(data.category || '');
  if (type === 'team_join_request') return JOIN_CHANNEL_ID;
  if (
    category === 'match' ||
    category === 'live_match' ||
    category === 'streaming' ||
    type.startsWith('match_') ||
    type === 'wicket' ||
    type === 'hat_trick' ||
    type.includes('milestone') ||
    type.includes('stream') ||
    type.includes('innings') ||
    type.includes('dls') ||
    type.includes('target')
  ) {
    return MATCH_CHANNEL_ID;
  }
  return DEFAULT_CHANNEL_ID;
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

  const channelId = androidChannelForData(stringData);

  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: stringData,
      android: {
        priority: 'high',
        notification: {
          channelId,
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
