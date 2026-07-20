const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const { fanOutMatchNotification } = require('../utils/fanOut');
const {
  buildMatchBreakStartedNotification,
  buildMatchBreakEndedNotification,
} = require('../utils/notificationBuilder');

const db = getFirestore();

/**
 * Match break start/end — notify followers when activeMatchBreak changes.
 */
exports.onMatchBreak = onDocumentUpdated('matches/{matchId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;

  const matchId = event.params.matchId;
  const beforeBreak = before.activeMatchBreak;
  const afterBreak = after.activeMatchBreak;

  const hadActive = beforeBreak && beforeBreak.status === 'active';
  const hasActive = afterBreak && afterBreak.status === 'active';

  if (!hadActive && hasActive) {
    const built = buildMatchBreakStartedNotification(after, afterBreak);
    await fanOutMatchNotification(
      db,
      matchId,
      after,
      built,
      'match_break_started',
      {},
      { category: 'match', tab: 'live' },
    );
    return;
  }

  if (hadActive && !hasActive) {
    const history = after.matchBreakHistory;
    const last =
      Array.isArray(history) && history.length > 0
        ? history[history.length - 1]
        : null;
    const built = buildMatchBreakEndedNotification(after, last);
    await fanOutMatchNotification(
      db,
      matchId,
      after,
      built,
      'match_break_ended',
      {},
      { category: 'match', tab: 'live' },
    );
  }
});
