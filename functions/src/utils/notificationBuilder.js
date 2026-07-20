const {
  ballsPerOver,
  totalOvers,
  battingTeamName,
  currentInnings,
  firstInnings,
  scoreLine,
  chaseSituation,
  matchTitle,
  formatOvers,
  teamName,
} = require('./matchFormat');

/** Standard match-notification shape for inbox + push. */
function pack(match, eventTitle, detailLines, extras = {}) {
  const mt = matchTitle(match);
  const details = detailLines.filter((l) => l != null && String(l).trim() !== '');
  return {
    title: eventTitle,
    body: details.join('\n'),
    matchTitle: mt,
    pushTitle: mt,
    pushBody: [eventTitle, ...details.slice(0, 2)].join('\n'),
    ...extras,
  };
}

function tournamentLine(match) {
  return match.tournamentName || match.roundName || null;
}

function venueLine(match) {
  const v = (match.venue || '').trim();
  return v || null;
}

function tossLines(match) {
  const lines = [];
  const tossWinnerIsTeamA = match.tossWinnerIsTeamA;
  const batsFirst = match.tossWinnerBatsFirst;
  if (tossWinnerIsTeamA == null || batsFirst == null) return lines;
  const winner = tossWinnerIsTeamA
    ? match.teamAName || 'Team A'
    : match.teamBName || 'Team B';
  const decision = batsFirst ? 'bat' : 'bowl';
  lines.push(`${winner} won the toss and elected to ${decision}.`);
  return lines;
}

function oversLine(match) {
  return `${totalOvers(match)} Overs`;
}

function milestoneLabel(runs) {
  switch (runs) {
    case 30:
      return 'Thirty';
    case 50:
      return 'Half Century';
    case 100:
      return 'Century';
    case 150:
      return '150';
    case 200:
      return 'Double Century';
    default:
      return `${runs} Runs`;
  }
}

function bowlingMilestoneLabel(wickets) {
  switch (wickets) {
    case 3:
      return 'Three Wickets';
    case 4:
      return 'Four Wickets';
    case 5:
      return 'Five Wicket Haul';
    default:
      return `${wickets} Wickets`;
  }
}

function buildMatchStartNotification(match, perspective = 'general', actorName) {
  const mt = matchTitle(match);
  if (perspective === 'self') {
    return pack(match, '🏏 Match Started', [
      'Your match has started',
      tournamentLine(match),
      venueLine(match),
      oversLine(match),
      ...tossLines(match),
    ]);
  }
  if (perspective === 'network' && actorName) {
    return pack(match, '🏏 Match Started', [
      `${actorName} has started a match`,
      tournamentLine(match),
      mt,
      oversLine(match),
    ]);
  }
  return pack(match, '🏏 Match Started', [
    tournamentLine(match),
    venueLine(match),
    oversLine(match),
    ...tossLines(match),
  ]);
}

function buildSecondInningsStartNotification(match) {
  const inn = currentInnings(match) || { totalRuns: 0, totalWickets: 0, legalBalls: 0 };
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, inn);
  const { target, runsNeeded, ballsRemaining } = chaseSituation(match, inn);
  return pack(match, 'Second Innings Started', [
    team,
    scoreLine(inn, bpo),
    `Target ${target}`,
    `Need ${runsNeeded} runs from ${ballsRemaining} balls`,
  ]);
}

function buildFirstInningsCompleteNotification(match, perspective = 'general', actorName) {
  const first = firstInnings(match);
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, first);
  const target = (first?.totalRuns || 0) + 1;
  if (perspective === 'network' && actorName) {
    return pack(match, 'First Innings Complete', [
      `${actorName}'s match has reached the innings break.`,
      `Target: ${target} Runs.`,
    ]);
  }
  return pack(match, 'First Innings Complete', [
    team,
    scoreLine(first, bpo),
    `${totalOvers(match)} Overs`,
    `Target`,
    `${target} Runs`,
  ]);
}

function buildWicketNotification(match, event) {
  const inn = currentInnings(match);
  const bpo = ballsPerOver(match);
  const batter =
    event.dismissedPlayerName ||
    event.lineupStrikerName ||
    event.strikerAfterBall ||
    null;
  const dismissal =
    event.dismissalText ||
    event.commentary ||
    (batter ? `${batter} is out` : 'Wicket fallen');
  const lines = [batter, dismissal, scoreLine(inn, bpo)].filter(Boolean);
  if (inn && inn.inningsNumber >= 2) {
    const { runsNeeded } = chaseSituation(match, inn);
    if (runsNeeded > 0) lines.push(`Need ${runsNeeded} more runs`);
  }
  return pack(match, 'WICKET!', lines);
}

function buildHatTrickNotification(match, bowlerName, perspective = 'general') {
  const name = bowlerName || 'Bowler';
  const line =
    perspective === 'self'
      ? 'You take three wickets in three balls.'
      : `${name} takes three wickets in three balls.`;
  return pack(match, 'HAT-TRICK!', [line]);
}

function buildTeamMilestoneNotification(match, milestone, inn) {
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, inn);
  return pack(match, `${milestone} Runs`, [
    team,
    scoreLine(inn, bpo),
  ]);
}

function buildPlayerMilestoneNotification(
  match,
  playerName,
  runs,
  balls,
  perspective = 'general',
) {
  const label = milestoneLabel(runs);
  if (perspective === 'self') {
    return pack(match, `${label}!`, [
      `You scored a ${label}.`,
      `${runs} (${balls})`,
    ]);
  }
  if (perspective === 'network') {
    return pack(match, `${label}!`, [
      `${playerName} scored a ${label}.`,
      `${runs} (${balls})`,
    ]);
  }
  return pack(match, `${label}!`, [
    `${playerName} reaches ${runs} from ${balls} balls.`,
  ]);
}

function buildBowlingMilestoneNotification(
  match,
  playerName,
  wickets,
  runsConceded,
  perspective = 'general',
) {
  const label = bowlingMilestoneLabel(wickets);
  const figures =
    runsConceded != null ? `${wickets}/${runsConceded}` : `${wickets} wickets`;
  if (perspective === 'self') {
    return pack(match, `${label}!`, [
      `You took ${wickets} wickets.`,
      figures,
    ]);
  }
  if (perspective === 'network') {
    return pack(match, `${label}!`, [
      `${playerName} took ${wickets} wickets.`,
      figures,
    ]);
  }
  return pack(match, `${label}!`, [playerName, figures]);
}

function buildTargetRevisionNotification(match, revision) {
  const inn = currentInnings(match);
  const bpo = ballsPerOver(match);
  const oldTarget = revision.oldTarget ?? revision.originalTarget;
  const newTarget = revision.newTarget ?? revision.revisedTarget;
  const lines = [
    `Old Target: ${oldTarget ?? '—'}`,
    `New Target: ${newTarget ?? '—'}`,
  ];
  if (revision.reason) lines.push(revision.reason);
  if (inn) {
    lines.push(scoreLine(inn, bpo));
    if (inn.inningsNumber >= 2 && newTarget) {
      const runsNeeded = Math.max(0, newTarget - (inn.totalRuns || 0));
      const totalBalls = totalOvers(match) * bpo;
      const ballsRemaining = Math.max(0, totalBalls - (inn.legalBalls || 0));
      lines.push(`Need ${runsNeeded} runs from ${ballsRemaining} balls`);
    }
  }
  return pack(match, 'Target Revised', lines);
}

function buildDlsNotification(match, revision) {
  const inn = currentInnings(match);
  const bpo = ballsPerOver(match);
  const newTarget =
    revision.newTarget ??
    match.targetState?.revisedTarget ??
    match.targetState?.pendingChaseTarget;
  const lines = [];
  if (newTarget) lines.push(`Target revised to ${newTarget}`);
  if (revision.revisedOvers) {
    lines.push(`Overs reduced to ${revision.revisedOvers}`);
  }
  if (inn) {
    lines.push(scoreLine(inn, bpo));
    if (inn.inningsNumber >= 2 && newTarget) {
      const runsNeeded = Math.max(0, newTarget - (inn.totalRuns || 0));
      const totalBalls = (revision.revisedOvers || totalOvers(match)) * bpo;
      const ballsRemaining = Math.max(0, totalBalls - (inn.legalBalls || 0));
      lines.push(`Need ${runsNeeded} runs from ${ballsRemaining} balls`);
    }
  }
  return pack(match, 'DLS Applied', lines);
}

function resultVerbSummary(match) {
  const summary = (match.resultSummary || '').trim();
  if (summary) {
    // Prefer natural "defeated … by" wording when possible.
    const winnerId = match.winnerTeamId;
    if (winnerId) {
      const winner = teamName(match, winnerId);
      const loser =
        winnerId === match.teamAId
          ? match.teamBName || 'Team B'
          : match.teamAName || 'Team A';
      const byMatch = summary.match(/by\s+(.+)$/i);
      if (byMatch) {
        return `${winner} defeated ${loser} by ${byMatch[1]}.`;
      }
    }
    return summary.endsWith('.') ? summary : `${summary}.`;
  }
  const outcome = match.targetState?.matchOutcome;
  if (outcome === 'draw') return 'The match ended in a draw.';
  if (outcome === 'abandoned') return 'The match was abandoned.';
  return 'Match completed.';
}

function buildMatchResultNotification(match, perspective = 'general', performanceLines) {
  const outcome = match.targetState?.matchOutcome;
  let eventTitle = '🏆 Match Complete';
  if (outcome === 'draw') eventTitle = 'Match Drawn';
  if (outcome === 'abandoned') eventTitle = 'Match Abandoned';

  const lines = [resultVerbSummary(match)];
  if (performanceLines && performanceLines.length) {
    lines.push('', ...performanceLines);
  }
  return pack(match, eventTitle, lines, { perspective });
}

function formatPerformanceLines(perf, perspective, playerName) {
  if (!perf) return [];
  const bat =
    perf.runs > 0
      ? `${perf.runs}${perf.balls > 0 ? ` (${perf.balls})` : ''}`
      : null;
  const catchLine =
    perf.catches > 0
      ? `${perf.catches} Catch${perf.catches === 1 ? '' : 'es'}`
      : null;
  const sr =
    perf.balls > 0 && perf.runs > 0
      ? `Strike Rate ${((perf.runs / perf.balls) * 100).toFixed(1)}`
      : null;
  const bpo = perf.bpo || 6;
  const economy =
    perf.ballsBowled > 0 && perf.runsConceded != null
      ? `Economy ${((perf.runsConceded * bpo) / perf.ballsBowled).toFixed(2)}`
      : null;
  const oversBowled =
    perf.ballsBowled > 0
      ? `${formatOvers(perf.ballsBowled, bpo)} Overs`
      : null;
  const figures =
    perf.wickets > 0 && perf.runsConceded != null
      ? `${perf.wickets}/${perf.runsConceded}`
      : null;

  if (perspective === 'network') {
    const lines = [];
    if (bat) {
      lines.push(`${playerName} scored`, bat);
      if (perf.wickets > 0) {
        lines.push(
          `and took ${perf.wickets} wicket${perf.wickets === 1 ? '' : 's'}.`,
        );
      }
      return lines;
    }
    if (perf.wickets > 0) {
      return [
        `${playerName} took ${perf.wickets} wicket${perf.wickets === 1 ? '' : 's'}.`,
        figures,
      ].filter(Boolean);
    }
    if (catchLine) return [`${playerName}`, catchLine];
    return [];
  }

  // Self / general performance block
  const lines = ['Your Performance'];
  if (bat) lines.push(bat);
  if (perf.wickets > 0) {
    lines.push(`${perf.wickets} Wicket${perf.wickets === 1 ? '' : 's'}`);
    if (figures) lines.push(figures);
  }
  if (catchLine) lines.push(catchLine);
  if (bat && sr) lines.push(sr);
  if (!bat && oversBowled) lines.push(oversBowled);
  if (!bat && economy) lines.push(economy);
  return lines.length > 1 ? lines : [];
}

function buildHeroOfMatchNotification(match, hero, perspective = 'general') {
  const name = hero?.playerName || 'Player';
  const lines = [];
  if (perspective === 'self') {
    lines.push('You were named Hero of the Match.');
  } else if (perspective === 'network') {
    lines.push(`${name} was named Hero of the Match.`);
  } else {
    lines.push(`${name} was named Hero of the Match.`);
  }
  if (hero?.reason) lines.push(hero.reason);
  if (hero?.battingLine) lines.push(hero.battingLine);
  if (hero?.bowlingLine) lines.push(hero.bowlingLine);
  return pack(match, '⭐ Hero of the Match', lines);
}

function buildBadgeUnlockNotification(badgeTitle, reason) {
  return {
    title: '🏅 New Badge Unlocked',
    body: [badgeTitle, reason].filter(Boolean).join('\n'),
    matchTitle: null,
    pushTitle: '🏅 New Badge Unlocked',
    pushBody: [badgeTitle, reason].filter(Boolean).join('\n'),
    category: 'badge',
  };
}

function buildMatchBreakStartedNotification(match, activeBreak) {
  const inn = currentInnings(match) || { totalRuns: 0, totalWickets: 0, legalBalls: 0 };
  const bpo = ballsPerOver(match);
  const breakType = activeBreak?.breakType || 'Match';
  return pack(match, `${breakType} Break`, [
    'Current Score',
    scoreLine(inn, bpo),
  ]);
}

function buildMatchBreakEndedNotification(match, lastEntry) {
  const inn = currentInnings(match) || { totalRuns: 0, totalWickets: 0, legalBalls: 0 };
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, inn);
  const lines = [];
  if (lastEntry?.breakType) {
    lines.push(`${lastEntry.breakType} break ended`);
  }
  lines.push(team, scoreLine(inn, bpo));
  return pack(match, 'Match Resumed', lines);
}

function buildStreamStartedNotification(match) {
  return pack(match, 'Live Stream Started', [
    'Watch the live stream now on CrickFlow.',
  ]);
}

function buildStreamEndedNotification(match) {
  return pack(match, 'Stream Ended', [
    'The live stream has ended.',
  ]);
}

module.exports = {
  pack,
  milestoneLabel,
  bowlingMilestoneLabel,
  buildMatchStartNotification,
  buildSecondInningsStartNotification,
  buildFirstInningsCompleteNotification,
  buildWicketNotification,
  buildHatTrickNotification,
  buildTeamMilestoneNotification,
  buildPlayerMilestoneNotification,
  buildBowlingMilestoneNotification,
  buildTargetRevisionNotification,
  buildDlsNotification,
  buildMatchResultNotification,
  formatPerformanceLines,
  buildHeroOfMatchNotification,
  buildBadgeUnlockNotification,
  buildMatchBreakStartedNotification,
  buildMatchBreakEndedNotification,
  buildStreamStartedNotification,
  buildStreamEndedNotification,
};
