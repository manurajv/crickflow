const {
  ballsPerOver,
  totalOvers,
  battingTeamName,
  currentInnings,
  firstInnings,
  scoreLine,
  scoreStatusLine,
  chaseSituation,
  matchTitle,
  formatOvers,
  teamName,
} = require('./matchFormat');

/**
 * Professional match notification shape (Google Cricket / CrickHeroes style).
 *
 * Push tray:
 *   Title  = full match title (never shortened)
 *   Body   = what happened
 *            batting side score (runs/wkts overs)
 *
 * Inbox:
 *   matchTitle = full match title
 *   title      = short event label
 *   body       = same multi-line body as push
 */
function pack(match, eventTitle, eventLine, scoreStatus, extras = {}) {
  const mt = matchTitle(match);
  const event = String(eventLine || eventTitle || '')
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean)
    .join('\n');
  const score = scoreStatus != null ? String(scoreStatus).trim() : '';
  const bodyLines = [event, score].filter((l) => l && l.length > 0);
  const body = bodyLines.join('\n');
  return {
    title: eventTitle,
    body,
    matchTitle: mt,
    pushTitle: mt,
    pushBody: body,
    ...extras,
  };
}

function currentScoreStatus(match, inn) {
  const use = inn || currentInnings(match);
  if (!use) return null;
  return scoreStatusLine(match, use);
}

function tournamentHint(match) {
  return match.tournamentName || match.roundName || null;
}

function tossHint(match) {
  const tossWinnerIsTeamA = match.tossWinnerIsTeamA;
  const batsFirst = match.tossWinnerBatsFirst;
  if (tossWinnerIsTeamA == null || batsFirst == null) return null;
  const winner = tossWinnerIsTeamA
    ? match.teamAName || 'Team A'
    : match.teamBName || 'Team B';
  const decision = batsFirst ? 'bat' : 'bowl';
  return `${winner} elected to ${decision}`;
}

function milestoneLabel(runs) {
  switch (runs) {
    case 30:
      return 'Thirty';
    case 50:
      return 'Fifty';
    case 100:
      return 'Century';
    case 150:
      return '150';
    case 200:
      return 'Double century';
    default:
      return `${runs} runs`;
  }
}

function bowlingMilestoneLabel(wickets) {
  switch (wickets) {
    case 3:
      return '3 wickets';
    case 4:
      return '4 wickets';
    case 5:
      return '5-wicket haul';
    default:
      return `${wickets} wickets`;
  }
}

function buildMatchStartNotification(match, perspective = 'general', actorName) {
  const overs = `${totalOvers(match)} overs`;
  const toss = tossHint(match);
  const tourney = tournamentHint(match);
  let event;
  if (perspective === 'self') {
    event = ['Your match is live', toss || overs].filter(Boolean).join(' · ');
  } else if (perspective === 'network' && actorName) {
    event = [`${actorName} started a match`, toss || overs]
      .filter(Boolean)
      .join(' · ');
  } else {
    event = [tourney, toss || overs].filter(Boolean).join(' · ') || 'Match is live';
  }
  return pack(match, 'Match started', event, null);
}

function buildSecondInningsStartNotification(match) {
  const inn =
    currentInnings(match) || { totalRuns: 0, totalWickets: 0, legalBalls: 0 };
  const { target, runsNeeded, ballsRemaining } = chaseSituation(match, inn);
  const team = battingTeamName(match, inn);
  return pack(
    match,
    'Chase underway',
    `${team} need ${runsNeeded} from ${ballsRemaining} (target ${target})`,
    currentScoreStatus(match, inn),
  );
}

function buildFirstInningsCompleteNotification(
  match,
  perspective = 'general',
  actorName,
) {
  const first = firstInnings(match);
  const bpo = ballsPerOver(match);
  const team = battingTeamName(match, first);
  const target = (first?.totalRuns || 0) + 1;
  const status = first ? `${team} ${scoreLine(first, bpo)}` : null;
  if (perspective === 'network' && actorName) {
    return pack(
      match,
      'Innings break',
      `${actorName}'s match — target ${target}`,
      status,
    );
  }
  return pack(match, 'Innings break', `Target ${target}`, status);
}

function buildWicketNotification(match, event) {
  const inn = currentInnings(match);
  const batter =
    event.dismissedPlayerName ||
    event.lineupStrikerName ||
    event.strikerAfterBall ||
    null;
  const dismissal =
    event.dismissalText ||
    event.commentary ||
    (batter ? `${batter} is out` : 'Wicket');
  let eventLine = batter
    ? `OUT · ${dismissal}`.replace(/\s+/g, ' ').trim()
    : `OUT · ${dismissal}`;
  // Avoid "OUT · Name Name is out" redundancy when dismissal already has name.
  if (batter && dismissal.toLowerCase().startsWith(batter.toLowerCase())) {
    eventLine = `OUT · ${dismissal}`;
  } else if (batter && !dismissal.toLowerCase().includes(batter.toLowerCase())) {
    eventLine = `OUT · ${batter} — ${dismissal}`;
  }
  if (inn && inn.inningsNumber >= 2) {
    const { runsNeeded } = chaseSituation(match, inn);
    if (runsNeeded > 0) {
      eventLine = `${eventLine} · Need ${runsNeeded}`;
    }
  }
  return pack(match, 'Wicket', eventLine, currentScoreStatus(match, inn));
}

/**
 * Retired Hurt — not a dismissal. Never use the word "Out".
 */
function buildRetiredHurtNotification(match, event) {
  const batter =
    event.dismissedPlayerName ||
    event.lineupStrikerName ||
    'Batter';
  const runs = retiredScoreFromMatch(match, event);
  const eventLine =
    runs != null
      ? `${batter} retired hurt on ${runs}.`
      : `${batter} retired hurt and left the field.`;
  return pack(match, 'Retired Hurt', eventLine, currentScoreStatus(match));
}

/**
 * Retired Out — counts as a wicket but wording is "retired out", not "OUT ·".
 */
function buildRetiredOutNotification(match, event) {
  const batter =
    event.dismissedPlayerName ||
    event.lineupStrikerName ||
    'Batter';
  const runs = retiredScoreFromMatch(match, event);
  const eventLine =
    runs != null
      ? `${batter} retired out on ${runs}.`
      : `${batter} retired out.`;
  return pack(match, 'Retired Out', eventLine, currentScoreStatus(match));
}

function retiredScoreFromMatch(match, event) {
  const id = event.dismissedPlayerId;
  if (!id || !match?.innings) return null;
  for (const inn of match.innings) {
    const batsmen = inn.batsmen || [];
    const b = batsmen.find((x) => x.playerId === id);
    if (b) {
      if (b.retiredAtScore != null) return b.retiredAtScore;
      if (b.runs != null) return b.runs;
    }
  }
  return null;
}

function buildHatTrickNotification(match, bowlerName, perspective = 'general') {
  const name = bowlerName || 'Bowler';
  const event =
    perspective === 'self'
      ? 'You — 3 wickets in 3 balls'
      : `${name} — 3 wickets in 3 balls`;
  return pack(match, 'Hat-trick', event, currentScoreStatus(match));
}

function buildTeamMilestoneNotification(match, milestone, inn) {
  const team = battingTeamName(match, inn);
  return pack(
    match,
    `${milestone} up`,
    `${team} reach ${milestone}`,
    currentScoreStatus(match, inn),
  );
}

function buildPlayerMilestoneNotification(
  match,
  playerName,
  runs,
  balls,
  perspective = 'general',
) {
  const label = milestoneLabel(runs);
  const figures = `${runs} (${balls})`;
  let event;
  if (perspective === 'self') {
    event = `You ${figures}`;
  } else {
    event = `${playerName || 'Batter'} ${figures}`;
  }
  return pack(match, label, event, currentScoreStatus(match));
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
    runsConceded != null ? `${wickets}/${runsConceded}` : `${wickets} wkts`;
  let event;
  if (perspective === 'self') {
    event = `You — ${label} (${figures})`;
  } else {
    event = `${playerName || 'Bowler'} — ${label} (${figures})`;
  }
  return pack(match, label, event, currentScoreStatus(match));
}

function buildTargetRevisionNotification(match, revision) {
  const inn = currentInnings(match);
  const bpo = ballsPerOver(match);
  const oldTarget = revision.oldTarget ?? revision.originalTarget;
  const newTarget = revision.newTarget ?? revision.revisedTarget;
  let event = `Target ${oldTarget ?? '—'} → ${newTarget ?? '—'}`;
  if (inn && inn.inningsNumber >= 2 && newTarget) {
    const runsNeeded = Math.max(0, newTarget - (inn.totalRuns || 0));
    const totalBalls = totalOvers(match) * bpo;
    const ballsRemaining = Math.max(0, totalBalls - (inn.legalBalls || 0));
    event = `${event} · Need ${runsNeeded} from ${ballsRemaining}`;
  }
  return pack(match, 'Target revised', event, currentScoreStatus(match, inn));
}

function buildDlsNotification(match, revision) {
  const inn = currentInnings(match);
  const bpo = ballsPerOver(match);
  const newTarget =
    revision.newTarget ??
    match.targetState?.revisedTarget ??
    match.targetState?.pendingChaseTarget;
  const parts = [];
  if (newTarget) parts.push(`Target ${newTarget}`);
  if (revision.revisedOvers) parts.push(`${revision.revisedOvers} overs`);
  let event = parts.join(' · ') || 'DLS applied';
  if (inn && inn.inningsNumber >= 2 && newTarget) {
    const runsNeeded = Math.max(0, newTarget - (inn.totalRuns || 0));
    const totalBalls = (revision.revisedOvers || totalOvers(match)) * bpo;
    const ballsRemaining = Math.max(0, totalBalls - (inn.legalBalls || 0));
    event = `${event} · Need ${runsNeeded} from ${ballsRemaining}`;
  }
  return pack(match, 'DLS', event, currentScoreStatus(match, inn));
}

function resultVerbSummary(match) {
  const summary = (match.resultSummary || '').trim();
  if (summary) {
    const winnerId = match.winnerTeamId;
    if (winnerId) {
      const winner = teamName(match, winnerId);
      const loser =
        winnerId === match.teamAId
          ? match.teamBName || 'Team B'
          : match.teamAName || 'Team A';
      const byMatch = summary.match(/by\s+(.+)$/i);
      if (byMatch) {
        return `${winner} beat ${loser} by ${byMatch[1]}`;
      }
    }
    return summary.replace(/\.$/, '');
  }
  const outcome = match.targetState?.matchOutcome;
  if (outcome === 'draw') return 'Match drawn';
  if (outcome === 'abandoned') return 'Match abandoned';
  return 'Match complete';
}

function buildMatchResultNotification(match, perspective = 'general', performanceLines) {
  const outcome = match.targetState?.matchOutcome;
  let eventTitle = 'Match complete';
  if (outcome === 'draw') eventTitle = 'Match drawn';
  if (outcome === 'abandoned') eventTitle = 'Match abandoned';

  let event = resultVerbSummary(match);
  if (performanceLines && performanceLines.length) {
    const compact = performanceLines
      .map((l) => String(l).trim())
      .filter((l) => l && l !== 'Your Performance')
      .slice(0, 2)
      .join(' · ');
    if (compact) event = `${event} · ${compact}`;
  }
  // Final batting status if still available.
  const inn = currentInnings(match) || firstInnings(match);
  return pack(match, eventTitle, event, currentScoreStatus(match, inn), {
    perspective,
  });
}

function formatPerformanceLines(perf, perspective, playerName) {
  if (!perf) return [];
  const bat =
    perf.runs > 0
      ? `${perf.runs}${perf.balls > 0 ? ` (${perf.balls})` : ''}`
      : null;
  const catchLine =
    perf.catches > 0
      ? `${perf.catches} catch${perf.catches === 1 ? '' : 'es'}`
      : null;
  const figures =
    perf.wickets > 0 && perf.runsConceded != null
      ? `${perf.wickets}/${perf.runsConceded}`
      : null;

  if (perspective === 'network') {
    if (bat && perf.wickets > 0) {
      return [`${playerName} ${bat} & ${figures || `${perf.wickets} wkts`}`];
    }
    if (bat) return [`${playerName} ${bat}`];
    if (perf.wickets > 0) {
      return [`${playerName} ${figures || `${perf.wickets} wkts`}`];
    }
    if (catchLine) return [`${playerName} ${catchLine}`];
    return [];
  }

  const bits = [];
  if (bat) bits.push(bat);
  if (perf.wickets > 0) bits.push(figures || `${perf.wickets} wkts`);
  if (catchLine) bits.push(catchLine);
  return bits.length ? bits : [];
}

function buildHeroOfMatchNotification(match, hero, perspective = 'general') {
  const name = hero?.playerName || 'Player';
  let event =
    perspective === 'self'
      ? 'You — Hero of the Match'
      : `${name} — Hero of the Match`;
  const bits = [hero?.reason, hero?.battingLine, hero?.bowlingLine]
    .filter(Boolean)
    .slice(0, 1);
  if (bits.length) event = `${event} · ${bits[0]}`;
  return pack(match, 'Hero of the Match', event, null);
}

function buildBadgeUnlockNotification(badgeTitle, reason) {
  return {
    title: 'New badge',
    body: [badgeTitle, reason].filter(Boolean).join('\n'),
    matchTitle: null,
    pushTitle: 'New badge unlocked',
    pushBody: [badgeTitle, reason].filter(Boolean).join('\n'),
    category: 'badge',
  };
}

function buildMatchBreakStartedNotification(match, activeBreak) {
  const breakType = activeBreak?.breakType || 'Match';
  return pack(
    match,
    `${breakType} break`,
    'Play paused',
    currentScoreStatus(match),
  );
}

function buildMatchBreakEndedNotification(match, lastEntry) {
  const breakType = lastEntry?.breakType;
  const event = breakType ? `${breakType} over — play resumed` : 'Play resumed';
  return pack(match, 'Play resumed', event, currentScoreStatus(match));
}

function buildStreamStartedNotification(match) {
  return pack(match, 'Live stream', 'Watch now on CrickFlow', null);
}

function buildStreamEndedNotification(match) {
  return pack(match, 'Stream ended', 'Live stream has ended', null);
}

module.exports = {
  pack,
  milestoneLabel,
  bowlingMilestoneLabel,
  buildMatchStartNotification,
  buildSecondInningsStartNotification,
  buildFirstInningsCompleteNotification,
  buildWicketNotification,
  buildRetiredHurtNotification,
  buildRetiredOutNotification,
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
