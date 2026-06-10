const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { evaluateInningsBadges, pickMatchHero } = require('../utils/badges');
const { updateTournamentStandings } = require('../utils/tournament');
const { notifyMatchTopic, createUserNotification } = require('../utils/messaging');
const {
  resolveBallType,
  applyPlayerStats,
  applyPlayerHighScores,
  collectPlayerAgg,
  applyTeamResult,
} = require('../utils/stats');
const {
  collectPlayerAggFromEvents,
  deriveInningsList,
} = require('../utils/ballEventStats');

const db = getFirestore();

async function fetchBallEvents(matchId) {
  const snap = await db
    .collection('matches')
    .doc(matchId)
    .collection('ball_events')
    .orderBy('sequence')
    .get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

exports.onMatchCompleted = onDocumentUpdated(
  'matches/{matchId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    if (before.status === 'completed' || after.status !== 'completed') return;
    if (after.statsProcessed === true) return;

    const matchId = event.params.matchId;
    const ballEvents = await fetchBallEvents(matchId);

    const useEvents = ballEvents.length > 0;
    const playerAgg = useEvents
      ? collectPlayerAggFromEvents(after, ballEvents)
      : collectPlayerAgg(after.innings || []);

    const derivedInnings = useEvents
      ? deriveInningsList(after, ballEvents)
      : after.innings || [];

    const ballType = resolveBallType(after.rules);
    const batch = db.batch();
    applyPlayerStats(batch, db, playerAgg, ballType);

    const winner = after.winnerTeamId;
    const teamA = after.teamAId;
    const teamB = after.teamBId;

    if (teamA && teamB) {
      if (winner) {
        applyTeamResult(batch, db, winner, { won: true, lost: false, tied: false });
        const loser = winner === teamA ? teamB : teamA;
        applyTeamResult(batch, db, loser, { won: false, lost: true, tied: false });
      }
    }

    const allBadges = [];
    for (const inn of derivedInnings) {
      allBadges.push(...evaluateInningsBadges(matchId, inn));
    }

    for (const badge of allBadges) {
      const badgeRef = db.collection('badges').doc(badge.id);
      batch.set(badgeRef, badge, { merge: true });
      if (badge.playerId) {
        const playerRef = db.collection('players').doc(badge.playerId);
        batch.set(
          playerRef,
          { badgeIds: FieldValue.arrayUnion(badge.id) },
          { merge: true },
        );
      }
    }

    const hero =
      after.matchHero ||
      pickMatchHero({ ...after, innings: derivedInnings });
    const badgeIds = allBadges.map((b) => b.id);

    batch.update(event.data.after.ref, {
      statsProcessed: true,
      badgeIds,
      matchHero: hero,
      playerOfMatchId: hero?.playerId || after.playerOfMatchId || null,
      statsSource: useEvents ? 'ball_events' : 'innings_cache',
      updatedAt: new Date().toISOString(),
    });

    await batch.commit();
    await applyPlayerHighScores(db, playerAgg, ballType);

    if (after.tournamentId) {
      await updateTournamentStandings(db, after.tournamentId, after);
    }

    const summary = after.resultSummary || 'Match completed';
    await notifyMatchTopic(matchId, 'Match finished', summary, {
      status: 'completed',
    });

    if (after.createdBy) {
      await createUserNotification(db, after.createdBy, {
        title: 'Match completed',
        body: summary,
        matchId,
      });
    }

    console.log(
      `Processed match ${matchId}: ${allBadges.length} badges, stats from ${useEvents ? 'ball_events' : 'innings'}`,
    );
  },
);
