const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { notifyMatchTopic } = require('../utils/messaging');

/**
 * Notify subscribers when a match goes live.
 */
exports.onMatchLive = onDocumentUpdated('matches/{matchId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;

  if (before.status === 'live' || after.status !== 'live') return;

  const matchId = event.params.matchId;
  const title = after.title || 'CrickFlow Match';
  await notifyMatchTopic(matchId, 'Match is LIVE', `${title} has started`, {
    status: 'live',
  });
});
