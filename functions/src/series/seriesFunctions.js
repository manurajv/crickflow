/**
 * Series / Competition Organization — privileged callables + helpers.
 * All sensitive mutations (approvals, PII, memberships, admin grants) go here.
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const {
  OwnerOpError,
  seriesOwnerUid,
  lifecycleNextStatus,
  validateOwnershipTransfer,
  validateAnnouncement,
  announcementRecipients,
} = require('./seriesOwnerOps');
const competitionOps = require('./seriesCompetitionOps');
const { updateSeriesRankings } = require('./updateSeriesRankings');
const orgTeams = require('./orgTeamLink');
const orgWalkIns = require('./orgWalkIns');
const { markDocsRead } = require('../notifications/notificationPriority');

const COLLECTIONS = {
  series: 'series',
  admins: 'series_admins',
  clubs: 'series_clubs',
  clubAdmins: 'series_club_admins',
  registrations: 'series_registrations',
  memberships: 'series_memberships',
  approvals: 'series_approvals',
  competitions: 'series_competitions',
  clubRankings: 'series_club_rankings',
  playerRankings: 'series_player_rankings',
  audit: 'series_audit_logs',
  announcements: 'announcements', // subcollection of series/{id}
  matches: 'matches',
  tournaments: 'tournaments',
  users: 'users',
};

function db() {
  return getFirestore();
}

function requireAuth(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  return request.auth.uid;
}

function nowIso() {
  return new Date().toISOString();
}

function adminDocId(seriesId, userId) {
  return `${seriesId}_${userId}`;
}

function clubAdminDocId(seriesId, clubId, userId) {
  return `${seriesId}_${clubId}_${userId}`;
}

function membershipDocId(seriesId, clubId, userId) {
  return `${seriesId}_${clubId}_${userId}`;
}

function clubRankingDocId(seriesId, clubId) {
  return `${seriesId}_${clubId}`;
}

function playerRankingDocId(seriesId, userId) {
  return `${seriesId}_${userId}`;
}

async function getSeriesOrThrow(firestore, seriesId) {
  const snap = await firestore.collection(COLLECTIONS.series).doc(seriesId).get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Series not found');
  }
  return { id: snap.id, ...snap.data() };
}

function isSuperAdmin(series, uid) {
  return series.superAdminUserId === uid ||
    (!series.superAdminUserId && series.createdBy === uid);
}

async function isSeriesAdmin(firestore, series, uid) {
  if (isSuperAdmin(series, uid)) return true;
  const snap = await firestore
    .collection(COLLECTIONS.admins)
    .doc(adminDocId(series.id, uid))
    .get();
  return snap.exists && snap.data()?.status === 'active';
}

async function isClubAdmin(firestore, seriesId, clubId, uid) {
  const snap = await firestore
    .collection(COLLECTIONS.clubAdmins)
    .doc(clubAdminDocId(seriesId, clubId, uid))
    .get();
  return snap.exists && snap.data()?.status === 'active';
}

async function requireSuperAdmin(firestore, seriesId, uid) {
  const series = await getSeriesOrThrow(firestore, seriesId);
  if (!isSuperAdmin(series, uid)) {
    throw new HttpsError('permission-denied', 'Series Super Admin required');
  }
  return series;
}

async function requireSeriesAdmin(firestore, seriesId, uid) {
  const series = await getSeriesOrThrow(firestore, seriesId);
  if (!(await isSeriesAdmin(firestore, series, uid))) {
    throw new HttpsError('permission-denied', 'Series Admin required');
  }
  return series;
}

async function writeAudit(firestore, entry) {
  const ref = firestore.collection(COLLECTIONS.audit).doc();
  await ref.set({
    ...entry,
    timestamp: entry.timestamp || nowIso(),
  });
  return ref.id;
}

function seriesApprovalRef(firestore, seriesId, approvalId) {
  return firestore
    .collection(COLLECTIONS.series)
    .doc(seriesId)
    .collection('approvals')
    .doc(approvalId);
}

/** Dual-write top-level + series/{id}/approvals (path-scoped rules for list queries). */
async function writeApprovalDocs(firestore, seriesId, approvalId, payload, { merge = false } = {}) {
  const rootRef = firestore.collection(COLLECTIONS.approvals).doc(approvalId);
  const nestedRef = seriesApprovalRef(firestore, seriesId, approvalId);
  const batch = firestore.batch();
  if (merge) {
    batch.set(rootRef, payload, { merge: true });
    batch.set(nestedRef, payload, { merge: true });
  } else {
    batch.set(rootRef, payload);
    batch.set(nestedRef, payload);
  }
  await batch.commit();
}

async function updateApprovalDocs(firestore, seriesId, approvalId, patch) {
  const rootRef = firestore.collection(COLLECTIONS.approvals).doc(approvalId);
  const nestedRef = seriesApprovalRef(firestore, seriesId, approvalId);
  const nestedSnap = await nestedRef.get();
  const batch = firestore.batch();
  batch.update(rootRef, patch);
  if (nestedSnap.exists) {
    batch.update(nestedRef, patch);
  } else {
    const rootSnap = await rootRef.get();
    if (rootSnap.exists) {
      batch.set(nestedRef, { ...rootSnap.data(), ...patch });
    }
  }
  await batch.commit();
}

async function createApproval(firestore, data) {
  const ref = firestore.collection(COLLECTIONS.approvals).doc();
  const payload = {
    ...data,
    status: 'pending',
    requestedAt: nowIso(),
    reason: data.reason || '',
    metadata: data.metadata || {},
  };
  await writeApprovalDocs(firestore, data.seriesId, ref.id, payload);

  // Notify Series Super Admin of pending work (best-effort).
  try {
    const series = await getSeriesOrThrow(firestore, data.seriesId);
    const superUid = series.superAdminUserId || series.createdBy;
    if (superUid && superUid !== data.requestedBy) {
      await firestore.collection('notifications').doc().set({
        userId: superUid,
        title: 'Series approval needed',
        body: `${data.targetType || 'Request'} pending in ${series.name || 'Series'}`,
        type: 'series_approval_pending',
        priority: true,
        seriesId: data.seriesId,
        requestId: ref.id,
        addedByUserId: data.requestedBy || 'system',
        createdAt: nowIso(),
        read: false,
      });
    }
  } catch (err) {
    console.error('series pending notify failed', err);
  }

  return { id: ref.id, ...payload };
}

/**
 * Mirror legacy top-level series_approvals into series/{id}/approvals so manager
 * list queries succeed under path-scoped rules.
 */
exports.syncSeriesApprovalMirrors = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  if (!seriesId) {
    throw new HttpsError('invalid-argument', 'seriesId required');
  }
  const firestore = db();
  await requireSeriesAdmin(firestore, seriesId, uid);

  const rootSnap = await firestore
    .collection(COLLECTIONS.approvals)
    .where('seriesId', '==', seriesId)
    .get();
  let mirrored = 0;
  const batchSize = 400;
  let batch = firestore.batch();
  let ops = 0;
  for (const docSnap of rootSnap.docs) {
    const nestedRef = seriesApprovalRef(firestore, seriesId, docSnap.id);
    batch.set(nestedRef, docSnap.data(), { merge: true });
    mirrored += 1;
    ops += 1;
    if (ops >= batchSize) {
      await batch.commit();
      batch = firestore.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();
  return { seriesId, mirrored };
});

/**
 * Create competition organization (Series / League / Company / …).
 * Creator becomes Super Admin; status active.
 */
const ALLOWED_SERIES_KINDS = new Set([
  'series',
  'league',
  'association',
  'federation',
  'club',
  'company',
  'cup',
  'other',
]);

exports.createSeries = onCall(
  {
    timeoutSeconds: 120,
    memory: '512MiB',
    cpu: 1,
    concurrency: 20,
  },
  async (request) => {
  const uid = requireAuth(request);
  const name = String(request.data?.name || '').trim();
  if (name.length < 3 || name.length > 120) {
    throw new HttpsError('invalid-argument', 'Name required (3–120 characters)');
  }
  const kind = String(request.data?.kind || 'series').toLowerCase();
  if (!ALLOWED_SERIES_KINDS.has(kind)) {
    throw new HttpsError('invalid-argument', 'Invalid type');
  }
  const description = String(request.data?.description || '').trim();
  if (description.length > 2000) {
    throw new HttpsError('invalid-argument', 'Description max 2000 characters');
  }
  const rulesText = String(request.data?.rulesText || '').trim();
  if (rulesText.length > 10000) {
    throw new HttpsError('invalid-argument', 'Rules max 10000 characters');
  }

  const firestore = db();
  const ref = firestore.collection(COLLECTIONS.series).doc();
  const ts = nowIso();
  const settings = request.data?.settings && typeof request.data.settings === 'object'
    ? request.data.settings
    : {};
  const maxSquad = Number(settings.maxSquadSize);
  if (!Number.isFinite(maxSquad) || maxSquad < 1 || maxSquad > 50) {
    throw new HttpsError('invalid-argument', 'Max players per team must be 1–50');
  }
  const ranking = settings.rankingRules && typeof settings.rankingRules === 'object'
    ? settings.rankingRules
    : {};
  const clampPoints = (v, fallback) => {
    const n = Number(v);
    if (!Number.isFinite(n) || n < 0 || n > 100) return fallback;
    return Math.floor(n);
  };
  const series = {
    name,
    description: description.slice(0, 2000),
    rulesText: rulesText.slice(0, 10000),
    kind,
    status: 'active',
    superAdminUserId: uid,
    coverImageUrl: request.data?.coverImageUrl || null,
    logoUrl: request.data?.logoUrl || null,
    region: String(request.data?.region || '').trim().slice(0, 80),
    location: String(request.data?.location || '').trim().slice(0, 80),
    country: String(request.data?.country || '').trim().slice(0, 80),
    settings: {
      maxSquadSize: Math.floor(maxSquad),
      requireFullName: settings.requireFullName !== false,
      requireCrickFlowPlayerId: settings.requireCrickFlowPlayerId !== false,
      requireDateOfBirth: !!settings.requireDateOfBirth,
      requireNationalId: !!settings.requireNationalId,
      requirePassport: !!settings.requirePassport,
      requirePhoneNumber: !!settings.requirePhoneNumber,
      requireAddress: !!settings.requireAddress,
      requireProfilePhoto: !!settings.requireProfilePhoto,
      customRequiredFields: Array.isArray(settings.customRequiredFields)
        ? settings.customRequiredFields
        : [],
      rankingRules: {
        winPoints: clampPoints(ranking.winPoints, 2),
        lossPoints: clampPoints(ranking.lossPoints, 0),
        tiePoints: clampPoints(ranking.tiePoints, 1),
        noResultPoints: clampPoints(ranking.noResultPoints, 1),
        bonusPointsEnabled: !!ranking.bonusPointsEnabled,
        useNetRunRate: ranking.useNetRunRate !== false,
        useRunDifference: !!ranking.useRunDifference,
      },
    },
    clubCount: 0,
    playerCount: 0,
    matchCount: 0,
    tournamentCount: 0,
    organizationId: request.data?.organizationId || null,
    createdBy: uid,
    createdAt: ts,
    updatedAt: ts,
  };

  const adminRef = firestore.collection(COLLECTIONS.admins).doc(adminDocId(ref.id, uid));
  const batch = firestore.batch();
  batch.set(ref, series);
  batch.set(adminRef, {
    seriesId: ref.id,
    userId: uid,
    displayName: String(request.data?.displayName || '').slice(0, 80),
    permissions: ['*'],
    status: 'active',
    role: 'superAdmin',
    createdBy: uid,
    createdAt: ts,
  });
  await batch.commit();

  await writeAudit(firestore, {
    seriesId: ref.id,
    actorUserId: uid,
    actorRole: 'superAdmin',
    action: 'SERIES_CREATED',
    targetType: 'series',
    targetId: ref.id,
    previousState: {},
    newState: { name, kind, status: 'active', country: series.country },
  });

  return { seriesId: ref.id, ...series };
});

exports.addSeriesAdmin = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const targetUserId = String(request.data?.userId || '');
  if (!seriesId || !targetUserId) {
    throw new HttpsError('invalid-argument', 'seriesId and userId required');
  }
  const firestore = db();
  const series = await requireSuperAdmin(firestore, seriesId, uid);
  const ts = nowIso();
  const ref = firestore.collection(COLLECTIONS.admins).doc(adminDocId(seriesId, targetUserId));
  await ref.set({
    seriesId,
    userId: targetUserId,
    displayName: String(request.data?.displayName || ''),
    permissions: Array.isArray(request.data?.permissions) ? request.data.permissions : [],
    status: 'active',
    role: 'seriesAdmin',
    createdBy: uid,
    createdAt: ts,
  }, { merge: true });

  await writeAudit(firestore, {
    seriesId,
    actorUserId: uid,
    actorRole: 'superAdmin',
    action: 'SERIES_ADMIN_ADDED',
    targetType: 'series_admin',
    targetId: targetUserId,
    previousState: {},
    newState: { status: 'active' },
  });

  return { ok: true, adminId: ref.id, seriesName: series.name };
});

exports.removeSeriesAdmin = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const targetUserId = String(request.data?.userId || '');
  if (!seriesId || !targetUserId) {
    throw new HttpsError('invalid-argument', 'seriesId and userId required');
  }
  if (targetUserId === uid) {
    throw new HttpsError('failed-precondition', 'Cannot remove yourself');
  }
  const firestore = db();
  const series = await requireSuperAdmin(firestore, seriesId, uid);
  if (series.superAdminUserId === targetUserId) {
    throw new HttpsError('failed-precondition', 'Cannot remove Super Admin');
  }
  const ref = firestore.collection(COLLECTIONS.admins).doc(adminDocId(seriesId, targetUserId));
  await ref.set({ status: 'removed', updatedAt: nowIso() }, { merge: true });
  await writeAudit(firestore, {
    seriesId,
    actorUserId: uid,
    actorRole: 'superAdmin',
    action: 'SERIES_ADMIN_REMOVED',
    targetType: 'series_admin',
    targetId: targetUserId,
    previousState: { status: 'active' },
    newState: { status: 'removed' },
  });
  return { ok: true };
});

exports.updateSeriesSettings = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const settings = request.data?.settings;
  if (!seriesId || !settings || typeof settings !== 'object') {
    throw new HttpsError('invalid-argument', 'seriesId and settings required');
  }
  const maxSquad = Number(settings.maxSquadSize);
  if (!Number.isFinite(maxSquad) || maxSquad < 1 || maxSquad > 50) {
    throw new HttpsError('invalid-argument', 'Max players per team must be 1–50');
  }
  const firestore = db();
  const series = await requireSuperAdmin(firestore, seriesId, uid);
  const sanitized = {
    ...settings,
    maxSquadSize: Math.floor(maxSquad),
  };
  await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
    settings: sanitized,
    updatedAt: nowIso(),
  });
  await writeAudit(firestore, {
    seriesId,
    actorUserId: uid,
    actorRole: 'superAdmin',
    action: 'RANKING_SETTINGS_CHANGED',
    targetType: 'series',
    targetId: seriesId,
    previousState: { settings: series.settings || {} },
    newState: { settings: sanitized },
  });
  return { ok: true };
});

async function ensureClubRankingRow(firestore, seriesId, clubId, clubName, ts) {
  await firestore.collection(COLLECTIONS.clubRankings)
    .doc(clubRankingDocId(seriesId, clubId))
    .set({
      seriesId,
      clubId,
      clubName: clubName || '',
      played: 0,
      won: 0,
      lost: 0,
      tied: 0,
      noResult: 0,
      points: 0,
      netRunRate: 0,
      runDifference: 0,
      bonusPoints: 0,
      updatedAt: ts,
    }, { merge: true });
}

/** Activate a club immediately (no pending approval). */
async function activateClub(firestore, { seriesId, clubId, clubName, ts }) {
  const clubRef = firestore.collection(COLLECTIONS.clubs).doc(clubId);
  await clubRef.update({
    status: 'approved',
    updatedAt: ts,
  });
  await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
    clubCount: FieldValue.increment(1),
    updatedAt: ts,
  });
  const caSnap = await firestore.collection(COLLECTIONS.clubAdmins)
    .where('seriesId', '==', seriesId)
    .where('clubId', '==', clubId)
    .get();
  const batch = firestore.batch();
  caSnap.docs.forEach((d) => {
    if (d.data().status === 'pending') {
      batch.update(d.ref, { status: 'active', updatedAt: ts });
    }
  });
  await batch.commit();
  await ensureClubRankingRow(firestore, seriesId, clubId, clubName, ts);
}

exports.createSeriesClub = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const name = String(request.data?.name || '').trim();
  if (!seriesId || !name) {
    throw new HttpsError('invalid-argument', 'seriesId and name required');
  }
  const firestore = db();
  const series = await getSeriesOrThrow(firestore, seriesId);
  const manager = await isSeriesAdmin(firestore, series, uid);
  const asSuper = isSuperAdmin(series, uid);
  const ts = nowIso();
  const ref = firestore.collection(COLLECTIONS.clubs).doc();
  // Every org team is a real CrickFlow team. The app creates it with the
  // normal team flow and passes linkedTeamId; web / older apps don't, so the
  // server creates one owned by the caller.
  const linkedTeamId = request.data?.linkedTeamId ? String(request.data.linkedTeamId) : null;
  if (linkedTeamId) {
    const tSnap = await firestore.collection('teams').doc(linkedTeamId).get();
    const team = tSnap.exists ? tSnap.data() : null;
    try {
      orgTeams.validateLinkTarget({
        team, uid, lockClub: await orgTeams.readLockClub(firestore, team),
      });
    } catch (err) {
      throw new HttpsError(err.code || 'failed-precondition', err.message);
    }
  }
  const lock = orgTeams.buildLock({ seriesId, clubId: ref.id, seriesName: series.name, ts });
  const teamId = linkedTeamId || await orgTeams.createTeamForClub(firestore, {
    name, createdBy: uid, lock, ts,
  });
  if (linkedTeamId) await orgTeams.lockTeam(firestore, linkedTeamId, lock);
  const club = {
    seriesId,
    name: name.slice(0, 120),
    description: String(request.data?.description || '').slice(0, 2000),
    logoUrl: request.data?.logoUrl || null,
    linkedTeamId: teamId,
    status: manager ? 'approved' : 'pending',
    createdBy: uid,
    squadCount: 0,
    createdAt: ts,
    updatedAt: ts,
  };
  await ref.set(club);

  // Creator is club admin — active immediately when a Series manager creates the club.
  await firestore.collection(COLLECTIONS.clubAdmins).doc(
    clubAdminDocId(seriesId, ref.id, uid),
  ).set({
    seriesId,
    clubId: ref.id,
    userId: uid,
    displayName: String(request.data?.displayName || ''),
    status: manager ? 'active' : 'pending',
    createdBy: uid,
    createdAt: ts,
  });

  let approvalId = null;
  if (manager) {
    await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
      clubCount: FieldValue.increment(1),
      updatedAt: ts,
    });
    await ensureClubRankingRow(firestore, seriesId, ref.id, name, ts);
  } else {
    const approval = await createApproval(firestore, {
      seriesId,
      clubId: ref.id,
      targetType: 'clubRegistration',
      targetId: ref.id,
      requestedBy: uid,
      metadata: { clubName: name },
    });
    approvalId = approval.id;
  }

  await writeAudit(firestore, {
    seriesId,
    clubId: ref.id,
    actorUserId: uid,
    actorRole: asSuper ? 'superAdmin' : (manager ? 'seriesAdmin' : 'clubAdmin'),
    action: manager ? 'CLUB_CREATED_APPROVED' : 'CLUB_CREATED',
    targetType: 'club',
    targetId: ref.id,
    previousState: {},
    newState: { status: club.status, name },
  });

  return {
    clubId: ref.id,
    approvalId,
    status: club.status,
    autoApproved: manager,
    ...club,
  };
});

/** Best effort: keep the linked CrickFlow team roster in step with the org. */
async function mirrorRoster(firestore, kind, args) {
  try {
    if (kind === 'add') await orgTeams.addMemberToLinkedTeam(firestore, args);
    else await orgTeams.removeMemberFromLinkedTeam(firestore, args);
  } catch (err) {
    console.warn(`org team roster ${kind} failed`, err.message);
  }
}

async function activateMembership(firestore, {
  seriesId, clubId, userId, playerDocId, registrationId, displayName,
}) {
  const mid = membershipDocId(seriesId, clubId, userId);
  const ref = firestore.collection(COLLECTIONS.memberships).doc(mid);
  const existing = await ref.get();
  const alreadyActive =
    existing.exists && existing.data()?.status === 'active';

  await ref.set({
    seriesId,
    clubId,
    userId,
    playerDocId: playerDocId || null,
    registrationId: registrationId || null,
    displayName: displayName || existing.data()?.displayName || '',
    status: 'active',
    joinedAt: alreadyActive
      ? (existing.data()?.joinedAt || nowIso())
      : nowIso(),
  }, { merge: true });

  await mirrorRoster(firestore, 'add', {
    clubId, userId, playerDocId: playerDocId || existing.data()?.playerDocId,
  });
  if (alreadyActive) return mid;

  const clubRef = firestore.collection(COLLECTIONS.clubs).doc(clubId);
  await clubRef.update({
    squadCount: FieldValue.increment(1),
    updatedAt: nowIso(),
  });
  await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
    playerCount: FieldValue.increment(1),
    updatedAt: nowIso(),
  });
  return mid;
}

async function enforceSquadMax(firestore, series, clubId) {
  const max = Number(series.settings?.maxSquadSize) || 20;
  const clubSnap = await firestore.collection(COLLECTIONS.clubs).doc(clubId).get();
  const squadCount = clubSnap.data()?.squadCount || 0;
  if (squadCount >= max) {
    throw new HttpsError(
      'failed-precondition',
      `Squad is full (max ${max})`,
    );
  }
}

exports.reviewSeriesApproval = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const approvalId = String(request.data?.approvalId || '');
  const decision = String(request.data?.decision || '').toLowerCase();
  // New clients require a reason in the UI; older builds send none.
  const reason = String(request.data?.reason || '').trim().slice(0, 500) ||
    (String(request.data?.decision || '').toLowerCase() === 'rejected' ? 'No reason given' : '');
  if (!seriesId || !approvalId || !['approved', 'rejected'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'Invalid review payload');
  }

  const firestore = db();
  // Series Admins may review operational approvals; Super Admin always can.
  // Ownership / settings / admin grants remain Super-Admin-only elsewhere.
  const series = await requireSeriesAdmin(firestore, seriesId, uid);
  const actorRole = isSuperAdmin(series, uid) ? 'superAdmin' : 'seriesAdmin';
  const approvalRef = firestore.collection(COLLECTIONS.approvals).doc(approvalId);
  const approvalSnap = await approvalRef.get();
  if (!approvalSnap.exists) {
    throw new HttpsError('not-found', 'Approval not found');
  }
  const approval = approvalSnap.data();
  if (approval.seriesId !== seriesId) {
    throw new HttpsError('permission-denied', 'Approval series mismatch');
  }
  if (approval.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'Approval already reviewed');
  }
  if (decision === 'approved' && approval.targetType === 'match') {
    const compSnap = await firestore.collection(COLLECTIONS.competitions).doc(approval.targetId).get();
    const mid = compSnap.data()?.matchId;
    const mSnap = mid ? await firestore.collection(COLLECTIONS.matches).doc(mid).get() : null;
    if (mSnap && competitionOps.isQuickMatch(mSnap.data())) {
      throw new HttpsError(
        'failed-precondition',
        'Quick matches are not allowed in orgs. Reject this request instead.',
      );
    }
  }

  const ts = nowIso();
  await updateApprovalDocs(firestore, seriesId, approvalId, {
    status: decision,
    reviewedBy: uid,
    reviewedAt: ts,
    reason,
  });

  // Every admin's "approval needed" notification for this request is done.
  try {
    const pend = await firestore.collection('notifications')
      .where('requestId', '==', approvalId)
      .where('type', '==', 'series_approval_pending')
      .get();
    await markDocsRead(firestore, pend.docs);
  } catch (err) {
    console.warn('approval notifications read failed', err.message);
  }

  const targetType = approval.targetType;
  const targetId = approval.targetId;
  let auditAction = decision === 'approved' ? 'APPROVAL_APPROVED' : 'APPROVAL_REJECTED';

  if (targetType === 'clubRegistration') {
    const clubRef = firestore.collection(COLLECTIONS.clubs).doc(targetId);
    if (decision === 'approved') {
      const club = (await clubRef.get()).data() || {};
      await activateClub(firestore, {
        seriesId,
        clubId: targetId,
        clubName: club.name || '',
        ts,
      });
    } else {
      await clubRef.update({
        status: 'rejected',
        updatedAt: ts,
      });
      // The CrickFlow team stays; it just becomes a normal, editable team again.
      const linked = (await clubRef.get()).data()?.linkedTeamId;
      await orgTeams.unlockTeamForClub(firestore, linked, targetId);
    }
    auditAction = decision === 'approved' ? 'CLUB_APPROVED' : 'CLUB_REJECTED';
  }

  if (['playerJoin', 'playerAdd', 'playerRegistration'].includes(targetType)) {
    if (targetType === 'playerJoin' && decision === 'approved') {
      const clubReview = approval.metadata?.clubReviewStatus;
      // Club Admin must clear join first, unless Super Admin overrides.
      if (clubReview !== 'approved' && !isSuperAdmin(series, uid)) {
        throw new HttpsError(
          'failed-precondition',
          'Team admin must approve this join before Series approval',
        );
      }
    }
    if (decision === 'approved') {
      const clubId = approval.clubId || approval.metadata?.clubId;
      if (!clubId) {
        throw new HttpsError('failed-precondition', 'Missing clubId on approval');
      }
      await enforceSquadMax(firestore, series, clubId);
      const userId = approval.metadata?.userId || approval.requestedBy;
      await activateMembership(firestore, {
        seriesId,
        clubId,
        userId,
        playerDocId: approval.metadata?.playerDocId,
        registrationId: approval.metadata?.registrationId || targetId,
        displayName: approval.metadata?.displayName || '',
      });
      if (approval.metadata?.registrationId || targetType === 'playerRegistration') {
        const regId = approval.metadata?.registrationId || targetId;
        await firestore.collection(COLLECTIONS.registrations).doc(regId).update({
          status: 'approved',
          updatedAt: ts,
        });
      }
      auditAction = 'PLAYER_APPROVED';
    } else {
      if (approval.metadata?.registrationId || targetType === 'playerRegistration') {
        const regId = approval.metadata?.registrationId || targetId;
        await firestore.collection(COLLECTIONS.registrations).doc(regId).update({
          status: 'rejected',
          updatedAt: ts,
        });
      }
      auditAction = 'PLAYER_REJECTED';
    }
  }

  if (targetType === 'playerRemoval') {
    if (decision === 'approved') {
      const clubId = approval.clubId;
      const userId = approval.metadata?.userId;
      if (clubId && userId) {
        const mid = membershipDocId(seriesId, clubId, userId);
        const prev = (await firestore.collection(COLLECTIONS.memberships).doc(mid).get()).data() || {};
        await firestore.collection(COLLECTIONS.memberships).doc(mid).update({
          status: 'removed',
          leftAt: ts,
        });
        await mirrorRoster(firestore, 'remove', { clubId, userId, playerDocId: prev.playerDocId });
        await firestore.collection(COLLECTIONS.clubs).doc(clubId).update({
          squadCount: FieldValue.increment(-1),
          updatedAt: ts,
        });
        await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
          playerCount: FieldValue.increment(-1),
          updatedAt: ts,
        });
      }
      auditAction = 'PLAYER_REMOVED';
    }
  }

  if (targetType === 'match') {
    const compRef = firestore.collection(COLLECTIONS.competitions).doc(targetId);
    const compSnap = await compRef.get();
    if (compSnap.exists) {
      await compRef.update({
        status: decision === 'approved' ? 'approved' : 'rejected',
        approvedAt: decision === 'approved' ? ts : null,
        approvedBy: decision === 'approved' ? uid : null,
        updatedAt: ts,
      });
      const matchId = compSnap.data().matchId;
      if (matchId) {
        await firestore.collection(COLLECTIONS.matches).doc(matchId).set({
          seriesOfficialStatus: decision === 'approved' ? 'approved' : 'rejected',
          seriesId,
          seriesCompetitionId: targetId,
          updatedAt: ts,
        }, { merge: true });
        await applyMatchDecision(firestore, { seriesId, matchId, decision, ts });
      }
    }
    auditAction = decision === 'approved' ? 'MATCH_APPROVED' : 'MATCH_REJECTED';
  }

  if (targetType === 'tournament') {
    const compRef = firestore.collection(COLLECTIONS.competitions).doc(targetId);
    const compSnap = await compRef.get();
    if (compSnap.exists) {
      await compRef.update({
        status: decision === 'approved' ? 'approved' : 'rejected',
        approvedAt: decision === 'approved' ? ts : null,
        approvedBy: decision === 'approved' ? uid : null,
        updatedAt: ts,
      });
      const tournamentId = compSnap.data().tournamentId;
      if (tournamentId) {
        await firestore.collection(COLLECTIONS.tournaments).doc(tournamentId).set({
          seriesOfficialStatus: decision === 'approved' ? 'approved' : 'rejected',
          seriesId,
          seriesCompetitionId: targetId,
          updatedAt: ts,
        }, { merge: true });
        await applyTournamentDecision(firestore, {
          seriesId, compId: targetId, tournamentId, decision, ts,
        });
      }
      if (decision === 'approved') {
        await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
          tournamentCount: FieldValue.increment(1),
          updatedAt: ts,
        });
      }
    }
    auditAction = decision === 'approved' ? 'TOURNAMENT_APPROVED' : 'TOURNAMENT_REJECTED';
  }

  await writeAudit(firestore, {
    seriesId,
    clubId: approval.clubId || null,
    actorUserId: uid,
    actorRole,
    action: auditAction,
    targetType,
    targetId,
    previousState: { status: 'pending' },
    newState: { status: decision },
    reason,
  });

  // Notify requester of decision (in-app + FCM via onNotificationCreated).
  try {
    if (approval.requestedBy && approval.requestedBy !== uid) {
      const notifRef = firestore.collection('notifications').doc();
      await notifRef.set({
        userId: approval.requestedBy,
        title: decision === 'approved' ? 'Series request approved' : 'Series request rejected',
        body: `${({ match: 'Match request', tournament: 'Tournament request' })[targetType] || targetType} ${decision}${reason ? `: ${reason}` : ''}`,
        type: decision === 'approved'
          ? 'series_approval_approved'
          : 'series_approval_rejected',
        seriesId,
        requestId: approvalId,
        addedByUserId: uid,
        createdAt: ts,
        read: false,
      });
    }
  } catch (err) {
    console.error('series approval notify failed', err);
  }

  return { ok: true, status: decision };
});

function validateRegistrationFields(settings, data) {
  const missing = [];
  if (settings.requireFullName !== false && !String(data.fullName || '').trim()) {
    missing.push('fullName');
  }
  if (settings.requireCrickFlowPlayerId && !String(data.crickFlowPlayerId || '').trim()) {
    missing.push('crickFlowPlayerId');
  }
  if (settings.requireDateOfBirth && !data.dateOfBirth) missing.push('dateOfBirth');
  if (settings.requirePhoneNumber && !String(data.phoneNumber || '').trim()) {
    missing.push('phoneNumber');
  }
  if (settings.requireAddress && !String(data.address || '').trim()) {
    missing.push('address');
  }
  if (settings.requireProfilePhoto && !data.profilePhotoUrl) {
    missing.push('profilePhotoUrl');
  }
  if (settings.requireNationalId && !String(data.nationalId || '').trim()) {
    missing.push('nationalId');
  }
  if (settings.requirePassport && !String(data.passportNumber || '').trim()) {
    missing.push('passportNumber');
  }
  if (missing.length) {
    throw new HttpsError(
      'invalid-argument',
      `Missing required registration fields: ${missing.join(', ')}`,
    );
  }
}

function registrationPayloadFromRequest(data, {
  seriesId,
  userId,
  createdBy,
  ts,
  status = 'pending',
}) {
  const nationalId = String(data?.nationalId || '').trim();
  const passportNumber = String(data?.passportNumber || '').trim();
  const nationalIdDocUrl = String(data?.nationalIdDocUrl || '').trim() || null;
  const passportDocUrl = String(data?.passportDocUrl || '').trim() || null;
  const hasSensitive = !!(nationalId || passportNumber || nationalIdDocUrl || passportDocUrl);

  const publicDoc = {
    seriesId,
    clubId: data?.clubId || null,
    userId,
    playerDocId: data?.playerDocId || userId || null,
    crickFlowPlayerId: data?.crickFlowPlayerId || null,
    fullName: String(data?.fullName || data?.displayName || '').slice(0, 120),
    phoneNumber: String(data?.phoneNumber || '').slice(0, 32),
    profilePhotoUrl: data?.profilePhotoUrl || null,
    dateOfBirth: data?.dateOfBirth || null,
    address: String(data?.address || '').slice(0, 500),
    customFields: data?.customFields && typeof data.customFields === 'object'
      ? data.customFields
      : {},
    hasSensitiveIdentity: hasSensitive,
    status,
    createdBy: createdBy || userId,
    createdAt: ts,
    updatedAt: ts,
  };

  const privateDoc = hasSensitive
    ? {
        nationalId: nationalId || null,
        passportNumber: passportNumber || null,
        nationalIdDocUrl,
        passportDocUrl,
        updatedAt: ts,
        updatedBy: createdBy || userId,
      }
    : null;

  return { publicDoc, privateDoc, hasSensitive };
}

async function writeRegistration(firestore, {
  seriesId,
  userId,
  createdBy,
  data,
  status = 'pending',
}) {
  const ts = nowIso();
  const ref = firestore.collection(COLLECTIONS.registrations).doc();
  const { publicDoc, privateDoc } = registrationPayloadFromRequest(data, {
    seriesId,
    userId,
    createdBy,
    ts,
    status,
  });
  await ref.set(publicDoc);
  if (privateDoc) {
    await ref.collection('private').doc('identity').set(privateDoc);
  }
  return { id: ref.id, ...publicDoc };
}

exports.submitSeriesRegistration = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  if (!seriesId) throw new HttpsError('invalid-argument', 'seriesId required');
  const firestore = db();
  const series = await getSeriesOrThrow(firestore, seriesId);
  const settings = series.settings || {};
  validateRegistrationFields(settings, request.data || {});

  const registration = await writeRegistration(firestore, {
    seriesId,
    userId: uid,
    createdBy: uid,
    data: { ...request.data, clubId: request.data?.clubId || null },
    status: 'pending',
  });

  const approval = await createApproval(firestore, {
    seriesId,
    clubId: request.data?.clubId || null,
    targetType: 'playerRegistration',
    targetId: registration.id,
    requestedBy: uid,
    metadata: {
      registrationId: registration.id,
      userId: uid,
      displayName: registration.fullName,
      playerDocId: registration.playerDocId,
    },
  });

  return { registrationId: registration.id, approvalId: approval.id, status: 'pending' };
});

exports.submitPlayerJoinRequest = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const clubId = String(request.data?.clubId || '');
  if (!seriesId || !clubId) {
    throw new HttpsError('invalid-argument', 'seriesId and clubId required');
  }
  const firestore = db();
  await getSeriesOrThrow(firestore, seriesId);
  const clubSnap = await firestore.collection(COLLECTIONS.clubs).doc(clubId).get();
  if (!clubSnap.exists || clubSnap.data().seriesId !== seriesId) {
    throw new HttpsError('not-found', 'Team not found');
  }
  if (clubSnap.data().status !== 'approved') {
    throw new HttpsError('failed-precondition', 'Team is not approved');
  }

  const approval = await createApproval(firestore, {
    seriesId,
    clubId,
    targetType: 'playerJoin',
    targetId: `${clubId}_${uid}`,
    requestedBy: uid,
    metadata: {
      userId: uid,
      displayName: String(request.data?.displayName || ''),
      registrationId: request.data?.registrationId || null,
      playerDocId: request.data?.playerDocId || null,
      clubReviewStatus: 'pending',
    },
  });
  return { approvalId: approval.id, status: 'pending', clubReviewStatus: 'pending' };
});

/**
 * Club Admin first-pass review for player join requests.
 * Final membership still requires Series Admin / Super Admin approval.
 */
exports.reviewClubJoinRequest = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const approvalId = String(request.data?.approvalId || '');
  const decision = String(request.data?.decision || '').toLowerCase();
  const reason = String(request.data?.reason || '');
  if (!seriesId || !approvalId || !['approved', 'rejected'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'Invalid club review payload');
  }
  const firestore = db();
  const approvalRef = firestore.collection(COLLECTIONS.approvals).doc(approvalId);
  const snap = await approvalRef.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Approval not found');
  const approval = snap.data();
  if (approval.seriesId !== seriesId || approval.targetType !== 'playerJoin') {
    throw new HttpsError('failed-precondition', 'Not a player join request');
  }
  if (approval.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'Already finalized');
  }
  const clubId = approval.clubId;
  if (!clubId || !(await isClubAdmin(firestore, seriesId, clubId, uid))) {
    throw new HttpsError('permission-denied', 'Team admin required');
  }
  const ts = nowIso();
  if (decision === 'rejected') {
    await updateApprovalDocs(firestore, seriesId, approvalId, {
      status: 'rejected',
      reviewedBy: uid,
      reviewedAt: ts,
      reason,
      metadata: {
        ...(approval.metadata || {}),
        clubReviewStatus: 'rejected',
        clubReviewedBy: uid,
        clubReviewedAt: ts,
      },
    });
    await writeAudit(firestore, {
      seriesId,
      clubId,
      actorUserId: uid,
      actorRole: 'clubAdmin',
      action: 'PLAYER_JOIN_CLUB_REJECTED',
      targetType: 'playerJoin',
      targetId: approval.targetId,
      reason,
      previousState: { clubReviewStatus: 'pending' },
      newState: { clubReviewStatus: 'rejected', status: 'rejected' },
    });
    return { ok: true, status: 'rejected' };
  }

  await updateApprovalDocs(firestore, seriesId, approvalId, {
    metadata: {
      ...(approval.metadata || {}),
      clubReviewStatus: 'approved',
      clubReviewedBy: uid,
      clubReviewedAt: ts,
    },
  });
  await writeAudit(firestore, {
    seriesId,
    clubId,
    actorUserId: uid,
    actorRole: 'clubAdmin',
    action: 'PLAYER_JOIN_CLUB_APPROVED',
    targetType: 'playerJoin',
    targetId: approval.targetId,
    reason,
    previousState: { clubReviewStatus: 'pending' },
    newState: { clubReviewStatus: 'approved' },
  });
  return { ok: true, clubReviewStatus: 'approved' };
});

exports.addSeriesClubAdmin = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const clubId = String(request.data?.clubId || '');
  const targetUserId = String(request.data?.userId || '');
  if (!seriesId || !clubId || !targetUserId) {
    throw new HttpsError('invalid-argument', 'seriesId, clubId, userId required');
  }
  const firestore = db();
  const series = await getSeriesOrThrow(firestore, seriesId);
  const asSeries = await isSeriesAdmin(firestore, series, uid);
  const asClub = await isClubAdmin(firestore, seriesId, clubId, uid);
  if (!asSeries && !asClub) {
    throw new HttpsError('permission-denied', 'Team admin or org admin required');
  }
  const clubSnap = await firestore.collection(COLLECTIONS.clubs).doc(clubId).get();
  if (!clubSnap.exists || clubSnap.data().seriesId !== seriesId) {
    throw new HttpsError('not-found', 'Team not found');
  }
  const ts = nowIso();
  const status = clubSnap.data().status === 'approved' ? 'active' : 'pending';
  const ref = firestore.collection(COLLECTIONS.clubAdmins).doc(
    clubAdminDocId(seriesId, clubId, targetUserId),
  );
  await ref.set({
    seriesId,
    clubId,
    userId: targetUserId,
    displayName: String(request.data?.displayName || ''),
    status,
    createdBy: uid,
    createdAt: ts,
  }, { merge: true });
  await writeAudit(firestore, {
    seriesId,
    clubId,
    actorUserId: uid,
    actorRole: asSeries ? (isSuperAdmin(series, uid) ? 'superAdmin' : 'seriesAdmin') : 'clubAdmin',
    action: 'CLUB_ADMIN_ADDED',
    targetType: 'club_admin',
    targetId: targetUserId,
    previousState: {},
    newState: { status },
  });
  return { ok: true, clubAdminId: ref.id, status };
});

exports.removeSeriesClubAdmin = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const clubId = String(request.data?.clubId || '');
  const targetUserId = String(request.data?.userId || '');
  if (!seriesId || !clubId || !targetUserId) {
    throw new HttpsError('invalid-argument', 'seriesId, clubId, userId required');
  }
  if (targetUserId === uid) {
    throw new HttpsError('failed-precondition', 'Cannot remove yourself');
  }
  const firestore = db();
  const series = await requireSeriesAdmin(firestore, seriesId, uid);
  const ref = firestore.collection(COLLECTIONS.clubAdmins).doc(
    clubAdminDocId(seriesId, clubId, targetUserId),
  );
  await ref.set({ status: 'removed', updatedAt: nowIso() }, { merge: true });
  await writeAudit(firestore, {
    seriesId,
    clubId,
    actorUserId: uid,
    actorRole: isSuperAdmin(series, uid) ? 'superAdmin' : 'seriesAdmin',
    action: 'CLUB_ADMIN_REMOVED',
    targetType: 'club_admin',
    targetId: targetUserId,
    previousState: { status: 'active' },
    newState: { status: 'removed' },
  });
  return { ok: true };
});

exports.submitPlayerAddRequest = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const clubId = String(request.data?.clubId || '');
  const targetUserId = String(request.data?.userId || '');
  if (!seriesId || !clubId || !targetUserId) {
    throw new HttpsError('invalid-argument', 'seriesId, clubId, userId required');
  }
  const firestore = db();
  const series = await getSeriesOrThrow(firestore, seriesId);
  const asSeriesAdmin = await isSeriesAdmin(firestore, series, uid);
  const asClubAdmin = await isClubAdmin(firestore, seriesId, clubId, uid);
  if (!asSeriesAdmin && !asClubAdmin) {
    throw new HttpsError('permission-denied', 'Team admin required');
  }

  const clubSnap = await firestore.collection(COLLECTIONS.clubs).doc(clubId).get();
  if (!clubSnap.exists || clubSnap.data().seriesId !== seriesId) {
    throw new HttpsError('not-found', 'Team not found');
  }
  if (clubSnap.data().status !== 'approved') {
    throw new HttpsError('failed-precondition', 'Team must be approved before adding players');
  }

  const settings = series.settings || {};
  const displayName = String(
    request.data?.fullName || request.data?.displayName || '',
  ).trim();
  const regInput = {
    ...request.data,
    clubId,
    fullName: displayName,
    displayName,
    playerDocId: request.data?.playerDocId || targetUserId,
  };
  validateRegistrationFields(settings, regInput);

  let registrationId = String(request.data?.registrationId || '').trim() || null;
  if (!registrationId) {
    const registration = await writeRegistration(firestore, {
      seriesId,
      userId: targetUserId,
      createdBy: uid,
      data: regInput,
      status: asSeriesAdmin ? 'approved' : 'pending',
    });
    registrationId = registration.id;
  }

  // Series Super Admin / Series Admin can add players immediately — no approval queue.
  if (asSeriesAdmin) {
    await enforceSquadMax(firestore, series, clubId);
    const membershipId = await activateMembership(firestore, {
      seriesId,
      clubId,
      userId: targetUserId,
      playerDocId: request.data?.playerDocId || targetUserId,
      registrationId,
      displayName,
    });
    if (registrationId) {
      await firestore.collection(COLLECTIONS.registrations).doc(registrationId).set({
        status: 'approved',
        updatedAt: nowIso(),
      }, { merge: true });
    }
    await writeAudit(firestore, {
      seriesId,
      clubId,
      actorUserId: uid,
      actorRole: isSuperAdmin(series, uid) ? 'superAdmin' : 'seriesAdmin',
      action: 'PLAYER_ADDED_DIRECT',
      targetType: 'membership',
      targetId: membershipId,
      previousState: {},
      newState: { userId: targetUserId, status: 'active', registrationId },
    });
    return {
      status: 'active',
      autoApproved: true,
      membershipId,
      registrationId,
    };
  }

  const approval = await createApproval(firestore, {
    seriesId,
    clubId,
    targetType: 'playerAdd',
    targetId: `${clubId}_${targetUserId}`,
    requestedBy: uid,
    metadata: {
      userId: targetUserId,
      displayName,
      registrationId,
      playerDocId: request.data?.playerDocId || targetUserId,
    },
  });
  return {
    approvalId: approval.id,
    status: 'pending',
    autoApproved: false,
    registrationId,
  };
});

exports.submitPlayerRemovalRequest = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const clubId = String(request.data?.clubId || '');
  const targetUserId = String(request.data?.userId || uid);
  const reason = String(request.data?.reason || '');
  if (!seriesId || !clubId) {
    throw new HttpsError('invalid-argument', 'seriesId and clubId required');
  }
  const firestore = db();
  const series = await getSeriesOrThrow(firestore, seriesId);

  // Super Admin can remove directly.
  if (isSuperAdmin(series, uid) && request.data?.direct === true) {
    const mid = membershipDocId(seriesId, clubId, targetUserId);
    const prev = (await firestore.collection(COLLECTIONS.memberships).doc(mid).get()).data() || {};
    await firestore.collection(COLLECTIONS.memberships).doc(mid).update({
      status: 'removed',
      leftAt: nowIso(),
    });
    await mirrorRoster(firestore, 'remove', {
      clubId, userId: targetUserId, playerDocId: prev.playerDocId,
    });
    await firestore.collection(COLLECTIONS.clubs).doc(clubId).update({
      squadCount: FieldValue.increment(-1),
      updatedAt: nowIso(),
    });
    await writeAudit(firestore, {
      seriesId,
      clubId,
      actorUserId: uid,
      actorRole: 'superAdmin',
      action: 'PLAYER_REMOVED',
      targetType: 'membership',
      targetId: mid,
      reason,
      previousState: { status: 'active' },
      newState: { status: 'removed' },
    });
    return { ok: true, direct: true };
  }

  const asClubAdmin = await isClubAdmin(firestore, seriesId, clubId, uid);
  const isSelf = targetUserId === uid;
  if (!asClubAdmin && !isSelf && !(await isSeriesAdmin(firestore, series, uid))) {
    throw new HttpsError('permission-denied', 'Not allowed');
  }

  const approval = await createApproval(firestore, {
    seriesId,
    clubId,
    targetType: 'playerRemoval',
    targetId: `${clubId}_${targetUserId}`,
    requestedBy: uid,
    reason,
    metadata: { userId: targetUserId },
  });
  return { approvalId: approval.id, status: 'pending' };
});

exports.proposeSeriesMatch = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const clubAId = String(request.data?.clubAId || '');
  const clubBId = String(request.data?.clubBId || '');
  const title = String(request.data?.title || '').trim();
  if (!seriesId || !clubAId || !clubBId) {
    throw new HttpsError('invalid-argument', 'seriesId, clubAId, clubBId required');
  }
  const firestore = db();
  const series = await getSeriesOrThrow(firestore, seriesId);
  const asAdmin = await isSeriesAdmin(firestore, series, uid);
  // Same rules as startSeriesMatch: players need the org's
  // "members can request" permission and must be on one of the two teams.
  const roles = asAdmin
    ? { adminClubIds: [], memberClubIds: [] }
    : await callerTeamRoles(firestore, seriesId, uid);
  const involved = (ids) => ids.includes(clubAId) || ids.includes(clubBId);
  let access;
  try {
    access = competitionOps.decideAccess({
      kind: 'match',
      isAdmin: asAdmin,
      isOwner: isSuperAdmin(series, uid),
      isTeamAdmin: involved(roles.adminClubIds),
      isMember: involved(roles.memberClubIds),
      policy: competitionOps.resolvePolicy(series),
      orgOpen: competitionOps.isOrgOpen(series),
    });
  } catch (err) {
    throw competitionHttpsError(err);
  }

  const ts = nowIso();
  const autoApprove = access.autoApprove;
  const officialStatus = autoApprove ? 'approved' : 'pendingApproval';
  const compRef = firestore.collection(COLLECTIONS.competitions).doc();
  let matchId = request.data?.matchId || null;
  if (matchId) {
    const existing = await firestore.collection(COLLECTIONS.matches).doc(String(matchId)).get();
    if (competitionOps.isQuickMatch(existing.data())) {
      throw new HttpsError('failed-precondition', 'Quick matches are not allowed in orgs. Start a normal match instead.');
    }
    if (existing.exists) {
      await assertWalkInsAllowed(firestore, series, existing.data());
    }
  }

  const clubASnap = await firestore.collection(COLLECTIONS.clubs).doc(clubAId).get();
  const clubBSnap = await firestore.collection(COLLECTIONS.clubs).doc(clubBId).get();
  const clubAName = clubASnap.data()?.name || 'Club A';
  const clubBName = clubBSnap.data()?.name || 'Club B';
  const matchTitle = title || `${clubAName} vs ${clubBName}`;

  // Optionally create a draft CrickFlow match linked to this Series competition.
  if (!matchId && request.data?.createMatchDraft === true) {
    const matchRef = firestore.collection(COLLECTIONS.matches).doc();
    await matchRef.set({
      title: matchTitle,
      matchType: 'single',
      matchMode: 'normal',
      status: 'draft',
      teamAId: clubASnap.data()?.linkedTeamId || null,
      teamBId: clubBSnap.data()?.linkedTeamId || null,
      teamAName: clubAName,
      teamBName: clubBName,
      seriesId,
      seriesCompetitionId: compRef.id,
      seriesClubAId: clubAId,
      seriesClubBId: clubBId,
      seriesOfficialStatus: officialStatus,
      createdBy: uid,
      scorerIds: [uid],
      createdAt: ts,
      updatedAt: ts,
    });
    matchId = matchRef.id;
  }

  await compRef.set({
    seriesId,
    type: 'singleMatch',
    title: matchTitle,
    clubAId,
    clubBId,
    matchId,
    tournamentId: null,
    status: officialStatus,
    createdBy: uid,
    createdAt: ts,
    updatedAt: ts,
    ...(autoApprove
      ? { approvedAt: ts, approvedBy: uid }
      : {}),
  });

  if (matchId) {
    await firestore.collection(COLLECTIONS.matches).doc(matchId).set({
      seriesId,
      seriesCompetitionId: compRef.id,
      seriesClubAId: clubAId,
      seriesClubBId: clubBId,
      seriesOfficialStatus: officialStatus,
      updatedAt: ts,
    }, { merge: true });
  }

  let approvalId = null;
  if (autoApprove) {
    await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
      matchCount: FieldValue.increment(1),
      updatedAt: ts,
    });
    await writeAudit(firestore, {
      seriesId,
      clubId: clubAId,
      actorUserId: uid,
      actorRole: access.role,
      action: 'MATCH_APPROVED_DIRECT',
      targetType: 'match',
      targetId: compRef.id,
      previousState: {},
      newState: { status: 'approved', matchId },
    });
  } else {
    const approval = await createApproval(firestore, {
      seriesId,
      clubId: clubAId,
      targetType: 'match',
      targetId: compRef.id,
      requestedBy: uid,
      metadata: { matchId, clubAId, clubBId, clubAName, clubBName },
    });
    approvalId = approval.id;
  }

  return {
    competitionId: compRef.id,
    approvalId,
    matchId,
    status: officialStatus,
    autoApproved: autoApprove,
  };
});

/**
 * Legacy entry point (older app builds typed a tournament ID). Now runs the
 * same checks as startSeriesTournament: the caller must organize the
 * tournament, and the requester/approval rules apply.
 */
exports.proposeSeriesTournament = onCall(async (request) => {
  const uid = requireAuth(request);
  return startSeriesTournamentCore(uid, {
    seriesId: request.data?.seriesId,
    tournamentId: request.data?.tournamentId,
    title: request.data?.title,
    teamClubIds: [],
    mode: 'link',
  });
});

exports.suspendSeriesEntity = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const entityType = String(request.data?.entityType || '');
  const entityId = String(request.data?.entityId || '');
  const reason = String(request.data?.reason || '');
  if (!seriesId || !entityType || !entityId) {
    throw new HttpsError('invalid-argument', 'Missing fields');
  }
  const firestore = db();
  await requireSuperAdmin(firestore, seriesId, uid);
  const ts = nowIso();

  if (entityType === 'series') {
    await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
      status: 'suspended',
      updatedAt: ts,
    });
  } else if (entityType === 'club') {
    await firestore.collection(COLLECTIONS.clubs).doc(entityId).update({
      status: 'suspended',
      updatedAt: ts,
    });
  } else if (entityType === 'membership') {
    await firestore.collection(COLLECTIONS.memberships).doc(entityId).update({
      status: 'suspended',
    });
  } else {
    throw new HttpsError('invalid-argument', 'Unknown entityType');
  }

  await writeAudit(firestore, {
    seriesId,
    actorUserId: uid,
    actorRole: 'superAdmin',
    action: 'ENTITY_SUSPENDED',
    targetType: entityType,
    targetId: entityId,
    reason,
    previousState: {},
    newState: { status: 'suspended' },
  });
  return { ok: true };
});

/** Maps pure-helper errors to HttpsError so clients get a readable message. */
function rethrowOwnerOp(err) {
  if (err instanceof OwnerOpError) {
    throw new HttpsError(err.code, err.message);
  }
  throw err;
}

/**
 * Owner-only: hand the organization to an existing active admin.
 * The previous owner stays on as an active admin. Audited + new owner notified.
 */
exports.transferSeriesOwnership = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const targetUserId = String(request.data?.newOwnerUserId || '').trim();
  if (!seriesId) {
    throw new HttpsError('invalid-argument', 'seriesId required');
  }
  const firestore = db();
  const series = await getSeriesOrThrow(firestore, seriesId);
  const targetRef = firestore.collection(COLLECTIONS.admins)
    .doc(adminDocId(seriesId, targetUserId || '_'));
  const targetSnap = targetUserId ? await targetRef.get() : null;
  let target;
  try {
    target = validateOwnershipTransfer({
      series,
      actorUid: uid,
      targetUid: targetUserId,
      targetAdmin: targetSnap?.exists ? targetSnap.data() : null,
    });
  } catch (err) {
    rethrowOwnerOp(err);
  }

  const ts = nowIso();
  const previousOwner = seriesOwnerUid(series);
  const previousOwnerRef = firestore.collection(COLLECTIONS.admins)
    .doc(adminDocId(seriesId, previousOwner));
  const previousOwnerSnap = await previousOwnerRef.get();
  const batch = firestore.batch();
  batch.update(firestore.collection(COLLECTIONS.series).doc(seriesId), {
    superAdminUserId: target,
    ownershipTransferredAt: ts,
    previousOwnerUserId: previousOwner,
    updatedAt: ts,
  });
  batch.set(targetRef, {
    role: 'superAdmin',
    status: 'active',
    updatedAt: ts,
  }, { merge: true });
  batch.set(previousOwnerRef, {
    seriesId,
    userId: previousOwner,
    role: 'seriesAdmin',
    status: 'active',
    updatedAt: ts,
    ...(previousOwnerSnap.exists ? {} : { createdBy: previousOwner, createdAt: ts, permissions: [] }),
  }, { merge: true });
  await batch.commit();

  await writeAudit(firestore, {
    seriesId,
    actorUserId: uid,
    actorRole: 'superAdmin',
    action: 'OWNERSHIP_TRANSFERRED',
    targetType: 'series',
    targetId: seriesId,
    reason: String(request.data?.reason || '').slice(0, 500),
    previousState: { ownerUserId: previousOwner },
    newState: { ownerUserId: target },
  });

  try {
    await firestore.collection('notifications').doc().set({
      userId: target,
      title: 'You are now the owner',
      body: `You now own ${series.name || 'an organization'} on CrickFlow.`,
      type: 'series_ownership_transferred',
      seriesId,
      addedByUserId: uid,
      createdAt: ts,
      read: false,
    });
  } catch (err) {
    console.error('ownership transfer notify failed', err);
  }

  return { ok: true, ownerUserId: target, previousOwnerUserId: previousOwner };
});

/**
 * Owner-only archive / reactivate. Refused while CrickFlow staff have the
 * organization on platform hold (`platformHold: true`).
 */
exports.setSeriesLifecycle = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const action = String(request.data?.action || '');
  const reason = String(request.data?.reason || '').slice(0, 500);
  if (!seriesId) {
    throw new HttpsError('invalid-argument', 'seriesId required');
  }
  const firestore = db();
  const series = await requireSuperAdmin(firestore, seriesId, uid);
  let next;
  try {
    next = lifecycleNextStatus(series, action);
  } catch (err) {
    rethrowOwnerOp(err);
  }
  const ts = nowIso();
  await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
    status: next,
    updatedAt: ts,
  });
  await writeAudit(firestore, {
    seriesId,
    actorUserId: uid,
    actorRole: 'superAdmin',
    action: action === 'archive' ? 'SERIES_ARCHIVED' : 'SERIES_REACTIVATED',
    targetType: 'series',
    targetId: seriesId,
    reason,
    previousState: { status: series.status || 'draft' },
    newState: { status: next },
  });
  return { ok: true, status: next };
});

/**
 * Series admins post an announcement to members. Stored under
 * series/{id}/announcements and fanned out as in-app notifications
 * (push via onNotificationCreated).
 */
exports.sendSeriesAnnouncement = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  if (!seriesId) {
    throw new HttpsError('invalid-argument', 'seriesId required');
  }
  let payload;
  try {
    payload = validateAnnouncement(request.data || {});
  } catch (err) {
    rethrowOwnerOp(err);
  }
  const firestore = db();
  const series = await requireSeriesAdmin(firestore, seriesId, uid);
  if (series.status !== 'active') {
    throw new HttpsError('failed-precondition', 'Only active organizations can send announcements');
  }

  const rows = async (collection) => {
    const snap = await firestore.collection(collection)
      .where('seriesId', '==', seriesId)
      .where('status', '==', 'active')
      .limit(2500)
      .get();
    return snap.docs.map((d) => d.data());
  };
  const needAdmins = payload.audience === 'all' || payload.audience === 'admins';
  const needClubAdmins = payload.audience === 'all' || payload.audience === 'clubAdmins';
  const needMembers = payload.audience === 'all' || payload.audience === 'members';
  const recipients = announcementRecipients({
    audience: payload.audience,
    ownerUid: seriesOwnerUid(series),
    seriesAdmins: needAdmins ? await rows(COLLECTIONS.admins) : [],
    clubAdmins: needClubAdmins ? await rows(COLLECTIONS.clubAdmins) : [],
    memberships: needMembers ? await rows(COLLECTIONS.memberships) : [],
    senderUid: uid,
  });

  const ts = nowIso();
  const senderSnap = await firestore.collection(COLLECTIONS.users).doc(uid).get();
  const sender = senderSnap.exists ? senderSnap.data() : {};
  const announcementRef = firestore.collection(COLLECTIONS.series).doc(seriesId)
    .collection(COLLECTIONS.announcements).doc();
  await announcementRef.set({
    seriesId,
    title: payload.title,
    body: payload.body,
    audience: payload.audience,
    createdBy: uid,
    createdByName: String(sender.displayName || sender.name || ''),
    recipientCount: recipients.length,
    createdAt: ts,
  });

  for (let i = 0; i < recipients.length; i += 400) {
    const batch = firestore.batch();
    for (const userId of recipients.slice(i, i + 400)) {
      batch.set(firestore.collection('notifications').doc(), {
        userId,
        title: `${series.name || 'Organization'}: ${payload.title}`,
        body: payload.body.slice(0, 240),
        type: 'series_announcement',
        seriesId,
        requestId: announcementRef.id,
        addedByUserId: uid,
        createdAt: ts,
        read: false,
      });
    }
    await batch.commit();
  }

  await writeAudit(firestore, {
    seriesId,
    actorUserId: uid,
    actorRole: isSuperAdmin(series, uid) ? 'superAdmin' : 'seriesAdmin',
    action: 'ANNOUNCEMENT_SENT',
    targetType: 'announcement',
    targetId: announcementRef.id,
    previousState: {},
    newState: { audience: payload.audience, recipientCount: recipients.length },
    metadata: { title: payload.title },
  });

  return { ok: true, announcementId: announcementRef.id, recipientCount: recipients.length };
});

exports.getSeriesRegistrationIdentity = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const registrationId = String(request.data?.registrationId || '');
  if (!seriesId || !registrationId) {
    throw new HttpsError('invalid-argument', 'seriesId and registrationId required');
  }
  const firestore = db();
  await requireSeriesAdmin(firestore, seriesId, uid);
  const regSnap = await firestore.collection(COLLECTIONS.registrations).doc(registrationId).get();
  if (!regSnap.exists || regSnap.data().seriesId !== seriesId) {
    throw new HttpsError('not-found', 'Registration not found');
  }
  const idSnap = await regSnap.ref.collection('private').doc('identity').get();
  return {
    registrationId,
    identity: idSnap.exists ? idSnap.data() : null,
  };
});

// ── Org tournaments / matches (start inside an org, requests, approvals) ────

function assertSeriesOpen(series) {
  if (series.platformHold === true || ['archived', 'suspended'].includes(series.status)) {
    throw new HttpsError('failed-precondition', 'This org is not active');
  }
}

function competitionHttpsError(err) {
  if (err instanceof competitionOps.CompetitionOpError) {
    return new HttpsError(err.code, err.message);
  }
  return err;
}

/** players/{id} -> userId ('' when the profile has no account). Missing docs are omitted. */
async function loadPlayerUserIds(firestore, ids) {
  const out = new Map();
  const refs = ids.map((id) => firestore.collection('players').doc(id));
  for (let i = 0; i < refs.length; i += 100) {
    const snaps = await firestore.getAll(...refs.slice(i, i + 100));
    for (const snap of snaps) {
      if (snap.exists) out.set(snap.id, String(snap.data()?.userId || ''));
    }
  }
  return out;
}

/** Org setting allowWalkIns = false: no guest / account-less players in the squads. */
async function assertWalkInsAllowed(firestore, series, match) {
  if (competitionOps.resolvePolicy(series).allowWalkIns) return;
  const userIds = await loadPlayerUserIds(firestore, orgWalkIns.rosterPlayerIdsToCheck(match));
  const found = orgWalkIns.findWalkIns(match, userIds);
  if (found.length) {
    throw new HttpsError('failed-precondition', orgWalkIns.walkInsMessage(found));
  }
}

async function listSeriesClubs(firestore, seriesId) {
  const snap = await firestore.collection(COLLECTIONS.clubs)
    .where('seriesId', '==', seriesId)
    .get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

/** Org teams the caller can act for: active team-admin teams + active player teams. */
async function callerTeamRoles(firestore, seriesId, uid) {
  const [adminSnap, memberSnap] = await Promise.all([
    firestore.collection(COLLECTIONS.clubAdmins)
      .where('seriesId', '==', seriesId)
      .where('userId', '==', uid)
      .get(),
    firestore.collection(COLLECTIONS.memberships)
      .where('seriesId', '==', seriesId)
      .where('userId', '==', uid)
      .get(),
  ]);
  const active = (snap) => snap.docs
    .map((d) => d.data())
    .filter((d) => d.status === 'active' && d.clubId)
    .map((d) => d.clubId);
  return { adminClubIds: active(adminSnap), memberClubIds: active(memberSnap) };
}

async function notifyUser(firestore, userId, { title, body, type, seriesId, extra = {}, from }) {
  if (!userId || userId === from) return;
  try {
    await firestore.collection('notifications').doc().set({
      userId,
      title,
      body,
      type,
      seriesId,
      ...extra,
      addedByUserId: from || 'system',
      createdAt: nowIso(),
      read: false,
    });
  } catch (err) {
    console.error('series competition notify failed', err);
  }
}

async function startSeriesTournamentCore(uid, data) {
  const seriesId = String(data?.seriesId || '');
  const tournamentId = String(data?.tournamentId || '');
  const mode = data?.mode === 'link' ? 'link' : 'create';
  if (!seriesId || !tournamentId) {
    throw new HttpsError('invalid-argument', 'seriesId and tournamentId required');
  }
  const firestore = db();
  const series = await getSeriesOrThrow(firestore, seriesId);
  assertSeriesOpen(series);
  const isAdmin = await isSeriesAdmin(firestore, series, uid);
  const roles = isAdmin
    ? { adminClubIds: [], memberClubIds: [] }
    : await callerTeamRoles(firestore, seriesId, uid);
  let access;
  try {
    access = competitionOps.decideAccess({
      kind: 'tournament',
      isAdmin,
      isOwner: isSuperAdmin(series, uid),
      isTeamAdmin: roles.adminClubIds.length > 0,
      isMember: roles.memberClubIds.length > 0,
      policy: competitionOps.resolvePolicy(series),
      orgOpen: competitionOps.isOrgOpen(series),
    });
  } catch (err) {
    throw competitionHttpsError(err);
  }

  const tRef = firestore.collection(COLLECTIONS.tournaments).doc(tournamentId);
  const tSnap = await tRef.get();
  const tournament = tSnap.exists ? tSnap.data() : null;
  let teamRows = [];
  try {
    competitionOps.validateTournamentLink({ tournament, seriesId, uid });
    const ids = Array.isArray(data?.teamClubIds) ? data.teamClubIds : [];
    if (ids.length) {
      teamRows = competitionOps.resolveTournamentTeams({
        teamClubIds: ids,
        clubs: await listSeriesClubs(firestore, seriesId),
      });
    }
  } catch (err) {
    throw competitionHttpsError(err);
  }

  const ts = nowIso();
  const status = access.autoApprove ? 'approved' : 'pendingApproval';
  const requesterClubId = roles.adminClubIds[0] || roles.memberClubIds[0] || null;
  const compRef = firestore.collection(COLLECTIONS.competitions).doc();
  const title = String(data?.title || '').trim() || tournament.name || 'Org tournament';

  const batch = firestore.batch();
  batch.set(compRef, {
    seriesId,
    type: 'tournament',
    title,
    clubAId: requesterClubId,
    clubBId: null,
    matchId: null,
    tournamentId,
    origin: mode === 'link' ? 'linked' : 'created',
    status,
    createdBy: uid,
    createdAt: ts,
    updatedAt: ts,
    ...(access.autoApprove ? { approvedAt: ts, approvedBy: uid } : {}),
  });
  batch.set(tRef, {
    seriesId,
    seriesCompetitionId: compRef.id,
    seriesOfficialStatus: status,
    ...(teamRows.length ? competitionOps.tournamentTeamsPatch(tournament, teamRows) : {}),
    updatedAt: ts,
  }, { merge: true });
  if (access.autoApprove) {
    batch.update(firestore.collection(COLLECTIONS.series).doc(seriesId), {
      tournamentCount: FieldValue.increment(1),
      updatedAt: ts,
    });
  }
  await batch.commit();

  let approvalId = null;
  if (access.autoApprove) {
    await writeAudit(firestore, {
      seriesId,
      clubId: requesterClubId,
      actorUserId: uid,
      actorRole: access.role,
      action: mode === 'link' ? 'TOURNAMENT_LINKED_DIRECT' : 'TOURNAMENT_CREATED_DIRECT',
      targetType: 'tournament',
      targetId: compRef.id,
      previousState: {},
      newState: { status, tournamentId, teams: teamRows.map((c) => c.id) },
    });
  } else {
    const approval = await createApproval(firestore, {
      seriesId,
      clubId: requesterClubId,
      targetType: 'tournament',
      targetId: compRef.id,
      requestedBy: uid,
      metadata: { tournamentId, title, teamCount: teamRows.length },
    });
    approvalId = approval.id;
    await writeAudit(firestore, {
      seriesId,
      clubId: requesterClubId,
      actorUserId: uid,
      actorRole: access.role,
      action: 'TOURNAMENT_REQUESTED',
      targetType: 'tournament',
      targetId: compRef.id,
      previousState: {},
      newState: { status, tournamentId },
    });
  }
  return {
    competitionId: compRef.id,
    approvalId,
    tournamentId,
    status,
    autoApproved: access.autoApprove,
  };
}

/**
 * Link a tournament the caller just created in the org wizard (mode 'create')
 * or one of their existing tournaments (mode 'link', org admins only).
 * Adds the chosen org teams to the tournament.
 */
exports.startSeriesTournament = onCall(async (request) => {
  const uid = requireAuth(request);
  const mode = request.data?.mode === 'link' ? 'link' : 'create';
  if (mode === 'link') {
    const firestore = db();
    const series = await getSeriesOrThrow(firestore, String(request.data?.seriesId || ''));
    if (!(await isSeriesAdmin(firestore, series, uid))) {
      throw new HttpsError('permission-denied', 'Only org admins can add an existing tournament');
    }
  }
  return startSeriesTournamentCore(uid, { ...request.data, mode });
});

/**
 * Register a match started from inside an org (both sides approved org teams).
 * Inside an org tournament the match inherits the tournament's org status.
 * Idempotent: a second call for the same match returns the existing link.
 */
exports.startSeriesMatch = onCall(async (request) => {
  const uid = requireAuth(request);
  return registerSeriesMatchCore(uid, request.data || {});
});

/**
 * Shared by the startSeriesMatch callable and the onMatchCompleted fallback
 * (which acts as the match creator, with the same permission checks).
 */
async function registerSeriesMatchCore(uid, data) {
  const seriesId = String(data?.seriesId || '');
  const matchId = String(data?.matchId || '');
  if (!seriesId || !matchId) {
    throw new HttpsError('invalid-argument', 'seriesId and matchId required');
  }
  const firestore = db();
  const series = await getSeriesOrThrow(firestore, seriesId);
  assertSeriesOpen(series);
  const mRef = firestore.collection(COLLECTIONS.matches).doc(matchId);
  const mSnap = await mRef.get();
  const match = mSnap.exists ? { id: mSnap.id, ...mSnap.data() } : null;
  if (!match) throw new HttpsError('not-found', 'Match not found');
  if (!competitionOps.canRegisterMatch(match, uid)) {
    throw new HttpsError('permission-denied', 'Only the match creator or scorer can add it to an org');
  }
  try {
    competitionOps.assertNotQuick(match);
  } catch (err) {
    throw competitionHttpsError(err);
  }
  if (match.seriesId === seriesId && match.seriesOfficialStatus &&
      match.seriesOfficialStatus !== 'rejected') {
    return {
      competitionId: match.seriesCompetitionId || null,
      status: match.seriesOfficialStatus,
      autoApproved: match.seriesOfficialStatus === 'approved',
      already: true,
    };
  }
  if (match.seriesId && match.seriesId !== seriesId &&
      match.seriesOfficialStatus !== 'rejected') {
    throw new HttpsError('failed-precondition', 'Match already belongs to another org');
  }
  await assertWalkInsAllowed(firestore, series, match);

  const isAdmin = await isSeriesAdmin(firestore, series, uid);
  const roles = isAdmin
    ? { adminClubIds: [], memberClubIds: [] }
    : await callerTeamRoles(firestore, seriesId, uid);
  let access;
  let sides;
  try {
    sides = competitionOps.resolveMatchTeams({
      match,
      clubs: await listSeriesClubs(firestore, seriesId),
    });
    const sideIds = sides.map((c) => c.id);
    const asTeamAdmin = competitionOps.requesterOwnsSide({
      isAdmin, sideClubIds: sideIds, myClubIds: roles.adminClubIds,
    });
    const asMember = competitionOps.requesterOwnsSide({
      isAdmin, sideClubIds: sideIds, myClubIds: roles.memberClubIds,
    });
    access = competitionOps.decideAccess({
      kind: 'match',
      isAdmin,
      isOwner: isSuperAdmin(series, uid),
      isTeamAdmin: !isAdmin && asTeamAdmin,
      isMember: !isAdmin && asMember,
      policy: competitionOps.resolvePolicy(series),
      orgOpen: competitionOps.isOrgOpen(series),
    });
  } catch (err) {
    throw competitionHttpsError(err);
  }

  const ts = nowIso();
  const [clubA, clubB] = sides;

  // Inside an org tournament: inherit its status, no separate fixture row.
  if (match.tournamentId) {
    const tSnap = await firestore.collection(COLLECTIONS.tournaments).doc(match.tournamentId).get();
    const t = tSnap.data() || {};
    if (t.seriesId === seriesId && t.seriesOfficialStatus !== 'rejected') {
      await mRef.set({
        seriesId,
        seriesCompetitionId: t.seriesCompetitionId || null,
        seriesClubAId: clubA.id,
        seriesClubBId: clubB.id,
        seriesOfficialStatus: t.seriesOfficialStatus || 'pendingApproval',
        updatedAt: ts,
      }, { merge: true });
      return {
        competitionId: t.seriesCompetitionId || null,
        status: t.seriesOfficialStatus || 'pendingApproval',
        autoApproved: t.seriesOfficialStatus === 'approved',
        viaTournament: true,
      };
    }
  }

  const status = access.autoApprove ? 'approved' : 'pendingApproval';
  const fixedRef = firestore.collection(COLLECTIONS.competitions).doc(`match_${matchId}`);
  const fixedSnap = await fixedRef.get();
  if (fixedSnap.exists && fixedSnap.data()?.status !== 'rejected') {
    const d = fixedSnap.data();
    return { competitionId: fixedRef.id, status: d.status, autoApproved: d.status === 'approved', already: true };
  }
  const compRef = fixedSnap.exists
    ? firestore.collection(COLLECTIONS.competitions).doc()
    : fixedRef;
  const title = match.title || `${clubA.name || 'Team A'} vs ${clubB.name || 'Team B'}`;
  const batch = firestore.batch();
  batch.create(compRef, {
    seriesId,
    type: 'singleMatch',
    title,
    clubAId: clubA.id,
    clubBId: clubB.id,
    matchId,
    tournamentId: match.tournamentId || null,
    origin: 'created',
    status,
    createdBy: uid,
    createdAt: ts,
    updatedAt: ts,
    ...(access.autoApprove ? { approvedAt: ts, approvedBy: uid } : {}),
  });
  batch.set(mRef, {
    seriesId,
    seriesCompetitionId: compRef.id,
    seriesClubAId: clubA.id,
    seriesClubBId: clubB.id,
    seriesOfficialStatus: status,
    updatedAt: ts,
  }, { merge: true });
  if (access.autoApprove) {
    batch.update(firestore.collection(COLLECTIONS.series).doc(seriesId), {
      matchCount: FieldValue.increment(1),
      updatedAt: ts,
    });
  }
  try {
    await batch.commit();
  } catch (err) {
    // Client retry and the completion fallback raced: the first one won.
    if (err && (err.code === 6 || err.code === 'already-exists')) {
      return { competitionId: compRef.id, status, autoApproved: access.autoApprove, already: true };
    }
    throw err;
  }

  let approvalId = null;
  if (access.autoApprove) {
    await writeAudit(firestore, {
      seriesId,
      clubId: clubA.id,
      actorUserId: uid,
      actorRole: access.role,
      action: 'MATCH_CREATED_DIRECT',
      targetType: 'match',
      targetId: compRef.id,
      previousState: {},
      newState: { status, matchId },
    });
    // Already finished (e.g. scored offline before syncing): count it now.
    if (match.status === 'completed') {
      await updateSeriesRankings(firestore, {
        ...match, seriesId, seriesOfficialStatus: 'approved',
        seriesClubAId: clubA.id, seriesClubBId: clubB.id,
      }).catch((e) => console.error('series rankings on link failed', matchId, e));
    }
  } else {
    const approval = await createApproval(firestore, {
      seriesId,
      clubId: clubA.id,
      targetType: 'match',
      targetId: compRef.id,
      requestedBy: uid,
      metadata: {
        matchId, clubAId: clubA.id, clubBId: clubB.id,
        clubAName: clubA.name || '', clubBName: clubB.name || '',
      },
    });
    approvalId = approval.id;
    await writeAudit(firestore, {
      seriesId,
      clubId: clubA.id,
      actorUserId: uid,
      actorRole: access.role,
      action: 'MATCH_REQUESTED',
      targetType: 'match',
      targetId: compRef.id,
      previousState: {},
      newState: { status, matchId },
    });
  }
  return {
    competitionId: compRef.id,
    approvalId,
    matchId,
    status,
    autoApproved: access.autoApprove,
  };
}

/** Owner-only: who may request and whether requests need approval. */
exports.updateSeriesCompetitionPolicy = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  if (!seriesId) throw new HttpsError('invalid-argument', 'seriesId required');
  const firestore = db();
  const series = await requireSuperAdmin(firestore, seriesId, uid);
  let policy;
  try {
    policy = competitionOps.sanitizePolicy(request.data?.policy, series.competitionPolicy);
  } catch (err) {
    throw competitionHttpsError(err);
  }
  await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
    competitionPolicy: policy,
    updatedAt: nowIso(),
  });
  await writeAudit(firestore, {
    seriesId,
    actorUserId: uid,
    actorRole: 'superAdmin',
    action: 'COMPETITION_POLICY_CHANGED',
    targetType: 'series',
    targetId: seriesId,
    previousState: { competitionPolicy: competitionOps.resolvePolicy(series) },
    newState: { competitionPolicy: policy },
  });
  return { ok: true, policy };
});

/**
 * After an org approval decision on a tournament: make its matches official
 * (and count completed ones), or unlink everything on rejection.
 */
async function applyTournamentDecision(firestore, { seriesId, compId, tournamentId, decision, ts }) {
  const tRef = firestore.collection(COLLECTIONS.tournaments).doc(tournamentId);
  if (decision !== 'approved') {
    await tRef.set({
      seriesOfficialStatus: 'rejected',
      seriesId: FieldValue.delete(),
      seriesCompetitionId: FieldValue.delete(),
      updatedAt: ts,
    }, { merge: true });
  }
  const mSnap = await firestore.collection(COLLECTIONS.matches)
    .where('tournamentId', '==', tournamentId)
    .get();
  const clubs = decision === 'approved' ? await listSeriesClubs(firestore, seriesId) : [];
  const byTeam = competitionOps.playableTeamsByLinkedId(clubs);
  for (const d of mSnap.docs) {
    const m = { id: d.id, ...d.data() };
    if (competitionOps.isQuickMatch(m)) continue;
    if (decision !== 'approved') {
      if (m.seriesId === seriesId) {
        await d.ref.set({
          seriesOfficialStatus: 'rejected',
          seriesId: FieldValue.delete(),
          seriesCompetitionId: FieldValue.delete(),
          updatedAt: ts,
        }, { merge: true });
      }
      continue;
    }
    const a = byTeam.get(m.teamAId || '');
    const b = byTeam.get(m.teamBId || '');
    const patch = {
      seriesId,
      seriesCompetitionId: compId,
      seriesOfficialStatus: 'approved',
      ...(a ? { seriesClubAId: a.id } : {}),
      ...(b ? { seriesClubBId: b.id } : {}),
      updatedAt: ts,
    };
    await d.ref.set(patch, { merge: true });
    if (m.status === 'completed' && a && b) {
      await updateSeriesRankings(firestore, { ...m, ...patch })
        .catch((e) => console.error('series rankings on approval failed', m.id, e));
    }
  }
}

async function applyMatchDecision(firestore, { seriesId, matchId, decision, ts }) {
  const mRef = firestore.collection(COLLECTIONS.matches).doc(matchId);
  if (decision !== 'approved') {
    await mRef.set({
      seriesOfficialStatus: 'rejected',
      seriesId: FieldValue.delete(),
      seriesCompetitionId: FieldValue.delete(),
      updatedAt: ts,
    }, { merge: true });
    return;
  }
  await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
    matchCount: FieldValue.increment(1),
    updatedAt: ts,
  });
  const snap = await mRef.get();
  const m = snap.exists ? { id: snap.id, ...snap.data() } : null;
  if (m && m.status === 'completed') {
    await updateSeriesRankings(firestore, { ...m, seriesId, seriesOfficialStatus: 'approved' })
      .catch((e) => console.error('series rankings on approval failed', matchId, e));
  }
}

/**
 * Org admins: back every org team with a locked CrickFlow team (safe to re-run).
 */
exports.migrateSeriesTeamLinks = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  if (!seriesId) throw new HttpsError('invalid-argument', 'seriesId required');
  const firestore = db();
  const series = await requireSeriesAdmin(firestore, seriesId, uid);
  const result = await orgTeams.migrateSeriesTeams(firestore, { seriesId, seriesName: series.name });
  if (result.locked || result.created) {
    await writeAudit(firestore, {
      seriesId,
      actorUserId: uid,
      actorRole: isSuperAdmin(series, uid) ? 'superAdmin' : 'seriesAdmin',
      action: 'ORG_TEAMS_LINKED',
      targetType: 'series',
      targetId: seriesId,
      previousState: {},
      newState: { locked: result.locked, created: result.created },
    });
  }
  return result;
});

/**
 * Org admins: rebuild the per-match digests behind the org leaderboards
 * (fielding, dot balls, maidens, fastest 50/100). Safe to re-run; used to
 * backfill matches that finished before digests existed.
 */
exports.rebuildSeriesStandings = onCall(
  { timeoutSeconds: 540, memory: '512MiB' },
  async (request) => {
    const uid = requireAuth(request);
    const seriesId = String(request.data?.seriesId || '');
    if (!seriesId) throw new HttpsError('invalid-argument', 'seriesId required');
    const firestore = db();
    await requireSeriesAdmin(firestore, seriesId, uid);
    const { rebuildSeriesDigests } = require('../match/onOrgMatchDigest');
    return rebuildSeriesDigests(firestore, seriesId);
  },
);

exports.applyTournamentDecision = applyTournamentDecision;
exports.registerSeriesMatchCore = registerSeriesMatchCore;

exports.COLLECTIONS = COLLECTIONS;
exports.clubRankingDocId = clubRankingDocId;
exports.playerRankingDocId = playerRankingDocId;
exports.writeAudit = writeAudit;
