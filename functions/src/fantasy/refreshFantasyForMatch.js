const { getFirestore } = require('firebase-admin/firestore');
const { rawPlayerPoints, totalForEntry } = require('./fantasyPoints');

/**
 * Recalculates fantasy entry points when a ball is scored.
 */
async function refreshFantasyForMatch(matchId) {
  const db = getFirestore();

  const leaguesSnap = await db
    .collection('fantasy_leagues')
    .where('matchId', '==', matchId)
    .get();

  if (leaguesSnap.empty) return;

  const eventsSnap = await db
    .collection('matches')
    .doc(matchId)
    .collection('ball_events')
    .orderBy('sequence')
    .get();

  const events = eventsSnap.docs.map((d) => d.data());
  const raw = rawPlayerPoints(events);
  const now = new Date().toISOString();

  for (const leagueDoc of leaguesSnap.docs) {
    const league = leagueDoc.data();
    const entriesSnap = await leagueDoc.ref.collection('entries').get();
    if (entriesSnap.empty) continue;

    const batch = db.batch();
    for (const entryDoc of entriesSnap.docs) {
      const entry = entryDoc.data();
      if (!entry.playerIds || entry.playerIds.length === 0) continue;

      const total = totalForEntry(entry, league, raw);
      batch.update(entryDoc.ref, {
        totalPoints: total,
        updatedAt: now,
      });
    }
    await batch.commit();
  }
}

module.exports = { refreshFantasyForMatch };
