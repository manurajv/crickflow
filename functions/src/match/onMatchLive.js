const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const { fanOutMatchNotification } = require('../utils/fanOut');
const {
  buildMatchStartNotification,
  buildSecondInningsStartNotification,
  buildFirstInningsCompleteNotification,
} = require('../utils/notificationBuilder');

const db = getFirestore();

async function withTournamentName(match) {
  if (match.tournamentName || !match.tournamentId) return match;
  try {
    const snap = await db.collection('tournaments').doc(match.tournamentId).get();
    if (snap.exists) {
      return { ...match, tournamentName: snap.data()?.name || null };
    }
  } catch (_) {
    // ignore
  }
  return match;
}

/**
 * Match status transitions — match start, first innings complete, second innings start.
 */
exports.onMatchLive = onDocumentUpdated('matches/{matchId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;

  const matchId = event.params.matchId;
  const match = await withTournamentName(after);

  // First innings complete
  if (before.status === 'live' && after.status === 'inningsBreak') {
    await fanOutMatchNotification(
      db,
      matchId,
      match,
      buildFirstInningsCompleteNotification(match),
      'first_innings_complete',
      {},
      {
        mode: 'lifecycle',
        category: 'match',
        tab: 'live',
        personalize: (ctx, life) =>
          buildFirstInningsCompleteNotification(
            match,
            life.perspective,
            life.actorName,
          ),
      },
    );
    return;
  }

  if (before.status === 'live' || after.status !== 'live') return;

  if (before.status === 'inningsBreak') {
    await fanOutMatchNotification(
      db,
      matchId,
      match,
      buildSecondInningsStartNotification(match),
      'second_innings_started',
      {},
      { category: 'match', tab: 'live' },
    );
    return;
  }

  await fanOutMatchNotification(
    db,
    matchId,
    match,
    buildMatchStartNotification(match),
    'match_started',
    {},
    {
      mode: 'lifecycle',
      category: 'match',
      tab: 'live',
      personalize: (ctx, life) =>
        buildMatchStartNotification(match, life.perspective, life.actorName),
    },
  );
});
