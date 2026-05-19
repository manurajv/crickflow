const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { notifyMatchTopic } = require('../utils/messaging');

/**
 * Push highlights for wickets and boundaries (rate-limited by event type).
 */
exports.onBallEventCreated = onDocumentCreated(
  'matches/{matchId}/ball_events/{eventId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const matchId = event.params.matchId;
    const type = data.eventType;
    const runs = data.runs || 0;

    let title = null;
    let body = data.commentary || '';

    if (type === 'wicket') {
      title = 'WICKET!';
      body = body || 'Wicket fallen';
    } else if (runs === 6) {
      title = 'SIX!';
      body = body || 'Maximum!';
    } else if (runs === 4) {
      title = 'FOUR!';
      body = body || 'Boundary';
    }

    if (!title) return;

    await notifyMatchTopic(matchId, title, body, {
      eventType: type,
      sequence: String(data.sequence || ''),
    });
  },
);
