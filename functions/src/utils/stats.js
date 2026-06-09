const { FieldValue } = require('firebase-admin/firestore');

function resolveBallType(rules) {
  if (!rules) return 'leather';
  if (rules.ballType) return rules.ballType;
  if (rules.format === 'tennis') return 'tennis';
  if (rules.format === 'custom') return 'indoor';
  return 'leather';
}

function statsIncrements(agg, matchesDelta = 1) {
  return {
    runs: FieldValue.increment(agg.runs || 0),
    ballsFaced: FieldValue.increment(agg.ballsFaced || 0),
    fours: FieldValue.increment(agg.fours || 0),
    sixes: FieldValue.increment(agg.sixes || 0),
    wickets: FieldValue.increment(agg.wickets || 0),
    oversBowledBalls: FieldValue.increment(agg.oversBowledBalls || 0),
    runsConceded: FieldValue.increment(agg.runsConceded || 0),
    matchesPlayed: FieldValue.increment(matchesDelta),
    inningsPlayed: FieldValue.increment(agg.inningsPlayed || 0),
    dismissals: FieldValue.increment(agg.dismissals || 0),
    ducks: FieldValue.increment(agg.ducks || 0),
    thirties: FieldValue.increment(agg.thirties || 0),
    fifties: FieldValue.increment(agg.fifties || 0),
    hundreds: FieldValue.increment(agg.hundreds || 0),
    threeWickets: FieldValue.increment(agg.threeWickets || 0),
    fiveWickets: FieldValue.increment(agg.fiveWickets || 0),
    catches: FieldValue.increment(agg.catches || 0),
    runOuts: FieldValue.increment(agg.runOuts || 0),
    stumpings: FieldValue.increment(agg.stumpings || 0),
  };
}

/**
 * Aggregate player stats once per player per completed match.
 */
function applyPlayerStats(batch, db, playerAgg, ballType) {
  const prefix = `statsByBallType.${ballType}`;
  for (const [playerId, agg] of playerAgg.entries()) {
    if (!playerId || playerId.startsWith('guest_')) continue;
    const ref = db.collection('players').doc(playerId);
    const typed = {};
    for (const [key, value] of Object.entries(statsIncrements(agg))) {
      typed[`${prefix}.${key}`] = value;
    }
    batch.set(
      ref,
      {
        stats: statsIncrements(agg),
        ...typed,
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
  }
}

/** Update career high score (overall + per ball type). */
async function applyPlayerHighScores(db, playerAgg, ballType) {
  for (const [playerId, agg] of playerAgg.entries()) {
    if (!playerId || playerId.startsWith('guest_') || !agg.highScore) continue;
    const ref = db.collection('players').doc(playerId);
    const snap = await ref.get();
    const data = snap.data() || {};
    const curOverall = data.stats?.highScore || 0;
    const curTyped = data.statsByBallType?.[ballType]?.highScore || 0;
    const patch = { updatedAt: new Date().toISOString() };
    if (agg.highScore > curOverall) {
      patch.stats = { highScore: agg.highScore };
    }
    if (agg.highScore > curTyped) {
      patch[`statsByBallType.${ballType}.highScore`] = agg.highScore;
    }
    if (patch.stats || patch[`statsByBallType.${ballType}.highScore`]) {
      await ref.set(patch, { merge: true });
    }
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
        inningsPlayed: 0,
        dismissals: 0,
        ducks: 0,
        thirties: 0,
        fifties: 0,
        hundreds: 0,
        highScore: 0,
        threeWickets: 0,
        fiveWickets: 0,
        catches: 0,
        runOuts: 0,
        stumpings: 0,
        matchWickets: 0,
      });
    }
    return map.get(id);
  }

  for (const inn of innings) {
    for (const b of inn.batsmen || []) {
      if (!b.playerId) continue;
      const a = get(b.playerId);
      const runs = b.runs || 0;
      a.runs += runs;
      a.ballsFaced += b.balls || 0;
      a.fours += b.fours || 0;
      a.sixes += b.sixes || 0;
      a.inningsPlayed += 1;
      if (b.isOut) a.dismissals += 1;
      if (b.isOut && runs === 0) a.ducks += 1;
      if (runs >= 100) a.hundreds += 1;
      else if (runs >= 50) a.fifties += 1;
      else if (runs >= 30) a.thirties += 1;
      a.highScore = Math.max(a.highScore, runs);
    }
    for (const bowler of inn.bowlers || []) {
      if (!bowler.playerId) continue;
      const a = get(bowler.playerId);
      const wkts = bowler.wickets || 0;
      a.wickets += wkts;
      a.oversBowledBalls += bowler.oversBowledBalls || 0;
      a.runsConceded += bowler.runsConceded || 0;
      a.matchWickets += wkts;
    }
    for (const fielder of inn.fielders || []) {
      if (!fielder.playerId) continue;
      const a = get(fielder.playerId);
      a.catches += fielder.catches || 0;
      a.runOuts += fielder.runOuts || 0;
      a.stumpings += fielder.stumpings || 0;
    }
  }

  for (const a of map.values()) {
    if (a.matchWickets >= 5) a.fiveWickets += 1;
    else if (a.matchWickets >= 3) a.threeWickets += 1;
    delete a.matchWickets;
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
  resolveBallType,
  applyPlayerStats,
  applyPlayerHighScores,
  collectPlayerAgg,
  applyTeamResult,
};
