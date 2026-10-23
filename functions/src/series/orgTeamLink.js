/**
 * Org teams (series_clubs) are backed by a real CrickFlow team (teams/{id}).
 *
 * - The team carries `orgLock: { seriesId, clubId, seriesName, lockedAt }`.
 *   Firestore rules refuse client edits to its name, roster and details while
 *   the lock is set; only these server helpers change the roster, mirroring
 *   approved org membership changes.
 * - A rejected org team is unlocked again and stays a normal team.
 * - Nothing here deletes a team or removes a player who was already on it,
 *   except mirroring an approved org removal.
 */
const { FieldValue } = require('firebase-admin/firestore');

class OrgTeamLinkError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function formatTeamCode(n) {
  return `TM${String(n).padStart(5, '0')}`;
}

/** Same counter the app uses (app_meta/cf_team_ids). */
async function allocateTeamCode(firestore) {
  const ref = firestore.collection('app_meta').doc('cf_team_ids');
  return firestore.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const next = (Number(snap.data()?.lastNumber) || 0) + 1;
    tx.set(ref, { lastNumber: next, updatedAt: new Date().toISOString() }, { merge: true });
    return formatTeamCode(next);
  });
}

/** Lock held by an org team that is still live (not rejected / missing). */
function lockIsLive(lock, clubData) {
  if (!lock || !lock.clubId) return false;
  if (!clubData) return false;
  return clubData.status !== 'rejected';
}

/**
 * Pure check before linking [team] to a new org team.
 * [lockClub] is the series_clubs doc the team is currently locked to, if any.
 */
function validateLinkTarget({ team, uid, lockClub, allowNonOwner = false }) {
  if (!team) throw new OrgTeamLinkError('not-found', 'Team not found');
  if (!allowNonOwner && team.createdBy !== uid) {
    throw new OrgTeamLinkError('permission-denied', 'Only the team owner can add this team to an org');
  }
  if (lockIsLive(team.orgLock, lockClub)) {
    throw new OrgTeamLinkError('already-exists', 'This team already belongs to an org');
  }
}

function buildServerTeam({ name, createdBy, playerIds = [], ts }) {
  return {
    name: String(name || 'Team').slice(0, 120),
    playerIds,
    memberCount: playerIds.length,
    location: {},
    badgeIds: [],
    createdBy,
    createdAt: ts,
    updatedAt: ts,
  };
}

function buildLock({ seriesId, clubId, seriesName, ts }) {
  return { seriesId, clubId, seriesName: seriesName || '', lockedAt: ts };
}

async function readLockClub(firestore, team) {
  const clubId = team?.orgLock?.clubId;
  if (!clubId) return null;
  const snap = await firestore.collection('series_clubs').doc(clubId).get();
  return snap.exists ? snap.data() : null;
}

/** Creates a CrickFlow team for an org team (web / older apps / migration). */
async function createTeamForClub(firestore, { name, createdBy, playerIds = [], lock, ts }) {
  const ref = firestore.collection('teams').doc();
  let teamCode = null;
  try {
    teamCode = await allocateTeamCode(firestore);
  } catch (err) {
    console.warn('org team code allocation failed', err.message);
  }
  await ref.set({
    ...buildServerTeam({ name, createdBy, playerIds, ts }),
    ...(teamCode ? { teamCode } : {}),
    orgLock: lock,
  });
  if (playerIds.length) {
    const batch = firestore.batch();
    for (const pid of playerIds) {
      batch.set(firestore.collection('players').doc(pid), {
        teamIds: FieldValue.arrayUnion(ref.id),
        updatedAt: ts,
      }, { merge: true });
    }
    await batch.commit();
  }
  return ref.id;
}

async function lockTeam(firestore, teamId, lock) {
  await firestore.collection('teams').doc(teamId).update({
    orgLock: lock,
    updatedAt: lock.lockedAt,
  });
}

/** Removes the lock only if it still points at [clubId]. */
async function unlockTeamForClub(firestore, teamId, clubId) {
  if (!teamId) return;
  const ref = firestore.collection('teams').doc(teamId);
  const snap = await ref.get();
  if (!snap.exists || snap.data()?.orgLock?.clubId !== clubId) return;
  await ref.update({ orgLock: FieldValue.delete(), updatedAt: new Date().toISOString() });
}

/** Player doc for an org member: membership.playerDocId, then users' own profile. */
async function resolvePlayerDocId(firestore, { playerDocId, userId }) {
  if (playerDocId) {
    const s = await firestore.collection('players').doc(playerDocId).get();
    if (s.exists) return playerDocId;
  }
  if (!userId) return null;
  const own = await firestore.collection('players').doc(userId).get();
  if (own.exists) return userId;
  const q = await firestore.collection('players').where('userId', '==', userId).limit(1).get();
  return q.empty ? null : q.docs[0].id;
}

async function linkedTeamIdForClub(firestore, clubId) {
  const snap = await firestore.collection('series_clubs').doc(clubId).get();
  return snap.data()?.linkedTeamId || null;
}

/** Mirrors an approved org membership onto the linked team roster. */
async function addMemberToLinkedTeam(firestore, { clubId, userId, playerDocId }) {
  const teamId = await linkedTeamIdForClub(firestore, clubId);
  if (!teamId) return null;
  const teamRef = firestore.collection('teams').doc(teamId);
  const teamSnap = await teamRef.get();
  if (!teamSnap.exists || teamSnap.data()?.orgLock?.clubId !== clubId) return null;
  const pid = await resolvePlayerDocId(firestore, { playerDocId, userId });
  if (!pid) return null;
  const ts = new Date().toISOString();
  const ids = new Set(teamSnap.data().playerIds || []);
  ids.add(pid);
  await teamRef.update({ playerIds: [...ids], memberCount: ids.size, updatedAt: ts });
  await firestore.collection('players').doc(pid).set({
    teamIds: FieldValue.arrayUnion(teamId),
    teamId,
    updatedAt: ts,
  }, { merge: true });
  return pid;
}

/** Mirrors an approved org removal onto the linked team roster. */
async function removeMemberFromLinkedTeam(firestore, { clubId, userId, playerDocId }) {
  const teamId = await linkedTeamIdForClub(firestore, clubId);
  if (!teamId) return null;
  const teamRef = firestore.collection('teams').doc(teamId);
  const teamSnap = await teamRef.get();
  if (!teamSnap.exists || teamSnap.data()?.orgLock?.clubId !== clubId) return null;
  const pid = await resolvePlayerDocId(firestore, { playerDocId, userId });
  if (!pid) return null;
  const team = teamSnap.data();
  if (pid === team.createdBy) return null; // never strip the team owner
  const ts = new Date().toISOString();
  const ids = (team.playerIds || []).filter((x) => x !== pid);
  const patch = { playerIds: ids, memberCount: ids.length, updatedAt: ts };
  if (team.captainId === pid) patch.captainId = FieldValue.delete();
  if (team.viceCaptainId === pid) patch.viceCaptainId = FieldValue.delete();
  await teamRef.update(patch);
  await firestore.collection('players').doc(pid).set({
    teamIds: FieldValue.arrayRemove(teamId),
    updatedAt: ts,
  }, { merge: true });
  return pid;
}

/**
 * Non-destructive backfill for one org:
 * - club with a linked team the club creator owns: lock it, add active org
 *   members to its roster (nobody is removed);
 * - club without a team: create one (owner = club creator) with the active
 *   org members, link and lock it;
 * - rejected clubs, teams locked to another live org team, or linked teams
 *   owned by someone else are skipped and reported.
 */
async function migrateSeriesTeams(firestore, { seriesId, seriesName }) {
  const out = { locked: 0, created: 0, alreadyLinked: 0, skipped: [] };
  const clubs = await firestore.collection('series_clubs').where('seriesId', '==', seriesId).get();
  for (const doc of clubs.docs) {
    const club = doc.data();
    const clubId = doc.id;
    if (club.status === 'rejected') continue;
    const ts = new Date().toISOString();
    const lock = buildLock({ seriesId, clubId, seriesName, ts });
    const members = await firestore.collection('series_memberships')
      .where('seriesId', '==', seriesId).where('clubId', '==', clubId).get();
    const active = members.docs.map((d) => d.data()).filter((m) => m.status === 'active');
    if (club.linkedTeamId) {
      const tSnap = await firestore.collection('teams').doc(club.linkedTeamId).get();
      if (!tSnap.exists) {
        out.skipped.push({ clubId, reason: 'linked team missing' });
        continue;
      }
      const team = tSnap.data();
      if (team.orgLock?.clubId === clubId) {
        out.alreadyLinked += 1;
        continue;
      }
      try {
        validateLinkTarget({ team, uid: club.createdBy, lockClub: await readLockClub(firestore, team) });
      } catch (err) {
        out.skipped.push({ clubId, teamId: club.linkedTeamId, reason: err.message });
        continue;
      }
      await lockTeam(firestore, club.linkedTeamId, lock);
      for (const m of active) {
        await addMemberToLinkedTeam(firestore, { clubId, userId: m.userId, playerDocId: m.playerDocId });
      }
      out.locked += 1;
    } else {
      const pids = [];
      for (const m of active) {
        const pid = await resolvePlayerDocId(firestore, m);
        if (pid && !pids.includes(pid)) pids.push(pid);
      }
      const teamId = await createTeamForClub(firestore, {
        name: club.name, createdBy: club.createdBy, playerIds: pids, lock, ts,
      });
      await doc.ref.update({ linkedTeamId: teamId, updatedAt: ts });
      out.created += 1;
    }
  }
  return out;
}

module.exports = {
  OrgTeamLinkError,
  formatTeamCode,
  lockIsLive,
  validateLinkTarget,
  buildServerTeam,
  buildLock,
  readLockClub,
  createTeamForClub,
  lockTeam,
  unlockTeamForClub,
  addMemberToLinkedTeam,
  removeMemberFromLinkedTeam,
  migrateSeriesTeams,
};
