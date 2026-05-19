const { FieldValue } = require('firebase-admin/firestore');

/**
 * Aggregate player stats once per player per completed match.
 */
function applyPlayerStats(batch, db, playerAgg) {
  for (const [playerId, agg] of playerAgg.entries()) {
    if (!playerId || playerId.startsWith('guest_')) continue;
    const ref = db.collection('players').doc(playerId);
    batch.set(
      ref,
      {
        stats: {
          runs: FieldValue.increment(agg.runs),
          ballsFaced: FieldValue.increment(agg.ballsFaced),
          fours: FieldValue.increment(agg.fours),
          sixes: FieldValue.increment(agg.sixes),
          wickets: FieldValue.increment(agg.wickets),
          oversBowledBalls: FieldValue.increment(agg.oversBowledBalls),
          runsConceded: FieldValue.increment(agg.runsConceded),
          matchesPlayed: FieldValue.increment(1),
        },
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
  }
}

function collectPlayerAgg(innings) {
  const map = new Map();

  function get(id) {
    if (!map.has(id)) {
      map.set(id, {
        runs: 0,
        ballsFaced: 0,
        fours: 0,
        sixes: 0,
        wickets: 0,
        oversBowledBalls: 0,
        runsConceded: 0,
      });
    }
    return map.get(id);
  }

  for (const inn of innings) {
    for (const b of inn.batsmen || []) {
      if (!b.playerId) continue;
      const a = get(b.playerId);
      a.runs += b.runs || 0;
      a.ballsFaced += b.balls || 0;
      a.fours += b.fours || 0;
      a.sixes += b.sixes || 0;
    }
    for (const bowler of inn.bowlers || []) {
      if (!bowler.playerId) continue;
      const a = get(bowler.playerId);
      a.wickets += bowler.wickets || 0;
      a.oversBowledBalls += bowler.oversBowledBalls || 0;
      a.runsConceded += bowler.runsConceded || 0;
    }
  }

  return map;
}

function applyTeamResult(batch, db, teamId, { won, lost, tied, played = 1 }) {
  if (!teamId || teamId.startsWith('team_')) return;
  const ref = db.collection('teams').doc(teamId);
  const stats = { matchesPlayed: FieldValue.increment(played) };
  if (won) stats.matchesWon = FieldValue.increment(1);
  if (lost) stats.matchesLost = FieldValue.increment(1);
  if (tied) stats.matchesTied = FieldValue.increment(1);
  batch.set(ref, { stats, updatedAt: new Date().toISOString() }, { merge: true });
}

module.exports = {
  applyPlayerStats,
  collectPlayerAgg,
  applyTeamResult,
};
