const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const { resolvePolicy } = require('../series/seriesCompetitionOps');
const walkIns = require('../series/orgWalkIns');

const FINISHED = new Set(['completed', 'abandoned']);

function squadsChanged(before, after) {
  return walkIns.SQUAD_KEYS.some(
    (key) => JSON.stringify(before[key] || []) !== JSON.stringify(after[key] || []),
  );
}

/**
 * The org a match belongs to: its own seriesId, or the org of the tournament
 * it is played in (tournament matches only get seriesId stamped at the end).
 */
async function orgSeriesIdOf(firestore, match) {
  if (match.seriesId) return match.seriesId;
  if (!match.tournamentId) return null;
  const t = await firestore.collection('tournaments').doc(match.tournamentId).get();
  const data = t.exists ? t.data() : null;
  if (!data || !data.seriesId || data.seriesOfficialStatus === 'rejected') return null;
  return data.seriesId;
}

/**
 * Org setting allowWalkIns = false: any squad edit that adds a walk-in /
 * guest player to an org match (or org tournament match) is rolled back.
 * Players who already batted, bowled or fielded stay so scoring is never
 * corrupted. Changing the setting does not rewrite existing squads.
 */
async function enforceOrgWalkIns(matchId, before, after, firestore = getFirestore()) {
  if (!before || !after) return null;
  if (!after.seriesId && !after.tournamentId) return null;
  if (after.seriesId && after.seriesOfficialStatus === 'rejected') return null;
  if (FINISHED.has(after.status)) return null;
  if (!squadsChanged(before, after)) return null;

  const seriesId = await orgSeriesIdOf(firestore, after);
  if (!seriesId) return null;
  const seriesSnap = await firestore.collection('series').doc(seriesId).get();
  if (!seriesSnap.exists) return null;
  if (resolvePolicy(seriesSnap.data()).allowWalkIns) return null;

  const ids = walkIns.rosterPlayerIdsToCheck(after);
  const userIds = new Map();
  for (let i = 0; i < ids.length; i += 100) {
    const refs = ids.slice(i, i + 100).map((id) => firestore.collection('players').doc(id));
    for (const snap of await firestore.getAll(...refs)) {
      if (snap.exists) userIds.set(snap.id, String(snap.data()?.userId || ''));
    }
  }
  const found = walkIns.findWalkIns(after, userIds);
  if (!found.length) return null;
  const { patch, removed } = walkIns.stripWalkInsPatch(after, found);
  if (!patch) return null;

  const ts = new Date().toISOString();
  await firestore.collection('matches').doc(matchId).update({
    ...patch,
    orgWalkInsRemoved: removed.map((w) => w.name || w.id),
    orgWalkInsRemovedAt: ts,
    updatedAt: ts,
  });
  return removed;
}

exports.enforceOrgWalkIns = enforceOrgWalkIns;
exports.onOrgMatchSquad = onDocumentUpdated('matches/{matchId}', async (event) => {
  await enforceOrgWalkIns(
    event.params.matchId,
    event.data?.before?.data(),
    event.data?.after?.data(),
  );
});
