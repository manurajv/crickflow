/**
 * Super-admin notification campaign mass send.
 *
 * Callable starts (or dry-runs) a campaign. A Firestore worker continues
 * chunks while status === 'sending' and deliveryEngine === 'v1'.
 * Old "queued" stub campaigns are never auto-sent.
 *
 * FCM uses batched tokens from users/{uid}/private/fcm (legacy
 * users.fcmToken as fallback). There is no all-users topic subscription
 * in the mobile app, so "everyone" is token-batched, not a topic send.
 *
 * Inbox docs are written with pushSent: true so onNotificationCreated
 * does not send a second push.
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { getFirestore, FieldPath, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { adminHasPermission } = require('./adminDeleteEntity');

const DELIVERY_ENGINE = 'v1';
const CHUNK_SIZE = 200;
const FCM_BATCH = 500;
const INBOX_BATCH = 400;
const MAX_STARTS_PER_HOUR = 10;
const MAX_DRY_RUN_SCAN = 5000;
const LEASE_MS = 120000;
const RATE_DOC = 'admin_notification_meta/sendRate';
const CAMPAIGNS = 'admin_notification_campaigns';
const AUDIT = 'admin_audit_logs';

const FOLLOWER_AUDIENCES = new Set([
  'followers',
  'tournamentFollowers',
  'teamFollowers',
  'matchFollowers',
  'playerFollowers',
  'groundFollowers',
]);

const UNSUPPORTED_AUDIENCES = new Set([
  'communityMembers',
  'scorers',
  'groundFollowers',
  'tournamentFollowers',
  'followers',
]);

function httpsError(code, message) {
  return new HttpsError(code, message);
}

async function assertCanSend(db, uid) {
  if (!uid) throw httpsError('unauthenticated', 'Sign in required');
  const adminSnap = await db.collection('admin_users').doc(uid).get();
  const admin = adminSnap.exists ? adminSnap.data() : null;
  let role = null;
  if (admin?.roleId && admin.roleId !== 'superAdmin') {
    const r = await db.collection('admin_roles').doc(admin.roleId).get();
    role = r.exists ? r.data() : null;
  }
  if (!adminHasPermission(admin, role, 'canSendNotifications')) {
    throw httpsError('permission-denied', 'Sending campaigns requires canSendNotifications');
  }
  return admin;
}

function userCountry(user) {
  const loc = user?.location && typeof user.location === 'object' ? user.location : {};
  return String(user?.country || loc.country || '').trim();
}
function userState(user) {
  const loc = user?.location && typeof user.location === 'object' ? user.location : {};
  return String(user?.stateProvince || user?.state || loc.stateProvince || loc.state || '').trim();
}
function userCity(user) {
  const loc = user?.location && typeof user.location === 'object' ? user.location : {};
  return String(user?.city || loc.city || '').trim();
}

function shouldIncludeUser(user, campaign) {
  const status = String(user?.accountStatus || 'active');
  if (status && status !== 'active') return { ok: false, reason: 'status' };

  const prefs = user?.notificationPrefs && typeof user.notificationPrefs === 'object'
    ? user.notificationPrefs
    : {};
  if (prefs.notificationsEnabled === false) return { ok: false, reason: 'prefs' };
  if (prefs.receiveAdminNotifications === false) return { ok: false, reason: 'prefs' };

  const type = String(campaign.type || 'system');
  if (type === 'promotion' && prefs.receivePromotions === false) {
    return { ok: false, reason: 'prefs' };
  }
  if (type === 'match' && prefs.receiveTeamMatchNotifications === false) {
    return { ok: false, reason: 'prefs' };
  }
  if (FOLLOWER_AUDIENCES.has(String(campaign.audience || '')) &&
      prefs.receiveFollowerNotifications === false) {
    return { ok: false, reason: 'prefs' };
  }
  return { ok: true };
}

function audienceIdsOf(campaign) {
  const ids = Array.isArray(campaign.audienceIds) ? campaign.audienceIds : [];
  return [...new Set(ids.map((id) => String(id || '').trim()).filter(Boolean))];
}

function entityIds(campaign, fallbackField) {
  const ids = audienceIdsOf(campaign);
  const extra = campaign[fallbackField];
  if (extra && !ids.includes(extra)) ids.push(String(extra));
  return ids;
}

/**
 * One page of candidate UIDs (not yet pref-filtered).
 * @returns {{ uids: string[], nextCursor: object|null, scanned: number }}
 */
async function resolveAudiencePage(db, campaign, cursor, limit = CHUNK_SIZE) {
  const audience = String(campaign.audience || 'everyone');
  if (UNSUPPORTED_AUDIENCES.has(audience)) {
    throw httpsError(
      'failed-precondition',
      `Audience "${audience}" has no reliable recipient list in Firestore. ` +
        'Use Everyone, a country/state/city, specific users, teams, players, admins, moderators, or team/match/player followers.',
    );
  }

  if (audience === 'specificUsers' || audience === 'customList') {
    const ids = audienceIdsOf(campaign);
    if (!ids.length) {
      throw httpsError('invalid-argument', 'This audience needs at least one user id');
    }
    const start = cursor?.index || 0;
    const slice = ids.slice(start, start + limit);
    const next = start + slice.length < ids.length ? { index: start + slice.length } : null;
    return { uids: slice, nextCursor: next, scanned: slice.length };
  }

  if (audience === 'admins' || audience === 'moderators') {
    let q = db.collection('admin_users');
    const snap = await q.limit(500).get();
    const uids = [];
    for (const d of snap.docs) {
      const data = d.data() || {};
      if (data.isActive !== true) continue;
      if ((data.accessStatus || 'active') !== 'active') continue;
      if (audience === 'moderators' && data.roleId !== 'moderator') continue;
      uids.push(d.id);
    }
    const start = cursor?.index || 0;
    const slice = uids.slice(start, start + limit);
    const next = start + slice.length < uids.length ? { index: start + slice.length } : null;
    return { uids: slice, nextCursor: next, scanned: slice.length };
  }

  if (audience === 'specificTeams') {
    const teamIds = entityIds(campaign, 'teamId');
    if (!teamIds.length) {
      throw httpsError('invalid-argument', 'Team audience needs team ids');
    }
    const uids = new Set();
    for (const teamId of teamIds) {
      const team = await db.collection('teams').doc(teamId).get();
      if (!team.exists) continue;
      const data = team.data() || {};
      if (data.createdBy) uids.add(String(data.createdBy));
      for (const pid of data.playerIds || []) {
        if (!pid) continue;
        const player = await db.collection('players').doc(String(pid)).get();
        if (player.exists && player.data()?.userId) {
          uids.add(String(player.data().userId));
        } else {
          const asUser = await db.collection('users').doc(String(pid)).get();
          if (asUser.exists) uids.add(String(pid));
        }
      }
    }
    const list = [...uids];
    const start = cursor?.index || 0;
    const slice = list.slice(start, start + limit);
    const next = start + slice.length < list.length ? { index: start + slice.length } : null;
    return { uids: slice, nextCursor: next, scanned: slice.length };
  }

  if (audience === 'teamFollowers' || audience === 'matchFollowers' || audience === 'playerFollowers') {
    const cfg = {
      teamFollowers: { col: 'teamFollowers', field: 'teamId', fallback: 'teamId', uidField: 'userId' },
      matchFollowers: { col: 'matchFollowers', field: 'matchId', fallback: 'matchId', uidField: 'userId' },
      playerFollowers: { col: 'playerFollows', field: 'followedUserId', fallback: null, uidField: 'followerUserId' },
    }[audience];
    const ids = cfg.fallback ? entityIds(campaign, cfg.fallback) : audienceIdsOf(campaign);
    if (!ids.length) {
      throw httpsError('invalid-argument', `${audience} needs the followed entity id`);
    }
    const uids = new Set();
    for (const id of ids) {
      const snap = await db.collection(cfg.col).where(cfg.field, '==', id).limit(2000).get();
      for (const d of snap.docs) {
        const uid = d.data()?.[cfg.uidField];
        if (uid) uids.add(String(uid));
      }
    }
    const list = [...uids];
    const start = cursor?.index || 0;
    const slice = list.slice(start, start + limit);
    const next = start + slice.length < list.length ? { index: start + slice.length } : null;
    return { uids: slice, nextCursor: next, scanned: slice.length };
  }

  if (audience === 'players') {
    let q = db.collection('players').orderBy(FieldPath.documentId).limit(limit);
    if (cursor?.lastId) q = q.startAfter(cursor.lastId);
    const snap = await q.get();
    const uids = [];
    let lastId = cursor?.lastId || null;
    for (const d of snap.docs) {
      lastId = d.id;
      const uid = d.data()?.userId;
      if (uid) uids.push(String(uid));
    }
    const next = snap.docs.length < limit ? null : { lastId };
    return { uids, nextCursor: next, scanned: snap.docs.length };
  }

  // everyone / country / state / city — page through users.
  let q = db.collection('users').orderBy(FieldPath.documentId).limit(limit);
  if (cursor?.lastId) q = q.startAfter(cursor.lastId);
  const snap = await q.get();
  const uids = [];
  let lastId = cursor?.lastId || null;
  for (const d of snap.docs) {
    lastId = d.id;
    const data = d.data() || {};
    if (audience === 'country') {
      const want = String(campaign.country || '').trim();
      if (!want || userCountry(data) !== want) continue;
    } else if (audience === 'state') {
      const want = String(campaign.stateProvince || campaign.state || '').trim();
      if (!want || userState(data) !== want) continue;
    } else if (audience === 'city') {
      const want = String(campaign.city || '').trim();
      if (!want || userCity(data) !== want) continue;
    }
    uids.push(d.id);
  }
  const next = snap.docs.length < limit ? null : { lastId };
  return { uids, nextCursor: next, scanned: snap.docs.length };
}

async function resolveFcmToken(db, uid) {
  const privateSnap = await db.collection('users').doc(uid).collection('private').doc('fcm').get();
  const privateToken = privateSnap.data()?.fcmToken;
  if (privateToken) return String(privateToken);
  const userSnap = await db.collection('users').doc(uid).get();
  return userSnap.data()?.fcmToken ? String(userSnap.data().fcmToken) : null;
}

async function sendFcmBatch(messaging, messages) {
  if (!messaging || !messages.length) return { success: 0, failure: 0 };
  let success = 0;
  let failure = 0;
  for (let i = 0; i < messages.length; i += FCM_BATCH) {
    const chunk = messages.slice(i, i + FCM_BATCH);
    // Prefer sendEach so each token has its own result even if payloads match.
    const res = await messaging.sendEach(chunk);
    if (res && Array.isArray(res.responses)) {
      for (const r of res.responses) {
        if (r.success) success += 1;
        else failure += 1;
      }
    } else if (typeof res?.successCount === 'number') {
      success += res.successCount;
      failure += res.failureCount || 0;
    } else {
      success += chunk.length;
    }
  }
  return { success, failure };
}

function buildFcmMessage(token, campaign) {
  const data = {
    type: `admin_${campaign.type || 'system'}`,
    category: String(campaign.type || 'system'),
    tab: String(campaign.deepLink || ''),
    adminCampaignId: String(campaign.id || ''),
    tournamentId: String(campaign.tournamentId || ''),
    matchId: String(campaign.matchId || ''),
    teamId: String(campaign.teamId || ''),
  };
  const stringData = {};
  for (const [k, v] of Object.entries(data)) stringData[k] = v == null ? '' : String(v);
  const silent = campaign.sound === 'silent';
  return {
    token,
    notification: {
      title: campaign.title || 'CrickFlow',
      body: campaign.body || '',
    },
    data: stringData,
    android: {
      priority: campaign.priority === 'critical' || campaign.priority === 'high' ? 'high' : 'normal',
      notification: {
        channelId: 'crickflow_default',
        defaultSound: !silent,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: silent ? undefined : 'default',
          badge: 1,
        },
      },
    },
  };
}

async function writeInbox(db, campaign, actorUid, uids, ts) {
  for (let i = 0; i < uids.length; i += INBOX_BATCH) {
    const batch = db.batch();
    for (const uid of uids.slice(i, i + INBOX_BATCH)) {
      const ref = db.collection('notifications').doc();
      batch.set(ref, {
        userId: uid,
        title: campaign.title || 'CrickFlow',
        body: campaign.body || '',
        type: `admin_${campaign.type || 'system'}`,
        category: campaign.type || 'system',
        tab: campaign.deepLink || null,
        addedByUserId: actorUid || campaign.createdByUid || '',
        read: false,
        createdAt: ts,
        adminCampaignId: campaign.id,
        pushSent: true,
        tournamentId: campaign.tournamentId || null,
        matchId: campaign.matchId || null,
        teamId: campaign.teamId || null,
      });
    }
    await batch.commit();
  }
}

async function writeAudit(db, { action, actor, campaign, reason, metadata }) {
  const ref = db.collection(AUDIT).doc();
  await ref.set({
    action,
    actorUid: actor?.uid || actor?.id || '',
    actorEmail: actor?.email || '',
    targetUid: campaign.id,
    targetId: campaign.id,
    targetLabel: campaign.title || campaign.campaignName || campaign.id,
    timestamp: new Date().toISOString(),
    reason: reason || null,
    module: 'notifications',
    metadata: metadata || {},
  });
}

function hourKey(date = new Date()) {
  return date.toISOString().slice(0, 13); // YYYY-MM-DDTHH
}

async function assertRateLimits(db, { campaignId, dryRun }) {
  if (dryRun) return;
  const ref = db.doc ? db.doc(RATE_DOC) : db.collection('admin_notification_meta').doc('sendRate');
  const snap = await ref.get();
  const data = snap.exists ? snap.data() || {} : {};
  if (data.sendingCampaignId && data.sendingCampaignId !== campaignId) {
    throw httpsError(
      'resource-exhausted',
      `Another campaign (${data.sendingCampaignId}) is already sending. Wait for it to finish.`,
    );
  }
  const key = hourKey();
  const count = data.hourKey === key ? (data.startsThisHour || 0) : 0;
  if (count >= MAX_STARTS_PER_HOUR) {
    throw httpsError(
      'resource-exhausted',
      `Rate limit: at most ${MAX_STARTS_PER_HOUR} campaign sends can start per hour.`,
    );
  }
  await ref.set({
    hourKey: key,
    startsThisHour: count + 1,
    sendingCampaignId: campaignId,
    lastStartedAt: new Date().toISOString(),
  }, { merge: true });
}

async function clearSendingLock(db, campaignId) {
  const ref = db.doc ? db.doc(RATE_DOC) : db.collection('admin_notification_meta').doc('sendRate');
  const snap = await ref.get();
  const data = snap.exists ? snap.data() || {} : {};
  if (data.sendingCampaignId === campaignId) {
    await ref.set({ sendingCampaignId: FieldValue.delete() }, { merge: true });
  }
}

async function loadUsers(db, uids) {
  const out = new Map();
  for (const uid of uids) {
    const snap = await db.collection('users').doc(uid).get();
    out.set(uid, snap.exists ? snap.data() || {} : null);
  }
  return out;
}

/**
 * Process one chunk (or a full dry-run up to MAX_DRY_RUN_SCAN).
 */
async function processCampaignChunk({
  db,
  messaging,
  campaign,
  cursor,
  dryRun,
  actorUid,
  limit = CHUNK_SIZE,
  maxScan,
}) {
  const ts = new Date().toISOString();
  let pageCursor = cursor || null;
  let scanned = 0;
  let inbox = 0;
  let delivered = 0;
  let failed = 0;
  let skippedPrefs = 0;
  let skippedNoToken = 0;
  let skippedStatus = 0;
  let truncated = false;
  let nextCursor = null;
  const scanCap = dryRun ? (maxScan || MAX_DRY_RUN_SCAN) : limit;

  do {
    const page = await resolveAudiencePage(db, campaign, pageCursor, limit);
    scanned += page.scanned;
    nextCursor = page.nextCursor;
    pageCursor = page.nextCursor;

    const users = await loadUsers(db, page.uids);
    const eligible = [];
    for (const uid of page.uids) {
      const user = users.get(uid);
      if (!user) {
        skippedStatus += 1;
        continue;
      }
      const decision = shouldIncludeUser(user, campaign);
      if (!decision.ok) {
        if (decision.reason === 'prefs') skippedPrefs += 1;
        else skippedStatus += 1;
        continue;
      }
      eligible.push(uid);
    }

    if (dryRun) {
      for (const uid of eligible) {
        const token = await resolveFcmToken(db, uid);
        if (token) inbox += 1;
        else skippedNoToken += 1;
      }
    } else if (eligible.length) {
      const withToken = [];
      const messages = [];
      for (const uid of eligible) {
        const token = await resolveFcmToken(db, uid);
        if (token) {
          withToken.push(uid);
          messages.push(buildFcmMessage(token, { ...campaign }));
        } else {
          skippedNoToken += 1;
        }
      }
      // Inbox for every eligible user (in-app), including those without a token.
      await writeInbox(db, campaign, actorUid, eligible, ts);
      inbox += eligible.length;
      const fcm = await sendFcmBatch(messaging, messages);
      delivered += fcm.success;
      failed += fcm.failure;
    }

    if (dryRun && scanned >= scanCap && nextCursor) {
      truncated = true;
      break;
    }
    if (!dryRun) break; // live sends one page per worker tick
  } while (pageCursor);

  const skipped = skippedPrefs + skippedNoToken + skippedStatus;
  return {
    scanned,
    inbox,
    delivered,
    failed,
    skipped,
    skippedPrefs,
    skippedNoToken,
    skippedStatus,
    nextCursor,
    truncated,
    ts,
  };
}

function deliveryNote(result, { dryRun, done }) {
  const parts = [];
  if (dryRun) parts.push('Dry run — no inbox docs or FCM were sent.');
  if (done && !dryRun) parts.push('Send complete.');
  if (!done && !dryRun) parts.push('Sending in batches…');
  parts.push(
    `Inbox ${result.inbox}, FCM delivered ${result.delivered}, FCM failed ${result.failed}, ` +
      `skipped prefs ${result.skippedPrefs}, no token ${result.skippedNoToken}, ineligible ${result.skippedStatus}.`,
  );
  if (result.truncated) {
    parts.push(`Dry-run scan stopped after ${result.scanned} user documents (cap ${MAX_DRY_RUN_SCAN}).`);
  }
  return parts.join(' ');
}

async function applyChunkProgress(db, campaignRef, campaign, result, { dryRun, done }) {
  const sentCount = (campaign.sentCount || 0) + result.inbox;
  const deliveredCount = (campaign.deliveredCount || 0) + result.delivered;
  const failedCount = (campaign.failedCount || 0) + result.failed;
  const skippedCount = (campaign.skippedCount || 0) + result.skipped;
  const scannedCount = (campaign.scannedCount || 0) + result.scanned;
  const recipientCount = sentCount + skippedCount;
  const patch = {
    sentCount,
    deliveredCount,
    failedCount,
    skippedCount,
    scannedCount,
    recipientCount,
    deliveryCursor: result.nextCursor,
    deliveryNote: deliveryNote(result, { dryRun, done }),
    updatedAt: result.ts,
    workerLeaseUntil: null,
  };
  if (dryRun) {
    patch.status = campaign.status || 'draft';
    patch.dryRunAt = result.ts;
    patch.dryRunRecipientCount = recipientCount;
  } else if (done) {
    patch.status = failedCount > 0 && sentCount === 0 ? 'failed' : 'sent';
    patch.sentAt = result.ts;
    patch.finishedAt = result.ts;
  } else {
    patch.status = 'sending';
    patch.workerArmed = true;
  }
  if (done || dryRun) patch.workerArmed = false;
  await campaignRef.set(patch, { merge: true });
  return patch;
}

async function processNextChunk({ db, messaging, campaignId }) {
  const ref = db.collection(CAMPAIGNS).doc(campaignId);
  const snap = await ref.get();
  if (!snap.exists) return { skipped: true };
  const campaign = { id: campaignId, ...(snap.data() || {}) };
  if (campaign.deliveryEngine !== DELIVERY_ENGINE) return { skipped: true };
  if (campaign.status !== 'sending') return { skipped: true };
  if (campaign.workerArmed !== true) return { skipped: true };

  const leaseUntil = campaign.workerLeaseUntil ? Date.parse(campaign.workerLeaseUntil) : 0;
  if (leaseUntil && leaseUntil > Date.now()) return { leased: true };

  await ref.set({
    workerLeaseUntil: new Date(Date.now() + LEASE_MS).toISOString(),
    updatedAt: new Date().toISOString(),
  }, { merge: true });

  const result = await processCampaignChunk({
    db,
    messaging,
    campaign,
    cursor: campaign.deliveryCursor || null,
    dryRun: false,
    actorUid: campaign.startedByUid || campaign.createdByUid,
  });
  const done = !result.nextCursor;
  const patch = await applyChunkProgress(db, ref, campaign, result, { dryRun: false, done });
  if (done) await clearSendingLock(db, campaignId);
  return { done, patch, result };
}

async function startCampaign({
  db,
  messaging,
  campaignId,
  actor,
  reason,
  dryRun,
}) {
  const ref = db.collection(CAMPAIGNS).doc(campaignId);
  const snap = await ref.get();
  if (!snap.exists) throw httpsError('not-found', 'Campaign not found');
  const campaign = { id: campaignId, ...(snap.data() || {}) };

  if (!String(campaign.title || '').trim() && !String(campaign.body || '').trim()) {
    throw httpsError('invalid-argument', 'Campaign needs a title or body');
  }
  const status = String(campaign.status || 'draft');
  if (!dryRun && (status === 'sending')) {
    throw httpsError('failed-precondition', 'This campaign is already sending');
  }
  if (!dryRun && status === 'sent') {
    throw httpsError('failed-precondition', 'This campaign was already sent. Duplicate it to send again.');
  }

  // Resolve one page first so unsupported audiences fail before we flip status.
  await resolveAudiencePage(db, campaign, null, 1);

  await assertRateLimits(db, { campaignId, dryRun });

  const ts = new Date().toISOString();
  if (dryRun) {
    const result = await processCampaignChunk({
      db,
      messaging: null,
      campaign,
      cursor: null,
      dryRun: true,
      actorUid: actor.uid,
    });
    const patch = await applyChunkProgress(db, ref, campaign, result, { dryRun: true, done: true });
    await writeAudit(db, {
      action: 'notificationDryRun',
      actor,
      campaign,
      reason,
      metadata: { ...result, dryRun: true },
    });
    await clearSendingLock(db, campaignId); // dry-run should not hold the lock
    // assertRateLimits incremented starts; dry-run should not count. Roll back increment? 
    // We skipped increment... wait, assertRateLimits returns early if dryRun. Good.
    return { dryRun: true, ...result, status: patch.status, deliveryNote: patch.deliveryNote };
  }

  try {
  await ref.set({
    status: 'sending',
    deliveryEngine: DELIVERY_ENGINE,
    deliveryCursor: null,
    workerArmed: false,
    sentCount: 0,
    deliveredCount: 0,
    failedCount: 0,
    skippedCount: 0,
    scannedCount: 0,
    recipientCount: 0,
    deliveryNote: 'Starting server send…',
    startedAt: ts,
    startedByUid: actor.uid,
    startedByEmail: actor.email || '',
    updatedAt: ts,
    workerLeaseUntil: new Date(Date.now() + LEASE_MS).toISOString(),
  }, { merge: true });

  await writeAudit(db, {
    action: 'notificationSendStarted',
    actor,
    campaign,
    reason,
    metadata: { audience: campaign.audience, dryRun: false },
  });

  const result = await processCampaignChunk({
    db,
    messaging,
    campaign: { ...campaign, id: campaignId },
    cursor: null,
    dryRun: false,
    actorUid: actor.uid,
  });
  const done = !result.nextCursor;
  const patch = await applyChunkProgress(db, ref, {
    ...campaign,
    sentCount: 0,
    deliveredCount: 0,
    failedCount: 0,
    skippedCount: 0,
    scannedCount: 0,
  }, result, { dryRun: false, done });
  if (done) {
    await clearSendingLock(db, campaignId);
    await writeAudit(db, {
      action: 'notificationSent',
      actor,
      campaign,
      reason,
      metadata: result,
    });
  }
  return { dryRun: false, done, ...result, status: patch.status, deliveryNote: patch.deliveryNote };
  } catch (err) {
    await clearSendingLock(db, campaignId);
    throw err;
  }
}

exports.adminSendNotificationCampaign = onCall(
  { timeoutSeconds: 300, memory: '512MiB' },
  async (request) => {
    const db = getFirestore();
    const campaignId = String(request.data?.campaignId || '').trim();
    const dryRun = request.data?.dryRun === true;
    const reason = typeof request.data?.reason === 'string'
      ? request.data.reason.trim().slice(0, 500)
      : '';
    if (!campaignId) throw httpsError('invalid-argument', 'campaignId required');
    const uid = request.auth?.uid;
    const admin = await assertCanSend(db, uid);
    const actor = {
      uid,
      email: admin.email || request.auth?.token?.email || '',
    };
    return startCampaign({
      db,
      messaging: getMessaging(),
      campaignId,
      actor,
      reason,
      dryRun,
    });
  },
);

exports.onAdminNotificationCampaignWritten = onDocumentUpdated(
  { document: 'admin_notification_campaigns/{id}', timeoutSeconds: 300, memory: '512MiB' },
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;
    if (after.deliveryEngine !== DELIVERY_ENGINE) return;
    if (after.status !== 'sending') return;
    if (after.workerArmed !== true) return;
    if (after.dryRun === true) return;
    const db = getFirestore();
    await processNextChunk({
      db,
      messaging: getMessaging(),
      campaignId: event.params.id,
    });
  },
);

exports.processScheduledNotificationCampaigns = onSchedule(
  {
    schedule: 'every 5 minutes',
    timeZone: 'Asia/Colombo',
    timeoutSeconds: 300,
    memory: '512MiB',
  },
  async () => {
    const db = getFirestore();
    const now = new Date().toISOString();
    const snap = await db.collection(CAMPAIGNS)
      .where('deliveryEngine', '==', DELIVERY_ENGINE)
      .limit(20)
      .get();
    let started = 0;
    for (const d of snap.docs) {
      const data = d.data() || {};
      if (data.status !== 'scheduled') continue;
      const at = data.scheduledAt;
      const iso = typeof at === 'string' ? at : (at && at.toDate ? at.toDate().toISOString() : '');
      if (!iso || iso > now) continue;
      try {
        await startCampaign({
          db,
          messaging: getMessaging(),
          campaignId: d.id,
          actor: {
            uid: data.createdByUid || 'scheduler',
            email: data.createdByEmail || 'scheduler',
          },
          reason: 'Scheduled send',
          dryRun: false,
        });
        started += 1;
        break; // rate limit: one scheduled start per tick
      } catch (err) {
        console.warn('processScheduledNotificationCampaigns', d.id, err.message || err);
      }
    }
    return { started };
  },
);

// Test surface.
module.exports.DELIVERY_ENGINE = DELIVERY_ENGINE;
module.exports.CHUNK_SIZE = CHUNK_SIZE;
module.exports.MAX_STARTS_PER_HOUR = MAX_STARTS_PER_HOUR;
module.exports.shouldIncludeUser = shouldIncludeUser;
module.exports.resolveAudiencePage = resolveAudiencePage;
module.exports.processCampaignChunk = processCampaignChunk;
module.exports.startCampaign = startCampaign;
module.exports.processNextChunk = processNextChunk;
module.exports.assertCanSend = assertCanSend;
module.exports.assertRateLimits = assertRateLimits;
module.exports.clearSendingLock = clearSendingLock;
module.exports.hourKey = hourKey;
