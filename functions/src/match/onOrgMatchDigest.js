const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const {
  buildMatchDigest,
  isDigestMatch,
  digestFingerprint,
  DIGEST_VERSION,
} = require('../series/orgMatchDigest');

const DIGESTS = 'series_match_digests';

async function fetchBallEvents(firestore, matchId) {
  const snap = await firestore
    .collection('matches')
    .doc(matchId)
    .collection('ball_events')
    .orderBy('sequence')
    .get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

/**
 * Write (or refresh) the digest of one finished org match. Returns 'written',
 * 'removed' or 'skipped'.
 */
async function syncMatchDigest(firestore, matchId, match) {
  const ref = firestore.collection(DIGESTS).doc(matchId);
  if (!isDigestMatch(match)) {
    const existing = await ref.get();
    if (existing.exists) {
      await ref.delete();
      return 'removed';
    }
    return 'skipped';
  }
  const events = await fetchBallEvents(firestore, matchId);
  const digest = buildMatchDigest(match, events);
  await ref.set({
    seriesId: match.seriesId,
    matchId,
    tournamentId: match.tournamentId || null,
    status: match.status,
    fingerprint: digestFingerprint(match),
    ...digest,
    updatedAt: new Date().toISOString(),
  });
  return 'written';
}

/** Re-sync every org match of a series (backfill / repair). */
async function rebuildSeriesDigests(firestore, seriesId) {
  const snap = await firestore.collection('matches').where('seriesId', '==', seriesId).get();
  const out = { written: 0, removed: 0, skipped: 0, version: DIGEST_VERSION };
  for (const doc of snap.docs) {
    const result = await syncMatchDigest(firestore, doc.id, doc.data());
    out[result] += 1;
  }
  return out;
}

/**
 * Keeps series_match_digests in step with finished org matches: written when a
 * match finishes (or is approved after finishing, or its innings are
 * corrected), removed if it stops counting.
 */
exports.onOrgMatchDigest = onDocumentWritten('matches/{matchId}', async (event) => {
  const before = event.data.before?.data();
  const after = event.data.after?.data();
  const matchId = event.params.matchId;
  const firestore = getFirestore();
  try {
    if (!after) {
      if (before?.seriesId) await syncMatchDigest(firestore, matchId, null);
      return;
    }
    const counts = isDigestMatch(after);
    const counted = isDigestMatch(before);
    if (!counts && !counted) return;
    if (counts && counted && digestFingerprint(before) === digestFingerprint(after)) return;
    await syncMatchDigest(firestore, matchId, after);
  } catch (err) {
    console.error('org match digest failed', matchId, err);
  }
});

exports.syncMatchDigest = syncMatchDigest;
exports.rebuildSeriesDigests = rebuildSeriesDigests;
