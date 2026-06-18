const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const { fanOutMatchNotification } = require('../utils/fanOut');
const {
  buildMatchStartNotification,
  buildSecondInningsStartNotification,
  buildFirstInningsCompleteNotification,
} = require('../utils/notificationBuilder');

const db = getFirestore();

/**
 * Match status transitions — match start, first innings complete, second innings start.
 */
exports.onMatchLive = onDocumentUpdated('matches/{matchId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;

  const matchId = event.params.matchId;

  // First innings complete
  if (before.status === 'live' && after.status === 'inningsBreak') {
    const built = buildFirstInningsCompleteNotification(after);
    await fanOutMatchNotification(
      db,
      matchId,
      after,
      built,
      'first_innings_complete',
    );
    return;
  }

  if (before.status === 'live' || after.status !== 'live') return;

  if (before.status === 'inningsBreak') {
    const built = buildSecondInningsStartNotification(after);
    await fanOutMatchNotification(
      db,
      matchId,
      after,
      built,
      'second_innings_started',
    );
    return;
  }

  const built = buildMatchStartNotification(after);
  await fanOutMatchNotification(db, matchId, after, built, 'match_started');
});
