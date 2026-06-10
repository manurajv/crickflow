const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore } = require('firebase-admin/firestore');
const {
  collectPlayerAggFromEvents,
  deriveInningsList,
  verifyMatchProjection,
} = require('../utils/ballEventStats');
const {
  resolveBallType,
  applyPlayerStats,
  applyPlayerHighScores,
} = require('../utils/stats');

const db = getFirestore();

async function assertMatchAdmin(uid, match) {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  if (match.createdBy === uid) return;
  if ((match.scorerIds || []).includes(uid)) return;

  const userSnap = await db.collection('users').doc(uid).get();
  const role = userSnap.data()?.role;
  if (role === 'organizer') return;

  throw new HttpsError('permission-denied', 'Organizer or match scorer only');
}

async function loadMatchAndEvents(matchId) {
  if (!matchId) {
    throw new HttpsError('invalid-argument', 'matchId is required');
  }
  const matchRef = db.collection('matches').doc(matchId);
  const matchSnap = await matchRef.get();
  if (!matchSnap.exists) {
    throw new HttpsError('not-found', 'Match not found');
  }
  const eventsSnap = await matchRef
    .collection('ball_events')
    .orderBy('sequence')
    .get();
  const events = eventsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  return { match: matchSnap.data(), matchRef, events };
}

/**
 * Returns projection vs replay mismatches for a match (admin QA).
 */
exports.adminVerifyMatchIntegrity = onCall(async (request) => {
  const { matchId } = request.data || {};
  const { match, events } = await loadMatchAndEvents(matchId);
  await assertMatchAdmin(request.auth?.uid, match);

  const issues =
    events.length > 0 ? verifyMatchProjection(match, events) : [];

  return {
    matchId,
    eventCount: events.length,
    issueCount: issues.length,
    issues,
    statsSource: events.length > 0 ? 'ball_events' : 'innings_cache',
  };
});

/**
 * Preview career stat increments from ball_events (does not write).
 */
exports.adminPreviewMatchStatsFromEvents = onCall(async (request) => {
  const { matchId } = request.data || {};
  const { match, events } = await loadMatchAndEvents(matchId);
  await assertMatchAdmin(request.auth?.uid, match);

  if (events.length === 0) {
    throw new HttpsError(
      'failed-precondition',
      'No ball_events — cannot preview event-derived stats',
    );
  }

  const agg = collectPlayerAggFromEvents(match, events);
  const players = {};
  for (const [playerId, stats] of agg.entries()) {
    players[playerId] = stats;
  }

  return {
    matchId,
    eventCount: events.length,
    ballType: resolveBallType(match.rules),
    players,
    derivedInnings: deriveInningsList(match, events),
  };
});

/**
 * Re-apply player stats from ball_events for a completed match.
 * Only when statsProcessed is false (failed/partial completion) to avoid double-count.
 */
exports.adminReprocessMatchStats = onCall(async (request) => {
  const { matchId, force } = request.data || {};
  const { match, matchRef, events } = await loadMatchAndEvents(matchId);
  await assertMatchAdmin(request.auth?.uid, match);

  if (match.status !== 'completed') {
    throw new HttpsError(
      'failed-precondition',
      'Match must be completed',
    );
  }
  if (match.statsProcessed === true && force !== true) {
    throw new HttpsError(
      'failed-precondition',
      'Stats already processed. Pass force:true only after manual stat rollback.',
    );
  }
  if (events.length === 0) {
    throw new HttpsError(
      'failed-precondition',
      'No ball_events to aggregate',
    );
  }

  const playerAgg = collectPlayerAggFromEvents(match, events);
  const ballType = resolveBallType(match.rules);
  const batch = db.batch();
  applyPlayerStats(batch, db, playerAgg, ballType);
  batch.update(matchRef, {
    statsProcessed: true,
    statsSource: 'ball_events',
    statsReprocessedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });
  await batch.commit();
  await applyPlayerHighScores(db, playerAgg, ballType);

  return {
    matchId,
    playersUpdated: playerAgg.size,
    statsSource: 'ball_events',
  };
});
