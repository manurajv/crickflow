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

async function updateTournamentStandings(db, tournamentId, match) {
  if (!tournamentId) return;

  const tRef = db.collection('tournaments').doc(tournamentId);
  const tSnap = await tRef.get();
  if (!tSnap.exists) return;

  const data = tSnap.data();
  const table = [...(data.pointsTable || [])];
  const rules = match.rules || {};
  const ballsPerOver = rules.ballsPerOver || 6;
  const winPts = rules.pointsPerWin ?? 2;
  const tiePts = rules.pointsPerTie ?? 1;
  const lossPts = rules.pointsPerLoss ?? 0;

  const teamA = match.teamAId;
  const teamB = match.teamBId;
  const winner = match.winnerTeamId;
  const isTie =
    !winner || (match.resultSummary || '').toLowerCase().includes('tie');
  const innings = match.innings || [];

  function bump(teamId, teamName, won, lost, tied) {
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
        points: 0,
        netRunRate: 0,
      };
      table.push(row);
    }
    row.played += 1;
    if (tied) {
      row.tied += 1;
      row.points += tiePts;
    } else if (won) {
      row.won += 1;
      row.points += winPts;
    } else if (lost) {
      row.lost += 1;
      row.points += lossPts;
    }

    const delta = matchNrrDelta(innings, teamId, ballsPerOver);
    row.netRunRate = parseFloat(((row.netRunRate || 0) + delta).toFixed(3));
  }

  if (teamA && teamB) {
    if (isTie) {
      bump(teamA, match.teamAName, false, false, true);
      bump(teamB, match.teamBName, false, false, true);
    } else {
      bump(teamA, match.teamAName, winner === teamA, winner === teamB, false);
      bump(teamB, match.teamBName, winner === teamB, winner === teamA, false);
    }
  }

  table.sort((a, b) => {
    if (b.points !== a.points) return b.points - a.points;
    return (b.netRunRate || 0) - (a.netRunRate || 0);
  });

  await tRef.update({
    pointsTable: table,
    updatedAt: new Date().toISOString(),
  });
}

module.exports = { updateTournamentStandings, matchNrrDelta };
