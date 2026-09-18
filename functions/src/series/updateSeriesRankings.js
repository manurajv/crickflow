/**
 * Series rankings — independent of global players.stats / tournaments.pointsTable.
 * Called from onMatchCompleted only when match is an official Series match.
 */

function clubRankingDocId(seriesId, clubId) {
  return `${seriesId}_${clubId}`;
}

function playerRankingDocId(seriesId, userId) {
  return `${seriesId}_${userId}`;
}

function isOfficialSeriesMatch(match) {
  if (!match?.seriesId) return false;
  if (match.seriesOfficialStatus !== 'approved') return false;
  if (match.seriesRankingsProcessed === true) return false;
  // Must be completed (caller already checks).
  return true;
}

async function ensureClubRow(db, seriesId, clubId, clubName, batch) {
  const id = clubRankingDocId(seriesId, clubId);
  const ref = db.collection('series_club_rankings').doc(id);
  const snap = await ref.get();
  if (!snap.exists) {
    batch.set(ref, {
      seriesId,
      clubId,
      clubName: clubName || '',
      played: 0,
      won: 0,
      lost: 0,
      tied: 0,
      noResult: 0,
      points: 0,
      netRunRate: 0,
      runDifference: 0,
      bonusPoints: 0,
      updatedAt: new Date().toISOString(),
    });
  }
  return ref;
}

/**
 * Update Series club + player rankings for one completed official Series match.
 * Counts the match once even if it also belongs to a tournament.
 */
async function updateSeriesRankings(db, match) {
  if (!isOfficialSeriesMatch(match)) return;

  const seriesId = match.seriesId;
  const seriesSnap = await db.collection('series').doc(seriesId).get();
  if (!seriesSnap.exists) return;
  const series = seriesSnap.data();
  const rules = series.settings?.rankingRules || {};
  const winPts = rules.winPoints ?? 2;
  const lossPts = rules.lossPoints ?? 0;
  const tiePts = rules.tiePoints ?? 1;
  const nrPts = rules.noResultPoints ?? 1;

  const clubA = match.seriesClubAId;
  const clubB = match.seriesClubBId;
  if (!clubA || !clubB) {
    // Still mark processed to avoid retries without club refs.
    await db.collection('matches').doc(match.id).set({
      seriesRankingsProcessed: true,
    }, { merge: true });
    return;
  }

  const batch = db.batch();
  const refA = await ensureClubRow(db, seriesId, clubA, match.teamAName, batch);
  const refB = await ensureClubRow(db, seriesId, clubB, match.teamBName, batch);

  const snapA = await refA.get();
  const snapB = await refB.get();
  const rowA = snapA.exists ? snapA.data() : {
    played: 0, won: 0, lost: 0, tied: 0, noResult: 0, points: 0, netRunRate: 0,
  };
  const rowB = snapB.exists ? snapB.data() : {
    played: 0, won: 0, lost: 0, tied: 0, noResult: 0, points: 0, netRunRate: 0,
  };

  const winner = match.winnerTeamId;
  const summary = (match.resultSummary || '').toLowerCase();
  const isAbandoned = summary.includes('no result') || summary.includes('abandoned');
  const isTie = !isAbandoned && (!winner || summary.includes('tie'));

  const applyClub = (row, outcome) => {
    const next = { ...row, played: (row.played || 0) + 1 };
    if (outcome === 'win') {
      next.won = (row.won || 0) + 1;
      next.points = (row.points || 0) + winPts;
    } else if (outcome === 'loss') {
      next.lost = (row.lost || 0) + 1;
      next.points = (row.points || 0) + lossPts;
    } else if (outcome === 'tie') {
      next.tied = (row.tied || 0) + 1;
      next.points = (row.points || 0) + tiePts;
    } else {
      next.noResult = (row.noResult || 0) + 1;
      next.points = (row.points || 0) + nrPts;
    }
    next.updatedAt = new Date().toISOString();
    return next;
  };

  let nextA;
  let nextB;
  if (isAbandoned) {
    nextA = applyClub(rowA, 'nr');
    nextB = applyClub(rowB, 'nr');
  } else if (isTie) {
    nextA = applyClub(rowA, 'tie');
    nextB = applyClub(rowB, 'tie');
  } else if (winner === match.teamAId) {
    nextA = applyClub(rowA, 'win');
    nextB = applyClub(rowB, 'loss');
  } else if (winner === match.teamBId) {
    nextA = applyClub(rowA, 'loss');
    nextB = applyClub(rowB, 'win');
  } else {
    nextA = applyClub(rowA, 'nr');
    nextB = applyClub(rowB, 'nr');
  }

  batch.set(refA, {
    seriesId,
    clubId: clubA,
    clubName: match.teamAName || rowA.clubName || '',
    ...nextA,
  }, { merge: true });
  batch.set(refB, {
    seriesId,
    clubId: clubB,
    clubName: match.teamBName || rowB.clubName || '',
    ...nextB,
  }, { merge: true });

  // Lightweight player Series stats from innings cache (independent of career stats).
  const innings = match.innings || [];
  for (const inn of innings) {
    for (const bat of inn.batsmen || []) {
      const userId = bat.playerId || bat.userId;
      if (!userId) continue;
      const pref = db.collection('series_player_rankings')
        .doc(playerRankingDocId(seriesId, userId));
      const pSnap = await pref.get();
      const prev = pSnap.exists ? pSnap.data() : {};
      const runs = bat.runs || 0;
      const balls = bat.balls || bat.ballsFaced || 0;
      batch.set(pref, {
        seriesId,
        userId,
        playerDocId: bat.playerId || null,
        displayName: bat.name || prev.displayName || '',
        matches: (prev.matches || 0) + 1,
        innings: (prev.innings || 0) + 1,
        runs: (prev.runs || 0) + runs,
        highestScore: Math.max(prev.highestScore || 0, runs),
        ballsFaced: (prev.ballsFaced || 0) + balls,
        fours: (prev.fours || 0) + (bat.fours || 0),
        sixes: (prev.sixes || 0) + (bat.sixes || 0),
        thirties: (prev.thirties || 0) + (runs >= 30 && runs < 50 ? 1 : 0),
        fifties: (prev.fifties || 0) + (runs >= 50 && runs < 100 ? 1 : 0),
        hundreds: (prev.hundreds || 0) + (runs >= 100 ? 1 : 0),
        updatedAt: new Date().toISOString(),
      }, { merge: true });
    }
    for (const bowl of inn.bowlers || []) {
      const userId = bowl.playerId || bowl.userId;
      if (!userId) continue;
      const pref = db.collection('series_player_rankings')
        .doc(playerRankingDocId(seriesId, userId));
      const pSnap = await pref.get();
      const prev = pSnap.exists ? pSnap.data() : {};
      const wkts = bowl.wickets || 0;
      const runsConceded = bowl.runs || bowl.runsConceded || 0;
      batch.set(pref, {
        seriesId,
        userId,
        displayName: bowl.name || prev.displayName || '',
        bowlingMatches: (prev.bowlingMatches || 0) + 1,
        oversBowled: (prev.oversBowled || 0) + (bowl.overs || 0),
        bowlingRuns: (prev.bowlingRuns || 0) + runsConceded,
        wickets: (prev.wickets || 0) + wkts,
        maidens: (prev.maidens || 0) + (bowl.maidens || 0),
        bestBowling: prev.bestBowling || `${wkts}/${runsConceded}`,
        updatedAt: new Date().toISOString(),
      }, { merge: true });
    }
  }

  const matchRef = db.collection('matches').doc(match.id);
  batch.set(matchRef, { seriesRankingsProcessed: true }, { merge: true });
  await batch.commit();
}

module.exports = { updateSeriesRankings, isOfficialSeriesMatch };
