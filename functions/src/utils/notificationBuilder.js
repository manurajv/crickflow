const {
  ballsPerOver,
  totalOvers,
  battingTeamName,
  currentInnings,
  firstInnings,
  scoreLine,
  chaseSituation,
  matchTitle,
} = require('./matchFormat');

function buildMatchStartNotification(match) {
  const inn = currentInnings(match) || { totalRuns: 0, totalWickets: 0, legalBalls: 0 };
  const bpo = ballsPerOver(match);
  const title = matchTitle(match);
  const body = [
    'Match Started',
    `${totalOvers(match)} Over Match`,
    'Live Now',
    '',
    'Score:',
    scoreLine(inn, bpo),
  ].join('\n');
  return { title, body };
}

function buildSecondInningsStartNotification(match) {
  const inn = currentInnings(match) || { totalRuns: 0, totalWickets: 0, legalBalls: 0 };
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, inn);
  const { target, runsNeeded, ballsRemaining } = chaseSituation(match, inn);
  const body = [
    'Second Innings Started',
    `Target: ${target}`,
    team,
    scoreLine(inn, bpo),
    `Need ${runsNeeded} runs from ${ballsRemaining} balls`,
  ].join('\n');
  return { title: 'Second Innings Started', body };
}

function buildFirstInningsCompleteNotification(match) {
  const first = firstInnings(match);
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, first);
  const target = (first?.totalRuns || 0) + 1;
  const body = [
    'First Innings Complete',
    team,
    scoreLine(first, bpo),
    `Target: ${target}`,
  ].join('\n');
  return { title: 'First Innings Complete', body };
}

function buildWicketNotification(match, event) {
  const inn = currentInnings(match);
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, inn);
  const dismissal =
    event.dismissalText ||
    event.commentary ||
    event.dismissedPlayerName ||
    'Wicket fallen';
  const lines = ['WICKET!', team, scoreLine(inn, bpo), dismissal];
  if (inn && inn.inningsNumber >= 2) {
    const { runsNeeded } = chaseSituation(match, inn);
    if (runsNeeded > 0) lines.push(`Need ${runsNeeded} more runs`);
  }
  return { title: 'WICKET!', body: lines.join('\n') };
}

function buildBoundaryNotification(match, event, kind) {
  const inn = currentInnings(match);
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, inn);
  const label = kind === 'six' ? 'SIX!' : 'FOUR!';
  const lines = [label, team, scoreLine(inn, bpo)];
  if (inn && inn.inningsNumber >= 2) {
    const { target, runsNeeded, ballsRemaining } = chaseSituation(match, inn);
    lines.push(`Target: ${target}`);
    if (runsNeeded > 0) {
      lines.push(`Need ${runsNeeded} runs from ${ballsRemaining} balls`);
    }
  }
  return { title: label, body: lines.join('\n') };
}

function buildTeamMilestoneNotification(match, milestone, inn) {
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, inn);
  return {
    title: `${milestone} Runs Up`,
    body: [`${milestone} Runs Up`, team, scoreLine(inn, bpo)].join('\n'),
  };
}

function buildPlayerMilestoneNotification(match, playerName, runs, balls, inn) {
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, inn);
  return {
    title: `${runs} Runs`,
    body: [
      `${runs} Runs`,
      `${playerName}`,
      `${runs} (${balls})`,
      team,
      scoreLine(inn, bpo),
    ].join('\n'),
  };
}

function buildTargetRevisionNotification(match, revision) {
  const inn = currentInnings(match);
  const bpo = ballsPerOver(match);
  const oldTarget = revision.oldTarget ?? revision.originalTarget;
  const newTarget = revision.newTarget ?? revision.revisedTarget;
  const lines = [
    'Target Revised',
    `Old Target: ${oldTarget ?? '—'}`,
    `New Target: ${newTarget ?? '—'}`,
  ];
  if (revision.reason) lines.push(`Reason: ${revision.reason}`);
  if (inn) {
    lines.push('', 'Current Score:', scoreLine(inn, bpo));
    if (inn.inningsNumber >= 2 && newTarget) {
      const runsNeeded = Math.max(0, newTarget - (inn.totalRuns || 0));
      const totalBalls = totalOvers(match) * bpo;
      const ballsRemaining = Math.max(0, totalBalls - (inn.legalBalls || 0));
      lines.push(`Need ${runsNeeded} runs from ${ballsRemaining} balls`);
    }
  }
  return { title: 'Target Revised', body: lines.join('\n') };
}

function buildDlsNotification(match, revision) {
  const inn = currentInnings(match);
  const bpo = ballsPerOver(match);
  const newTarget =
    revision.newTarget ??
    match.targetState?.revisedTarget ??
    match.targetState?.pendingChaseTarget;
  const lines = ['DLS Applied'];
  if (newTarget) lines.push(`Target Revised: ${newTarget}`);
  if (revision.revisedOvers) lines.push(`Overs Reduced To ${revision.revisedOvers}`);
  if (inn) {
    lines.push('', scoreLine(inn, bpo));
    if (inn.inningsNumber >= 2 && newTarget) {
      const runsNeeded = Math.max(0, newTarget - (inn.totalRuns || 0));
      const totalBalls = (revision.revisedOvers || totalOvers(match)) * bpo;
      const ballsRemaining = Math.max(0, totalBalls - (inn.legalBalls || 0));
      lines.push(`Need ${runsNeeded} runs from ${ballsRemaining} balls`);
    }
  }
  return { title: 'DLS Applied', body: lines.join('\n') };
}

function buildMatchResultNotification(match) {
  const summary = match.resultSummary || 'Match completed';
  const outcome = match.targetState?.matchOutcome;
  let title = 'Match Result';
  if (outcome === 'draw') title = 'Match Drawn';
  if (outcome === 'abandoned') title = 'Match Abandoned';

  const lines = [summary];
  const second = (match.innings || []).find((i) => i.inningsNumber === 2);
  const first = firstInnings(match);
  const bpo = ballsPerOver(match);

  if (second) {
    lines.push('', 'Score:', scoreLine(second, bpo));
    const target = chaseSituation(match, second).target;
    if (target) lines.push(`Target: ${target}`);
  } else if (first) {
    lines.push('', 'Score:', scoreLine(first, bpo));
  }

  return { title, body: lines.join('\n') };
}

function buildMatchBreakStartedNotification(match, activeBreak) {
  const inn = currentInnings(match) || { totalRuns: 0, totalWickets: 0, legalBalls: 0 };
  const bpo = ballsPerOver(match);
  const breakType = activeBreak?.breakType || 'Match';
  const title = `${breakType} Break`;
  const body = [
    title,
    matchTitle(match),
    'Current Score:',
    scoreLine(inn, bpo),
  ].join('\n');
  return { title, body };
}

function buildMatchBreakEndedNotification(match, lastEntry) {
  const inn = currentInnings(match) || { totalRuns: 0, totalWickets: 0, legalBalls: 0 };
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, inn);
  const lines = ['Match Resumed'];
  if (lastEntry?.breakType) {
    lines.push(`${lastEntry.breakType} break ended`);
  }
  lines.push(matchTitle(match), team, scoreLine(inn, bpo));
  return { title: 'Match Resumed', body: lines.join('\n') };
}

module.exports = {
  buildMatchStartNotification,
  buildSecondInningsStartNotification,
  buildFirstInningsCompleteNotification,
  buildWicketNotification,
  buildBoundaryNotification,
  buildTeamMilestoneNotification,
  buildPlayerMilestoneNotification,
  buildTargetRevisionNotification,
  buildDlsNotification,
  buildMatchResultNotification,
  buildMatchBreakStartedNotification,
  buildMatchBreakEndedNotification,
};
