/**
 * Ball-event replay and player aggregation (mirrors Dart BallEventAggregator +
 * ScoringEngine). Server-side source of truth for match-completion stats.
 */

function normalizeRules(rules) {
  return {
    ballsPerOver: rules?.ballsPerOver ?? 6,
    wideRuns: rules?.wideRuns ?? 1,
    noBallRuns: rules?.noBallRuns ?? 1,
    freeHitEnabled: rules?.freeHitEnabled !== false,
    wideCountsAsLegalDelivery: rules?.wideCountsAsLegalDelivery === true,
    noBallCountsAsLegalDelivery: rules?.noBallCountsAsLegalDelivery === true,
  };
}

function countsAsWicket(e) {
  if (e.retiredHurt) return false;
  if (e.isWicket === true) return true;
  if (e.eventType !== 'wicket') return false;
  return !(e.isFreeHit && e.wicketType !== 'runOut');
}

function creditsBowlerWicketType(wicketType, isMankad = false) {
  if (!wicketType || isMankad) return false;
  return [
    'bowled',
    'caught',
    'caughtBehind',
    'caughtAndBowled',
    'lbw',
    'stumped',
    'hitWicket',
  ].includes(wicketType);
}

function bowlerGetsWicketFromEvent(event) {
  if (!countsAsWicket(event) || event.eventType !== 'wicket') return false;
  if (event.bowlerGetsWicket === true) return true;
  if (event.bowlerGetsWicket === false) return false;
  return creditsBowlerWicketType(event.wicketType, event.isMankad === true);
}

function formatKeeperDisplayName(name) {
  const trimmed = (name || '').trim();
  if (!trimmed) return '';
  if (trimmed.startsWith('†')) return trimmed;
  return `†${trimmed}`;
}

function formatRunOutDisplay(primary, secondary) {
  const names = [];
  if (primary) names.push(primary);
  if (secondary) names.push(secondary);
  if (names.length === 0) return 'run out';
  if (names.length === 1) return `run out ${names[0]}`;
  return `run out ${names.join(' / ')}`;
}

function formatDismissalFromEvent(event) {
  const type = event.wicketType;
  const bowler = (event.bowlerName || event.bowlerId || '').trim();
  const fielder = (
    event.primaryFielderName ||
    event.fielderName ||
    event.wicketKeeperName ||
    (event.fielderNames && event.fielderNames[0]) ||
    ''
  ).trim();
  const secondary = (
    event.secondaryFielderName ||
    (event.fielderNames && event.fielderNames[1]) ||
    ''
  ).trim();

  if (event.isMankad) {
    return formatRunOutDisplay(bowler);
  }

  switch (type) {
    case 'bowled':
      return bowler ? `b ${bowler}` : 'bowled';
    case 'caught': {
      const isBehind = event.dismissalSubType === 'caught_behind';
      const displayFielder = isBehind ? formatKeeperDisplayName(fielder) : fielder;
      if (displayFielder && bowler) return `c ${displayFielder} b ${bowler}`;
      if (displayFielder) return `c ${displayFielder}`;
      if (bowler) return `b ${bowler}`;
      return 'caught';
    }
    case 'caughtBehind': {
      const keeper = fielder ? formatKeeperDisplayName(fielder) : '';
      if (keeper && bowler) return `c ${keeper} b ${bowler}`;
      if (keeper) return `c ${keeper}`;
      if (bowler) return `b ${bowler}`;
      return 'caught behind';
    }
    case 'caughtAndBowled':
      return bowler ? `c & b ${bowler}` : 'c & b';
    case 'lbw':
      return bowler ? `lbw b ${bowler}` : 'lbw';
    case 'runOut': {
      if (
        !event.isMankad &&
        fielder &&
        bowler &&
        fielder === bowler
      ) {
        return formatRunOutDisplay('');
      }
      return formatRunOutDisplay(fielder, secondary);
    }
    case 'stumped':
      return bowler ? `st b ${bowler}` : 'stumped';
    case 'hitWicket':
      return bowler ? `hit wicket b ${bowler}` : 'hit wicket';
    case 'retiredHurt':
      return 'retired hurt';
    case 'retiredOut':
      return 'retired out';
    case 'obstructingField':
      return 'obstructing the field';
    case 'timedOut':
      return 'timed out';
    case 'handledBall':
      return 'handled the ball';
    case 'hitBallTwice':
      return 'hit the ball twice';
    default:
      return (event.dismissalText || type || 'out').trim();
  }
}

function illegalDeliveryExtras(event) {
  if (event.eventType === 'wide' || event.eventType === 'noBall') {
    return (event.runs || 0) - (event.batsmanRuns || 0);
  }
  return event.extraRuns || 0;
}

function runsAgainstBowler(event) {
  if (event.eventType === 'bye' || event.eventType === 'legBye') return 0;
  return event.runs || 0;
}

function countsAsBallFaced(event) {
  if (!event.isLegalDelivery) return false;
  return event.eventType !== 'wide' && event.eventType !== 'noBall';
}

function strikerFacedDelivery(event) {
  return countsAsBallFaced(event);
}

function runningRunsForEndChange(event) {
  switch (event.eventType) {
    case 'runs':
      return event.batsmanRuns || 0;
    case 'wide':
      return (event.runs || 0) - (event.extraRuns || 0);
    case 'noBall': {
      const mode = event.noBallRunsMode;
      if (mode === 'bye' || mode === 'legBye') {
        return (event.runs || 0) - (event.extraRuns || 0);
      }
      return event.batsmanRuns || 0;
    }
    case 'bye':
    case 'legBye':
      return event.runs || 0;
    default:
      return 0;
  }
}

function shouldRotateEndsForEvent(event) {
  const running = runningRunsForEndChange(event);
  if (running % 2 === 0) return false;
  switch (event.eventType) {
    case 'wide':
    case 'noBall':
      return true;
    case 'bye':
    case 'legBye':
    case 'runs':
      return !!event.isLegalDelivery;
    default:
      return false;
  }
}

function upsertBatsman(list, playerId, playerName) {
  const idx = list.findIndex((b) => b.playerId === playerId);
  if (idx >= 0) return list;
  return [
    ...list,
    {
      playerId,
      playerName: playerName || '',
      runs: 0,
      balls: 0,
      fours: 0,
      sixes: 0,
      isOut: false,
      dismissalInfo: '',
    },
  ];
}

function updateBatsman(list, playerId, runs, countBallFaced) {
  const idx = list.findIndex((b) => b.playerId === playerId);
  if (idx < 0) return list;
  const b = list[idx];
  const next = [...list];
  next[idx] = {
    ...b,
    runs: b.runs + runs,
    balls: b.balls + (countBallFaced ? 1 : 0),
    fours: b.fours + (runs === 4 ? 1 : 0),
    sixes: b.sixes + (runs === 6 ? 1 : 0),
  };
  return next;
}

function incrementBatsmanBall(list, playerId) {
  const idx = list.findIndex((b) => b.playerId === playerId);
  if (idx < 0) return list;
  const next = [...list];
  next[idx] = { ...next[idx], balls: next[idx].balls + 1 };
  return next;
}

function markBatsmanOut(list, playerId, dismissal) {
  const idx = list.findIndex((b) => b.playerId === playerId);
  if (idx >= 0) {
    const next = [...list];
    next[idx] = {
      ...next[idx],
      isOut: true,
      dismissalInfo: dismissal,
      retiredHurt: false,
      isEligibleToReturn: false,
    };
    return next;
  }
  return [
    ...list,
    {
      playerId,
      playerName: '',
      runs: 0,
      balls: 0,
      fours: 0,
      sixes: 0,
      isOut: true,
      dismissalInfo: dismissal,
      retiredHurt: false,
      isEligibleToReturn: false,
    },
  ];
}

function markBatsmanRetiredHurt(list, playerId) {
  const idx = list.findIndex((b) => b.playerId === playerId);
  if (idx >= 0) {
    const next = [...list];
    next[idx] = {
      ...next[idx],
      isOut: false,
      retiredHurt: true,
      isEligibleToReturn: true,
      dismissalInfo: 'retired hurt',
    };
    return next;
  }
  return [
    ...list,
    {
      playerId,
      playerName: '',
      runs: 0,
      balls: 0,
      fours: 0,
      sixes: 0,
      isOut: false,
      retiredHurt: true,
      isEligibleToReturn: true,
      dismissalInfo: 'retired hurt',
    },
  ];
}

function upsertBowler(list, playerId, playerName) {
  if (list.find((b) => b.playerId === playerId)) return list;
  return [
    ...list,
    {
      playerId,
      playerName: playerName || '',
      oversBowledBalls: 0,
      runsConceded: 0,
      wickets: 0,
      wides: 0,
      noBalls: 0,
    },
  ];
}

function updateBowler(list, playerId, runs, legalBall, wicket, isNoBall, isWide) {
  const idx = list.findIndex((b) => b.playerId === playerId);
  if (idx < 0) return list;
  const b = list[idx];
  const next = [...list];
  next[idx] = {
    ...b,
    oversBowledBalls: b.oversBowledBalls + (legalBall ? 1 : 0),
    runsConceded: b.runsConceded + runs,
    wickets: b.wickets + (wicket ? 1 : 0),
    wides: b.wides + (isWide ? 1 : 0),
    noBalls: b.noBalls + (isNoBall ? 1 : 0),
  };
  return next;
}

function baseInningsFrom(lineup, events) {
  const sorted = [...events].sort((a, b) => (a.sequence || 0) - (b.sequence || 0));
  const first = sorted[0];
  return {
    inningsNumber: lineup.inningsNumber,
    battingTeamId: lineup.battingTeamId,
    bowlingTeamId: lineup.bowlingTeamId,
    strikerId: first?.strikerId ?? lineup.strikerId ?? null,
    nonStrikerId: first?.nonStrikerId ?? lineup.nonStrikerId ?? null,
    currentBowlerId: first?.bowlerId ?? lineup.currentBowlerId ?? null,
    totalRuns: 0,
    totalWickets: 0,
    legalBalls: 0,
    extras: 0,
    partnershipRuns: 0,
    partnershipBalls: 0,
    isFreeHitActive: false,
    batsmen: (lineup.batsmen || []).map((b) => ({
      playerId: b.playerId,
      playerName: b.playerName || '',
      runs: 0,
      balls: 0,
      fours: 0,
      sixes: 0,
      isOut: false,
      dismissalInfo: '',
    })),
    bowlers: (lineup.bowlers || []).map((b) => ({
      playerId: b.playerId,
      playerName: b.playerName || '',
      oversBowledBalls: 0,
      runsConceded: 0,
      wickets: 0,
      wides: 0,
      noBalls: 0,
    })),
  };
}

function upsertBatsmanNamed(list, playerId, playerName) {
  const idx = list.findIndex((b) => b.playerId === playerId);
  if (idx >= 0) {
    const next = [...list];
    next[idx] = {
      ...next[idx],
      playerName: playerName || next[idx].playerName || '',
    };
    return next;
  }
  return upsertBatsman(list, playerId, playerName);
}

function upsertBowlerNamed(list, playerId, playerName) {
  const idx = list.findIndex((b) => b.playerId === playerId);
  if (idx >= 0) {
    const next = [...list];
    next[idx] = {
      ...next[idx],
      playerName: playerName || next[idx].playerName || '',
    };
    return next;
  }
  return upsertBowler(list, playerId, playerName);
}

function applyLineupChange(innings, event) {
  let batsmen = [...innings.batsmen];
  let bowlers = [...innings.bowlers];

  if (event.strikerId) {
    batsmen = upsertBatsmanNamed(
      batsmen,
      event.strikerId,
      event.lineupStrikerName || '',
    );
  }
  if (event.nonStrikerId) {
    batsmen = upsertBatsmanNamed(
      batsmen,
      event.nonStrikerId,
      event.lineupNonStrikerName || '',
    );
  }
  if (event.bowlerId) {
    bowlers = upsertBowlerNamed(
      bowlers,
      event.bowlerId,
      event.bowlerName || '',
    );
  }

  return {
    ...innings,
    strikerId: event.strikerId ?? innings.strikerId,
    nonStrikerId: event.nonStrikerId ?? innings.nonStrikerId,
    currentBowlerId: event.bowlerId || innings.currentBowlerId,
    batsmen,
    bowlers,
  };
}

function applyEventToInnings(innings, event, rules) {
  if (event.eventType === 'lineupChange') {
    return applyLineupChange(innings, event);
  }

  let totalRuns = innings.totalRuns + (event.runs || 0);
  let totalWickets = innings.totalWickets;
  let legalBalls = innings.legalBalls;
  let extras = innings.extras;
  let partnershipRuns = innings.partnershipRuns + (event.runs || 0);
  let partnershipBalls = innings.partnershipBalls;
  let isFreeHit = innings.isFreeHitActive;

  if (event.isLegalDelivery) {
    legalBalls += 1;
    partnershipBalls += 1;
    if (event.eventType === 'bye' || event.eventType === 'legBye') {
      extras += event.runs || 0;
    }
    isFreeHit = false;
  } else {
    extras += illegalDeliveryExtras(event);
  }

  if (event.eventType === 'noBall' && rules.freeHitEnabled) {
    isFreeHit = true;
  }

  let strikerId = innings.strikerId;
  let nonStrikerId = innings.nonStrikerId;

  let batsmen = [...innings.batsmen];
  let bowlers = [...innings.bowlers];

  if (event.eventType === 'wicket' && (event.batsmanRuns || 0) > 0) {
    if (event.strikerId) {
      batsmen = upsertBatsman(batsmen, event.strikerId, '');
      batsmen = updateBatsman(
        batsmen,
        event.strikerId,
        event.batsmanRuns || 0,
        countsAsBallFaced(event),
      );
    }
    if ((event.batsmanRuns || 0) % 2 === 1 && strikerId && nonStrikerId) {
      [strikerId, nonStrikerId] = [nonStrikerId, strikerId];
    }
  }

  if (event.eventType === 'wicket' && event.retiredHurt) {
    const retiredId =
      event.dismissedPlayerId || event.strikerId || strikerId;
    if (retiredId) {
      batsmen = markBatsmanRetiredHurt(batsmen, retiredId);
      if (retiredId === strikerId) strikerId = null;
      if (retiredId === nonStrikerId) nonStrikerId = null;
    }
  } else if (event.eventType === 'wicket' && countsAsWicket(event)) {
    totalWickets += 1;
    partnershipRuns = 0;
    partnershipBalls = 0;
    const dismissedId =
      event.dismissedPlayerId || event.strikerId || strikerId;
    if (dismissedId) {
      if (dismissedId === strikerId) strikerId = null;
      if (dismissedId === nonStrikerId) nonStrikerId = null;
    }
  }

  if (event.strikerId) {
    batsmen = upsertBatsman(batsmen, event.strikerId, '');
    const wicketRunsCredited =
      event.eventType === 'wicket' && (event.batsmanRuns || 0) > 0;
    if ((event.batsmanRuns || 0) > 0 && event.eventType !== 'wicket') {
      batsmen = updateBatsman(
        batsmen,
        event.strikerId,
        event.batsmanRuns || 0,
        countsAsBallFaced(event),
      );
    } else if (strikerFacedDelivery(event) && !wicketRunsCredited) {
      batsmen = incrementBatsmanBall(batsmen, event.strikerId);
    }
  }

  if (event.bowlerId) {
    const wicketCredit = bowlerGetsWicketFromEvent(event);
    bowlers = upsertBowler(bowlers, event.bowlerId, '');
    bowlers = updateBowler(
      bowlers,
      event.bowlerId,
      runsAgainstBowler(event),
      !!event.isLegalDelivery,
      wicketCredit,
      event.eventType === 'noBall',
      event.eventType === 'wide',
    );
  }

  if (
    event.eventType === 'wicket' &&
    countsAsWicket(event) &&
    !event.retiredHurt
  ) {
    const dismissedId =
      event.dismissedPlayerId || event.strikerId || innings.strikerId;
    if (dismissedId) {
      batsmen = markBatsmanOut(
        batsmen,
        dismissedId,
        formatDismissalFromEvent(event),
      );
    }
  }

  if (shouldRotateEndsForEvent(event) && strikerId && nonStrikerId) {
    [strikerId, nonStrikerId] = [nonStrikerId, strikerId];
  }

  if (
    event.isLegalDelivery &&
    legalBalls % rules.ballsPerOver === 0 &&
    legalBalls > 0 &&
    strikerId &&
    nonStrikerId
  ) {
    [strikerId, nonStrikerId] = [nonStrikerId, strikerId];
    isFreeHit = false;
  }

  return {
    ...innings,
    totalRuns,
    totalWickets,
    legalBalls,
    extras,
    strikerId,
    nonStrikerId,
    currentBowlerId: event.bowlerId || innings.currentBowlerId,
    batsmen,
    bowlers,
    partnershipRuns,
    partnershipBalls,
    isFreeHitActive: isFreeHit,
  };
}

/** Replay ball events into innings batting/bowling projection. */
function replayInnings(lineup, events, rulesInput) {
  const rules = normalizeRules(rulesInput);
  const sorted = [...events].sort((a, b) => (a.sequence || 0) - (b.sequence || 0));
  let state = baseInningsFrom(lineup, sorted);
  for (const e of sorted) {
    state = applyEventToInnings(state, e, rules);
  }
  // Restore display names from lineup
  const nameById = {};
  for (const b of lineup.batsmen || []) {
    if (b.playerId) nameById[b.playerId] = b.playerName || '';
  }
  for (const b of lineup.bowlers || []) {
    if (b.playerId) nameById[b.playerId] = b.playerName || '';
  }
  state.batsmen = state.batsmen.map((b) => ({
    ...b,
    playerName: nameById[b.playerId] || b.playerName,
  }));
  state.bowlers = state.bowlers.map((b) => ({
    ...b,
    playerName: nameById[b.playerId] || b.playerName,
  }));
  return state;
}

/** Fielding credits from wicket events only. */
function fieldersFromEvents(events) {
  const map = new Map();
  for (const e of events) {
    if (!countsAsWicket(e)) continue;
    const type = e.wicketType;
    let fielderId = e.primaryFielderId || e.fielderId;
    if (!type) continue;
    if (!fielderId && type === 'stumped' && e.wicketKeeperId) {
      fielderId = e.wicketKeeperId;
    }
    if (!fielderId) continue;

    let catches = 0;
    let runOuts = 0;
    let stumpings = 0;
    const isCaughtBehind =
      type === 'caughtBehind' || e.dismissalSubType === 'caught_behind';
    if (isCaughtBehind) {
      catches = 1;
      fielderId = e.wicketKeeperId || fielderId;
    } else if (['caught', 'caughtAndBowled'].includes(type)) {
      catches = 1;
    } else if (type === 'runOut') {
      runOuts = 1;
    } else if (type === 'stumped') {
      stumpings = 1;
      fielderId = e.wicketKeeperId || fielderId;
    } else {
      continue;
    }

    const cur = map.get(fielderId) || {
      playerId: fielderId,
      playerName: e.primaryFielderName || e.fielderName || e.wicketKeeperName || '',
      catches: 0,
      runOuts: 0,
      stumpings: 0,
    };
    map.set(fielderId, {
      playerId: fielderId,
      playerName: cur.playerName || e.fielderName || '',
      catches: cur.catches + catches,
      runOuts: cur.runOuts + runOuts,
      stumpings: cur.stumpings + stumpings,
    });
  }
  return [...map.values()];
}

function emptyPlayerAgg() {
  return {
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
  };
}

/**
 * Aggregate per-player match stats by replaying ball_events (preferred).
 */
function collectPlayerAggFromEvents(match, allEvents) {
  const rules = match.rules;
  const map = new Map();

  function get(id) {
    if (!map.has(id)) map.set(id, emptyPlayerAgg());
    return map.get(id);
  }

  for (const lineup of match.innings || []) {
    const events = allEvents.filter(
      (e) => e.inningsNumber === lineup.inningsNumber,
    );
    const derived = replayInnings(lineup, events, rules);
    const fielders = fieldersFromEvents(events);

    for (const b of derived.batsmen) {
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

    for (const bowler of derived.bowlers) {
      if (!bowler.playerId) continue;
      const a = get(bowler.playerId);
      const wkts = bowler.wickets || 0;
      a.wickets += wkts;
      a.oversBowledBalls += bowler.oversBowledBalls || 0;
      a.runsConceded += bowler.runsConceded || 0;
      a.matchWickets += wkts;
    }

    for (const fielder of fielders) {
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

/** Derived innings list for badges / hero (batting + bowling from events). */
function deriveInningsList(match, allEvents) {
  return (match.innings || []).map((lineup) => {
    const events = allEvents.filter(
      (e) => e.inningsNumber === lineup.inningsNumber,
    );
    const derived = replayInnings(lineup, events, match.rules);
    return {
      ...lineup,
      totalRuns: derived.totalRuns,
      totalWickets: derived.totalWickets,
      legalBalls: derived.legalBalls,
      extras: derived.extras,
      batsmen: derived.batsmen,
      bowlers: derived.bowlers,
      fielders: fieldersFromEvents(events),
    };
  });
}

/** Compare Firestore innings cache vs event replay; returns issue strings. */
function verifyMatchProjection(match, allEvents) {
  const issues = [];
  const rules = match.rules;

  for (const cached of match.innings || []) {
    const events = allEvents.filter(
      (e) => e.inningsNumber === cached.inningsNumber,
    );
    if (events.length === 0) continue;

    const replayed = replayInnings(cached, events, rules);
    const label = `inn${cached.inningsNumber}`;

    const compare = (field, a, b) => {
      if (a !== b) issues.push(`${label}.${field}: cache=${a} replay=${b}`);
    };

    compare('totalRuns', cached.totalRuns || 0, replayed.totalRuns);
    compare('totalWickets', cached.totalWickets || 0, replayed.totalWickets);
    compare('legalBalls', cached.legalBalls || 0, replayed.legalBalls);
    compare('extras', cached.extras || 0, replayed.extras);
    compare('strikerId', cached.strikerId || null, replayed.strikerId);
    compare(
      'nonStrikerId',
      cached.nonStrikerId || null,
      replayed.nonStrikerId,
    );

    const replayedBat = Object.fromEntries(
      replayed.batsmen.map((b) => [b.playerId, b]),
    );
    for (const b of cached.batsmen || []) {
      const r = replayedBat[b.playerId];
      if (!r) continue;
      if (
        (b.runs || 0) !== r.runs ||
        (b.balls || 0) !== r.balls ||
        !!b.isOut !== !!r.isOut
      ) {
        issues.push(
          `${label}.batsman.${b.playerId}: cache=${b.runs}/${b.balls} replay=${r.runs}/${r.balls}`,
        );
      }
    }
  }

  return issues;
}

module.exports = {
  normalizeRules,
  replayInnings,
  fieldersFromEvents,
  collectPlayerAggFromEvents,
  deriveInningsList,
  verifyMatchProjection,
};
