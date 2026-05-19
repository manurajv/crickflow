const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { evaluateInningsBadges, pickMatchHero } = require('../utils/badges');
const { updateTournamentStandings } = require('../utils/tournament');
const { notifyMatchTopic, createUserNotification } = require('../utils/messaging');
const {
  applyPlayerStats,
  applyPlayerHighScores,
  collectPlayerAgg,
  applyTeamResult,
} = require('../utils/stats');

const db = getFirestore();

exports.onMatchCompleted = onDocumentUpdated(
  'matches/{matchId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    if (before.status === 'completed' || after.status !== 'completed') return;
    if (after.statsProcessed === true) return;

    const matchId = event.params.matchId;
    const innings = after.innings || [];

    const batch = db.batch();
    const playerAgg = collectPlayerAgg(innings);
    applyPlayerStats(batch, db, playerAgg);

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
    for (const inn of innings) {
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

    const hero = after.matchHero || pickMatchHero(after);
    const badgeIds = allBadges.map((b) => b.id);

    batch.update(event.data.after.ref, {
      statsProcessed: true,
      badgeIds,
      matchHero: hero,
      playerOfMatchId: hero?.playerId || after.playerOfMatchId || null,
      updatedAt: new Date().toISOString(),
    });

    await batch.commit();
    await applyPlayerHighScores(db, playerAgg);

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

    console.log(`Processed match ${matchId}: ${allBadges.length} badges`);
  },
);
