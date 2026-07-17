/**
 * Tournament standings + net run rate (simplified T20 NRR).
 */

function oversFromBalls(balls, ballsPerOver) {
  if (!ballsPerOver || balls <= 0) return 0;
  const completed = Math.floor(balls / ballsPerOver);
  const rem = balls % ballsPerOver;
  return completed + rem / ballsPerOver;
}

function inningsForTeam(inningsList, teamId) {
  const batting = inningsList.find((inn) => inn.battingTeamId === teamId);
  const bowling = inningsList.find((inn) => inn.bowlingTeamId === teamId);
  return { batting, bowling };
}

/** Runs per over scored minus runs per over conceded in this match. */
function matchNrrDelta(inningsList, teamId, ballsPerOver = 6) {
  const { batting, bowling } = inningsForTeam(inningsList, teamId);
  if (!batting || !bowling) return 0;

  const oversFaced = oversFromBalls(batting.legalBalls || 0, ballsPerOver);
  const oversBowled = oversFromBalls(bowling.legalBalls || 0, ballsPerOver);
  const runsScored = batting.totalRuns || 0;
  const runsConceded = bowling.totalRuns || 0;

  const rpoScored = oversFaced > 0 ? runsScored / oversFaced : runsScored;
  const rpoConceded = oversBowled > 0 ? runsConceded / oversBowled : runsConceded;

  return rpoScored - rpoConceded;
}

/** Extract match-level run/over totals for a team. */
function matchRunsAndOvers(inningsList, teamId, ballsPerOver = 6, maxWickets = 10, totalOvers = 20) {
  const batting = inningsList.find((inn) => inn.battingTeamId === teamId);
  const bowling = inningsList.find((inn) => inn.bowlingTeamId === teamId);
  const runsFor = batting ? (batting.totalRuns || 0) : 0;
  const ballsFaced = batting ? (batting.legalBalls || 0) : 0;
  const runsAgainst = bowling ? (bowling.totalRuns || 0) : 0;
  const ballsBowled = bowling ? (bowling.legalBalls || 0) : 0;

  // ICC rule: if a team is all out, use full overs for NRR denominator.
  const battingAllOut = batting && (batting.totalWickets || 0) >= maxWickets;
  const bowlingAllOut = bowling && (bowling.totalWickets || 0) >= maxWickets;

  return {
    runsFor,
    oversFaced: battingAllOut ? totalOvers : oversFromBalls(ballsFaced, ballsPerOver),
    runsAgainst,
    oversBowled: bowlingAllOut ? totalOvers : oversFromBalls(ballsBowled, ballsPerOver),
  };
}

async function updateTournamentStandings(db, tournamentId, match) {
  if (!tournamentId) return;

  const tRef = db.collection('tournaments').doc(tournamentId);
  const tSnap = await tRef.get();
  if (!tSnap.exists) return;

  const data = tSnap.data();
  const table = [...(data.pointsTable || [])];
  const rules = match.rules || {};
  const ballsPerOver = rules.ballsPerOver || 6;
  const defaultRules = data.defaultRules || {};
  const winPts = defaultRules.pointsPerWin ?? rules.pointsPerWin ?? 2;
  const tiePts = defaultRules.pointsPerTie ?? rules.pointsPerTie ?? 1;
  const lossPts = defaultRules.pointsPerLoss ?? rules.pointsPerLoss ?? 0;
  const noResultPts = defaultRules.pointsPerNoResult ?? 1;

  const teamA = match.teamAId;
  const teamB = match.teamBId;
  const winner = match.winnerTeamId;
  const summary = (match.resultSummary || '').toLowerCase();
  const isAbandoned = match.status === 'abandoned' ||
    summary.includes('no result') || summary.includes('abandoned');
  const isTie = !isAbandoned &&
    (!winner || summary.includes('tie'));
  const innings = match.innings || [];
  const maxWickets = rules.maxWickets || 10;
  const totalOvers = rules.totalOvers || 20;

  function bump(teamId, teamName, won, lost, tied, noResult) {
    if (!teamId) return;
    let row = table.find((r) => r.teamId === teamId);
    if (!row) {
      row = {
        teamId,
        teamName: teamName || 'Team',
        played: 0,
        won: 0,
        lost: 0,
        tied: 0,
        noResult: 0,
        points: 0,
        netRunRate: 0,
        runsFor: 0,
        oversFaced: 0,
        runsAgainst: 0,
        oversBowled: 0,
        position: 0,
      };
      table.push(row);
    }
    row.played += 1;
    if (noResult) {
      row.noResult = (row.noResult || 0) + 1;
      row.points += noResultPts;
    } else if (tied) {
      row.tied += 1;
      row.points += tiePts;
    } else if (won) {
      row.won += 1;
      row.points += winPts;
    } else if (lost) {
      row.lost += 1;
      row.points += lossPts;
    }

    // Accumulate runs/overs for NRR sub-fields.
    const ro = matchRunsAndOvers(innings, teamId, ballsPerOver, maxWickets, totalOvers);
    row.runsFor = (row.runsFor || 0) + ro.runsFor;
    row.oversFaced = parseFloat(((row.oversFaced || 0) + ro.oversFaced).toFixed(4));
    row.runsAgainst = (row.runsAgainst || 0) + ro.runsAgainst;
    row.oversBowled = parseFloat(((row.oversBowled || 0) + ro.oversBowled).toFixed(4));

    // Compute NRR from cumulative values (proper formula).
    const cumulativeRpoFor = row.oversFaced > 0
      ? row.runsFor / row.oversFaced
      : 0;
    const cumulativeRpoAgainst = row.oversBowled > 0
      ? row.runsAgainst / row.oversBowled
      : 0;
    row.netRunRate = parseFloat((cumulativeRpoFor - cumulativeRpoAgainst).toFixed(3));
  }

  if (teamA && teamB) {
    if (isAbandoned) {
      bump(teamA, match.teamAName, false, false, false, true);
      bump(teamB, match.teamBName, false, false, false, true);
    } else if (isTie) {
      bump(teamA, match.teamAName, false, false, true, false);
      bump(teamB, match.teamBName, false, false, true, false);
    } else {
      bump(teamA, match.teamAName, winner === teamA, winner === teamB, false, false);
      bump(teamB, match.teamBName, winner === teamB, winner === teamA, false, false);
    }
  }

  // Sort by points DESC, then NRR DESC; assign positions.
  table.sort((a, b) => {
    if (b.points !== a.points) return b.points - a.points;
    return (b.netRunRate || 0) - (a.netRunRate || 0);
  });
  table.forEach((row, idx) => { row.position = idx + 1; });

  await tRef.update({
    pointsTable: table,
    updatedAt: new Date().toISOString(),
  });
}

module.exports = { updateTournamentStandings, matchNrrDelta };
