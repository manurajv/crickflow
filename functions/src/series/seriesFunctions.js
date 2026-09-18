/**
 * Series / Competition Organization — privileged callables + helpers.
 * All sensitive mutations (approvals, PII, memberships, admin grants) go here.
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

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
    throw new HttpsError('invalid-argument', 'Max players per club must be 1–50');
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
    throw new HttpsError('invalid-argument', 'Max players per club must be 1–50');
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
  const club = {
    seriesId,
    name: name.slice(0, 120),
    description: String(request.data?.description || '').slice(0, 2000),
    logoUrl: request.data?.logoUrl || null,
    linkedTeamId: request.data?.linkedTeamId || null,
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
  const reason = String(request.data?.reason || '');
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

  const ts = nowIso();
  await updateApprovalDocs(firestore, seriesId, approvalId, {
    status: decision,
    reviewedBy: uid,
    reviewedAt: ts,
    reason,
  });

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
          'Club Admin must approve this join before Series approval',
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
        await firestore.collection(COLLECTIONS.memberships).doc(mid).update({
          status: 'removed',
          leftAt: ts,
        });
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
        body: `${targetType} ${decision}${reason ? `: ${reason}` : ''}`,
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
    throw new HttpsError('not-found', 'Club not found');
  }
  if (clubSnap.data().status !== 'approved') {
    throw new HttpsError('failed-precondition', 'Club is not approved');
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
    throw new HttpsError('permission-denied', 'Club Admin required');
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
    throw new HttpsError('permission-denied', 'Club or Series Admin required');
  }
  const clubSnap = await firestore.collection(COLLECTIONS.clubs).doc(clubId).get();
  if (!clubSnap.exists || clubSnap.data().seriesId !== seriesId) {
    throw new HttpsError('not-found', 'Club not found');
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
    throw new HttpsError('permission-denied', 'Club Admin required');
  }

  const clubSnap = await firestore.collection(COLLECTIONS.clubs).doc(clubId).get();
  if (!clubSnap.exists || clubSnap.data().seriesId !== seriesId) {
    throw new HttpsError('not-found', 'Club not found');
  }
  if (clubSnap.data().status !== 'approved') {
    throw new HttpsError('failed-precondition', 'Club must be approved before adding players');
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
    await firestore.collection(COLLECTIONS.memberships).doc(mid).update({
      status: 'removed',
      leftAt: nowIso(),
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
  const asClubA = await isClubAdmin(firestore, seriesId, clubAId, uid);
  const asClubB = await isClubAdmin(firestore, seriesId, clubBId, uid);
  if (!asAdmin && !asClubA && !asClubB) {
    throw new HttpsError('permission-denied', 'Club Admin required');
  }

  const ts = nowIso();
  const autoApprove = asAdmin;
  const officialStatus = autoApprove ? 'approved' : 'pendingApproval';
  const compRef = firestore.collection(COLLECTIONS.competitions).doc();
  let matchId = request.data?.matchId || null;

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
      actorRole: isSuperAdmin(series, uid) ? 'superAdmin' : 'seriesAdmin',
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

exports.proposeSeriesTournament = onCall(async (request) => {
  const uid = requireAuth(request);
  const seriesId = String(request.data?.seriesId || '');
  const tournamentId = String(request.data?.tournamentId || '');
  const title = String(request.data?.title || '').trim();
  const clubId = String(request.data?.clubId || '');
  if (!seriesId || !tournamentId) {
    throw new HttpsError('invalid-argument', 'seriesId and tournamentId required');
  }
  const firestore = db();
  const series = await getSeriesOrThrow(firestore, seriesId);
  const asAdmin = await isSeriesAdmin(firestore, series, uid);
  const asClub = clubId
    ? await isClubAdmin(firestore, seriesId, clubId, uid)
    : false;
  if (!asAdmin && !asClub) {
    throw new HttpsError('permission-denied', 'Club Admin required');
  }

  const ts = nowIso();
  const autoApprove = asAdmin;
  const officialStatus = autoApprove ? 'approved' : 'pendingApproval';
  const compRef = firestore.collection(COLLECTIONS.competitions).doc();
  await compRef.set({
    seriesId,
    type: 'tournament',
    title: title || 'Series Tournament',
    clubAId: clubId || null,
    clubBId: null,
    matchId: null,
    tournamentId,
    status: officialStatus,
    createdBy: uid,
    createdAt: ts,
    updatedAt: ts,
    ...(autoApprove
      ? { approvedAt: ts, approvedBy: uid }
      : {}),
  });

  await firestore.collection(COLLECTIONS.tournaments).doc(tournamentId).set({
    seriesId,
    seriesCompetitionId: compRef.id,
    seriesOfficialStatus: officialStatus,
    updatedAt: ts,
  }, { merge: true });

  let approvalId = null;
  if (autoApprove) {
    await firestore.collection(COLLECTIONS.series).doc(seriesId).update({
      tournamentCount: FieldValue.increment(1),
      updatedAt: ts,
    });
    await writeAudit(firestore, {
      seriesId,
      clubId: clubId || null,
      actorUserId: uid,
      actorRole: isSuperAdmin(series, uid) ? 'superAdmin' : 'seriesAdmin',
      action: 'TOURNAMENT_APPROVED_DIRECT',
      targetType: 'tournament',
      targetId: compRef.id,
      previousState: {},
      newState: { status: 'approved', tournamentId },
    });
  } else {
    const approval = await createApproval(firestore, {
      seriesId,
      clubId: clubId || null,
      targetType: 'tournament',
      targetId: compRef.id,
      requestedBy: uid,
      metadata: { tournamentId },
    });
    approvalId = approval.id;
  }

  return {
    competitionId: compRef.id,
    approvalId,
    status: officialStatus,
    autoApproved: autoApprove,
  };
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

exports.COLLECTIONS = COLLECTIONS;
exports.clubRankingDocId = clubRankingDocId;
exports.playerRankingDocId = playerRankingDocId;
exports.writeAudit = writeAudit;
