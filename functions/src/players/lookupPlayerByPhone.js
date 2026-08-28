const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const E164 = /^\+[1-9]\d{6,14}$/;

function publicPlayerView({ uid, userData, playerData, playerDocId }) {
  const name =
    (playerData && (playerData.name || playerData.fullName)) ||
    (userData && (userData.displayName || userData.name)) ||
    'CrickFlow player';
  const playerId =
    (userData && (userData.playerId || userData.cfPlayerId)) ||
    (playerData && (playerData.playerId || playerData.cfPlayerId)) ||
    null;
  const photoUrl =
    (playerData && playerData.photoUrl) ||
    (userData && userData.photoUrl) ||
    null;
  const onboardingCompleted =
    userData?.onboardingCompleted === true ||
    (typeof playerId === 'string' && playerId.length > 0);

  return {
    exists: true,
    uid,
    playerDocId: playerDocId || uid,
    playerId,
    displayName: String(name).trim() || 'CrickFlow player',
    photoUrl,
    onboardingCompleted,
  };
}

async function loadUserAndPlayer(db, uid) {
  const [userSnap, playerSnap] = await Promise.all([
    db.collection('users').doc(uid).get(),
    db.collection('players').doc(uid).get(),
  ]);
  return {
    userData: userSnap.exists ? userSnap.data() : null,
    playerData: playerSnap.exists ? playerSnap.data() : null,
    playerDocId: playerSnap.exists ? playerSnap.id : uid,
  };
}

async function findUidByPhone(db, phone) {
  const users = db.collection('users');
  for (const field of ['phoneNumber', 'mobile']) {
    const snap = await users.where(field, '==', phone).limit(1).get();
    if (!snap.empty) return snap.docs[0].id;
  }
  return null;
}

/**
 * Returns whether a phone number already belongs to a CrickFlow Auth/user
 * account. Called by a signed-in registrar before creating another player.
 * Returns only public player fields — never email or tokens.
 */
exports.lookupPlayerByPhone = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }

  const phone = String(request.data?.phoneNumber || '').trim();
  if (!E164.test(phone)) {
    throw new HttpsError('invalid-argument', 'Enter a valid mobile number');
  }

  const db = getFirestore();
  const auth = getAuth();

  let uid = null;
  try {
    const record = await auth.getUserByPhoneNumber(phone);
    uid = record.uid;
  } catch (e) {
    if (e.code !== 'auth/user-not-found') {
      console.error('lookupPlayerByPhone auth lookup failed', e);
      throw new HttpsError('internal', 'Could not look up this number');
    }
  }

  if (!uid) {
    uid = await findUidByPhone(db, phone);
  }

  if (!uid) {
    return { exists: false };
  }

  const loaded = await loadUserAndPlayer(db, uid);
  return publicPlayerView({ uid, ...loaded });
});

/**
 * Stamps proxy-registration audit fields using the registrar's Auth token.
 * The new player's profile itself is written by the new Auth user (owner).
 */
exports.stampProxyPlayerRegistration = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }

  const registrarUid = request.auth.uid;
  const newUserId = String(request.data?.newUserId || '').trim();
  const phoneNumber = String(request.data?.phoneNumber || '').trim();

  if (!newUserId || newUserId === registrarUid) {
    throw new HttpsError('invalid-argument', 'Invalid player account');
  }
  if (phoneNumber && !E164.test(phoneNumber)) {
    throw new HttpsError('invalid-argument', 'Enter a valid mobile number');
  }

  const auth = getAuth();
  const db = getFirestore();

  let record;
  try {
    record = await auth.getUser(newUserId);
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      throw new HttpsError('not-found', 'Player account was not created');
    }
    throw new HttpsError('internal', 'Could not verify the new player');
  }

  if (phoneNumber && record.phoneNumber && record.phoneNumber !== phoneNumber) {
    throw new HttpsError('permission-denied', 'Phone number does not match');
  }

  const now = new Date().toISOString();
  const audit = {
    registrationSource: 'registered_by_another_user',
    registeredByUserId: registrarUid,
    registeredAt: now,
    updatedAt: now,
  };

  const userRef = db.collection('users').doc(newUserId);
  const playerRef = db.collection('players').doc(newUserId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new HttpsError('failed-precondition', 'Player profile is not ready');
  }

  await db.runTransaction(async (tx) => {
    tx.set(userRef, audit, { merge: true });
    tx.set(playerRef, audit, { merge: true });
    tx.set(db.collection('registration_events').doc(), {
      type: 'proxy_player_registration',
      newUserId,
      registeredByUserId: registrarUid,
      phoneNumber: record.phoneNumber || phoneNumber || null,
      createdAt: now,
    });
  });

  return { ok: true };
});
