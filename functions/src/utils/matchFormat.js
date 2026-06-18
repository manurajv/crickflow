/**
 * Score / overs formatting for notification bodies.
 */

function ballsPerOver(match) {
  return match?.rules?.ballsPerOver || 6;
}

function totalOvers(match) {
  return match?.rules?.totalOvers || 20;
}

function formatOvers(legalBalls, bpo) {
  const balls = Math.max(0, legalBalls || 0);
  const perOver = bpo || 6;
  const overs = Math.floor(balls / perOver);
  const rem = balls % perOver;
  return `${overs}.${rem}`;
}

function teamName(match, teamId) {
  if (!teamId) return 'Team';
  if (teamId === match.teamAId) return match.teamAName || 'Team A';
  if (teamId === match.teamBId) return match.teamBName || 'Team B';
  return 'Team';
}

function battingTeamName(match, inn) {
  if (!inn) return 'Team';
  return teamName(match, inn.battingTeamId);
}

function currentInnings(match) {
  const innings = match.innings || [];
  if (innings.length === 0) return null;
  const idx =
    typeof match.currentInningsIndex === 'number'
      ? match.currentInningsIndex
      : innings.length - 1;
  return innings[idx] || innings[innings.length - 1];
}

function firstInnings(match) {
  return (match.innings || []).find((i) => i.inningsNumber === 1) || null;
}

function scoreLine(inn, bpo) {
  if (!inn) return '0/0 (0.0)';
  return `${inn.totalRuns || 0}/${inn.totalWickets || 0} (${formatOvers(
    inn.legalBalls,
    bpo,
  )})`;
}

function chaseTarget(match, inn) {
  if (!inn) return 0;
  if (inn.targetRuns && inn.targetRuns > 0) return inn.targetRuns;
  const first = firstInnings(match);
  if (!first) return 0;
  const revised = match.targetState?.pendingChaseTarget;
  if (revised && revised > 0) return revised;
  return (first.totalRuns || 0) + 1;
}

function chaseSituation(match, inn) {
  const bpo = ballsPerOver(match);
  const target = chaseTarget(match, inn);
  const runsNeeded = Math.max(0, target - (inn?.totalRuns || 0));
  const totalBalls = totalOvers(match) * bpo;
  const ballsRemaining = Math.max(0, totalBalls - (inn?.legalBalls || 0));
  return { target, runsNeeded, ballsRemaining, bpo };
}

function matchTitle(match) {
  const a = match.teamAName || 'Team A';
  const b = match.teamBName || 'Team B';
  return `${a} vs ${b}`;
}

module.exports = {
  ballsPerOver,
  totalOvers,
  formatOvers,
  teamName,
  battingTeamName,
  currentInnings,
  firstInnings,
  scoreLine,
  chaseTarget,
  chaseSituation,
  matchTitle,
};
