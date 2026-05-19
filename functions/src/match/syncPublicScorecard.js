const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const db = () => getFirestore();

function sanitizeStream(stream) {
  if (!stream) return { status: 'idle' };
  return {
    status: stream.status || 'idle',
    youtubeWatchUrl: stream.youtubeWatchUrl || null,
    secondaryYoutubeWatchUrl: stream.secondaryYoutubeWatchUrl || null,
    cameraALabel: stream.cameraALabel || 'Main camera',
    cameraBLabel: stream.cameraBLabel || 'Camera 2',
    startedAt: stream.startedAt || null,
    webrtcEnabled: stream.webrtcEnabled === true,
  };
}

function sanitizeInnings(innings) {
  if (!Array.isArray(innings)) return [];
  return innings.map((inn) => ({
    inningsNumber: inn.inningsNumber,
    status: inn.status,
    totalRuns: inn.totalRuns ?? 0,
    totalWickets: inn.totalWickets ?? 0,
    legalBalls: inn.legalBalls ?? 0,
    batsmen: inn.batsmen ?? [],
    bowlers: inn.bowlers ?? [],
  }));
}

function buildPublicPayload(matchId, data) {
  return {
    matchId,
    title: data.title || 'CrickFlow Match',
    status: data.status || 'draft',
    teamAName: data.teamAName || '',
    teamBName: data.teamBName || '',
    venue: data.venue || '',
    location: data.location || {},
    rules: {
      ballsPerOver: data.rules?.ballsPerOver ?? 6,
    },
    innings: sanitizeInnings(data.innings),
    stream: sanitizeStream(data.stream),
    resultSummary: data.resultSummary || '',
    updatedAt: FieldValue.serverTimestamp(),
  };
}

/**
 * Public web scorecard — no stream keys or RTMP secrets.
 */
exports.syncPublicScorecard = onDocumentWritten(
  'matches/{matchId}',
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;

    const matchId = event.params.matchId;
    await db()
      .collection('matches')
      .doc(matchId)
      .collection('public')
      .doc('scorecard')
      .set(buildPublicPayload(matchId, after), { merge: true });
  },
);

exports.syncPublicOverlay = onDocumentWritten(
  'matches/{matchId}/overlay/{docId}',
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;

    const matchId = event.params.matchId;
    await db()
      .collection('matches')
      .doc(matchId)
      .collection('public')
      .doc('scorecard')
      .set(
        {
          overlay: after,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  },
);
