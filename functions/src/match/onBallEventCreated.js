const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { notifyMatchTopic } = require('../utils/messaging');

/**
 * Push FCM for highlights and persist highlight docs for analytics.
 */
exports.onBallEventCreated = onDocumentCreated(
  'matches/{matchId}/ball_events/{eventId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const matchId = event.params.matchId;
    const eventId = event.params.eventId;
    const type = data.eventType;
    const runs = data.runs || 0;

    let title = null;
    let highlightTag = null;
    let body = data.commentary || '';

    if (type === 'wicket') {
      title = 'WICKET!';
      highlightTag = 'wicket';
      body = body || 'Wicket fallen';
    } else if (runs >= 6) {
      title = 'SIX!';
      highlightTag = 'six';
      body = body || 'Maximum!';
    } else if (runs === 4) {
      title = 'FOUR!';
      highlightTag = 'four';
      body = body || 'Boundary';
    }

    if (!title) return;

    const db = getFirestore();
    await db
      .collection('matches')
      .doc(matchId)
      .collection('highlights')
      .doc(eventId)
      .set({
        eventId,
        matchId,
        highlightTag,
        eventType: type,
        runs,
        commentary: body,
        inningsNumber: data.inningsNumber || 1,
        overNumber: data.overNumber || 0,
        ballInOver: data.ballInOver || 0,
        sequence: data.sequence || 0,
        timestamp: data.timestamp || new Date().toISOString(),
        createdAt: FieldValue.serverTimestamp(),
      });

    await notifyMatchTopic(matchId, title, body, {
      eventType: type,
      sequence: String(data.sequence || ''),
    });
  },
);
