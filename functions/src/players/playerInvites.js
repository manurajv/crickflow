const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { randomUUID } = require('crypto');

const E164 = /^\+[1-9]\d{6,14}$/;
const INVITE_TTL_MS = 14 * 24 * 60 * 60 * 1000;
const MAX_PENDING_PER_REGISTRAR = 40;
const WEB_BASE = (process.env.CRICKFLOW_WEB_URL || 'https://crickflow.web.app').replace(
  /\/$/,
  '',
);

function inviteUrl(id) {
  return `${WEB_BASE}/invite/${id}/`;
}

async function findUidByPhone(db, phone) {
  const users = db.collection('users');
  for (const field of ['phoneNumber', 'mobile']) {
    const snap = await users.where(field, '==', phone).limit(1).get();
    if (!snap.empty) return snap.docs[0].id;
  }
  return null;
}

async function existingAuthUid(phone) {
  try {
    const record = await getAuth().getUserByPhoneNumber(phone);
    return record.uid;
  } catch (e) {
    if (e.code === 'auth/user-not-found') return null;
    throw e;
  }
}

function signInProvider(auth) {
  return auth?.token?.firebase?.sign_in_provider || null;
}

/**
 * Registrar creates a shareable invite. No SMS is sent from this device.
 * - phone: optional E.164 target (player can still accept with Google)
 * - inviteType: "phone" | "google" | "either" (default either when phone set, google when not)
 */
exports.createPlayerInvite = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }

  const registrarUid = request.auth.uid;
  const phoneRaw = String(request.data?.phoneNumber || '').trim();
  const phone = phoneRaw || null;
  const displayName = String(request.data?.displayName || '').trim().slice(0, 50);
  const requestedType = String(request.data?.inviteType || '').trim().toLowerCase();

  if (phone && !E164.test(phone)) {
    throw new HttpsError('invalid-argument', 'Enter a valid mobile number');
  }
  if (!phone && requestedType === 'phone') {
    throw new HttpsError('invalid-argument', 'Enter a valid mobile number');
  }

  const inviteType =
    requestedType === 'phone' || requestedType === 'google' || requestedType === 'either'
      ? requestedType
      : phone
        ? 'either'
        : 'google';

  if (inviteType === 'phone' && !phone) {
    throw new HttpsError('invalid-argument', 'Enter a valid mobile number');
  }

  const db = getFirestore();

  if (phone) {
    let existingUid = await existingAuthUid(phone);
    if (!existingUid) {
      existingUid = await findUidByPhone(db, phone);
    }
    if (existingUid) {
      throw new HttpsError(
        'already-exists',
        'This number already has a CrickFlow account',
      );
    }
  }

  const pendingSnap = await db
    .collection('player_invites')
    .where('invitedByUserId', '==', registrarUid)
    .limit(80)
    .get();

  const nowMs = Date.now();
  const reusable = pendingSnap.docs.find((d) => {
    const data = d.data() || {};
    if (data.status !== 'pending') return false;
    const exp = Date.parse(data.expiresAt || '') || 0;
    if (exp <= nowMs) return false;
    if (phone) return data.phoneNumber === phone;
    return !data.phoneNumber && (data.inviteType === 'google' || data.inviteType === 'either');
  });
  if (reusable) {
    return {
      exists: false,
      inviteId: reusable.id,
      url: inviteUrl(reusable.id),
      expiresAt: reusable.data().expiresAt,
      reused: true,
      inviteType: reusable.data().inviteType || inviteType,
    };
  }

  const activeCount = pendingSnap.docs.filter((d) => {
    const data = d.data() || {};
    if (data.status !== 'pending') return false;
    const exp = Date.parse(data.expiresAt || '') || 0;
    return exp > nowMs;
  }).length;
  if (activeCount >= MAX_PENDING_PER_REGISTRAR) {
    throw new HttpsError(
      'resource-exhausted',
      'You have too many pending invites. Wait for some to be accepted or expire.',
    );
  }

  let invitedByName = 'A CrickFlow user';
  try {
    const registrar = await db.collection('users').doc(registrarUid).get();
    const data = registrar.data() || {};
    invitedByName =
      String(data.displayName || data.name || '').trim() || invitedByName;
  } catch (_) {}

  const inviteId = randomUUID().replace(/-/g, '').slice(0, 22);
  const now = new Date();
  const expiresAt = new Date(nowMs + INVITE_TTL_MS).toISOString();
  const payload = {
    phoneNumber: phone,
    displayName: displayName || null,
    invitedByUserId: registrarUid,
    invitedByName,
    inviteType,
    status: 'pending',
    createdAt: now.toISOString(),
    expiresAt,
    registrationSource: 'invited_by_another_user',
  };

  await db.collection('player_invites').doc(inviteId).set(payload);

  return {
    exists: false,
    inviteId,
    url: inviteUrl(inviteId),
    expiresAt,
    reused: false,
    inviteType,
  };
});

/**
 * Invited player accepts after signing in with phone OTP and/or Google.
 * Phone-targeted invites: matching phone OR Google.
 * Google/open invites: Google (or any phone sign-in).
 */
exports.acceptPlayerInvite = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }

  const inviteId = String(request.data?.inviteId || '').trim();
  if (!inviteId) {
    throw new HttpsError('invalid-argument', 'Invite is missing');
  }

  const uid = request.auth.uid;
  const tokenPhone = request.auth.token?.phone_number || null;
  const provider = signInProvider(request.auth);
  const db = getFirestore();
  const inviteRef = db.collection('player_invites').doc(inviteId);
  const inviteSnap = await inviteRef.get();
  if (!inviteSnap.exists) {
    throw new HttpsError('not-found', 'This invite link is not valid');
  }

  const invite = inviteSnap.data() || {};
  const exp = Date.parse(invite.expiresAt || '') || 0;
  if (invite.status === 'accepted' && invite.acceptedByUserId === uid) {
    return { ok: true, alreadyAccepted: true };
  }
  if (invite.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'This invite is no longer active');
  }
  if (exp && exp < Date.now()) {
    await inviteRef.set({ status: 'expired' }, { merge: true });
    throw new HttpsError('failed-precondition', 'This invite has expired');
  }

  let authPhone = tokenPhone;
  if (!authPhone) {
    try {
      const record = await getAuth().getUser(uid);
      authPhone = record.phoneNumber || null;
    } catch (_) {}
  }

  const invitePhone = invite.phoneNumber || null;
  const phoneMatches = Boolean(invitePhone && authPhone && authPhone === invitePhone);
  const isGoogle = provider === 'google.com';
  const isPhoneAuth = provider === 'phone' || Boolean(authPhone);
  const inviteType = invite.inviteType || (invitePhone ? 'either' : 'google');

  let acceptedVia = null;
  if (phoneMatches) {
    acceptedVia = 'phone';
  } else if (isGoogle && (inviteType === 'google' || inviteType === 'either' || !invitePhone)) {
    acceptedVia = 'google';
  } else if (!invitePhone && isPhoneAuth) {
    acceptedVia = 'phone';
  } else if (isGoogle && invitePhone) {
    // Phone-targeted invite may still be claimed via Google (possession of link).
    acceptedVia = 'google';
  }

  if (!acceptedVia) {
    throw new HttpsError(
      'permission-denied',
      invitePhone
        ? 'Sign in with Google or the invited mobile number to accept this invite'
        : 'Sign in with Google or your phone to accept this invite',
    );
  }

  const now = new Date().toISOString();
  const audit = {
    registrationSource: 'invited_by_another_user',
    registeredByUserId: invite.invitedByUserId || null,
    invitedAt: invite.createdAt || now,
    registeredAt: now,
    updatedAt: now,
    inviteAcceptedVia: acceptedVia,
  };
  if (invite.displayName) {
    audit.invitedDisplayName = invite.displayName;
  }
  if (invitePhone && !authPhone) {
    audit.invitedPhoneNumber = invitePhone;
  }

  const userRef = db.collection('users').doc(uid);
  const playerRef = db.collection('players').doc(uid);

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(inviteRef);
    const data = fresh.data() || {};
    if (data.status === 'accepted' && data.acceptedByUserId === uid) {
      return;
    }
    if (data.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'This invite is no longer active');
    }
    tx.set(
      inviteRef,
      {
        status: 'accepted',
        acceptedByUserId: uid,
        acceptedAt: now,
        acceptedVia,
        updatedAt: now,
      },
      { merge: true },
    );
    tx.set(userRef, audit, { merge: true });
    tx.set(playerRef, audit, { merge: true });
    tx.set(db.collection('registration_events').doc(), {
      type: 'player_invite_accepted',
      inviteId,
      newUserId: uid,
      registeredByUserId: invite.invitedByUserId || null,
      phoneNumber: invitePhone,
      acceptedVia,
      createdAt: now,
    });
  });

  return { ok: true, alreadyAccepted: false, acceptedVia };
});
