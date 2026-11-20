import type { BallEvent, Innings, Match, MatchRules } from "@/types/models";

function eventCountsAsWicket(e: BallEvent): boolean {
  if (e.retiredHurt) return false;
  if (e.wicketType === "retiredHurt" || e.wicketType === "retired") return false;
  if (e.isWicket) return true;
  return e.eventType === "wicket";
}

export type MvpFormatContext = {
  totalOvers: number;
  ballsPerOver: number;
  totalLegalBalls: number;
  isTestMatch: boolean;
  parRunsPerInnings: number;
  parStrikeRate: number;
  parEconomy: number;
  strikeRateWeight: number;
  economyWeight: number;
  runsWeight: number;
};

export type MvpPlayerScore = {
  playerId: string;
  playerName: string;
  teamId: string;
  teamName: string;
  photoUrl?: string;
  rank: number;
  battingMvp: number;
  bowlingMvp: number;
  fieldingMvp: number;
  clutchBonus: number;
  partnershipBonus: number;
  totalMvp: number;
  isPlayerOfTheMatch: boolean;
  isFighterOfTheMatch: boolean;
};

export type MatchMvpSnapshot = {
  players: MvpPlayerScore[];
  formatContext?: MvpFormatContext;
  losingTeamId?: string;
  teamAId?: string;
  teamBId?: string;
  hasData: boolean;
  isLive: boolean;
};

type PlayerAccum = {
  playerId: string;
  playerName: string;
  teamId: string;
  teamName: string;
  photoUrl?: string;
  runs: number;
  balls: number;
  fours: number;
  sixes: number;
  deathBatRuns: number;
  wickets: number;
  runsConceded: number;
  legalBallsBowled: number;
  dotBallsBowled: number;
  maidens: number;
  wicketValueSum: number;
  deathWickets: number;
  deathDotBalls: number;
  catches: number;
  importantCatches: number;
  runOuts: number;
  directHitRunOuts: number;
  stumpings: number;
  clutchBonus: number;
  partnershipBonus: number;
};

function clamp(n: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, n));
}

function isTestMatch(rules: MatchRules): boolean {
  return String(rules.cricketMatchType) === "testMatch";
}

export function classifyOver(
  overNumber: number,
  rules: MatchRules,
): "powerplay" | "middle" | "death" | "normal" {
  if (isTestMatch(rules)) return "normal";
  const totalOvers = rules.totalOvers || 20;
  if (overNumber < 1 || overNumber > totalOvers) return "normal";
  const slots = rules.powerplaySlots;
  const hasCustom = Boolean(slots?.some((slot) => slot.length));
  if (hasCustom && slots) {
    if ((slots[0] ?? []).includes(overNumber) || (slots[1] ?? []).includes(overNumber)) {
      return "powerplay";
    }
    if ((slots[2] ?? []).includes(overNumber)) return "death";
  }
  if (rules.powerplayOvers != null && overNumber <= rules.powerplayOvers) return "powerplay";
  const total = clamp(totalOvers, 1, 999);
  const powerplayEnd =
    rules.powerplayOvers != null
      ? clamp(rules.powerplayOvers, 1, total)
      : Math.max(1, Math.round(total * 0.3));
  const deathLength = Math.max(1, Math.round(total * 0.25));
  let deathStart = Math.max(1, total - deathLength + 1);
  if (deathStart <= powerplayEnd) deathStart = powerplayEnd + 1;
  const deathEnd = total;
  const start = deathStart <= deathEnd ? deathStart : deathEnd;
  const middleStart = powerplayEnd + 1;
  const middleEnd = deathStart - 1;
  if (overNumber >= 1 && overNumber <= powerplayEnd) return "powerplay";
  if (overNumber >= start && overNumber <= deathEnd) return "death";
  if (middleStart <= middleEnd && overNumber >= middleStart && overNumber <= middleEnd) {
    return "middle";
  }
  return "normal";
}

export function eventsForInnings(all: BallEvent[], inningsNumber: number): BallEvent[] {
  return all
    .filter((e) => e.inningsNumber === inningsNumber)
    .slice()
    .sort((a, b) => a.sequence - b.sequence);
}

export function fallOfWicketsFromEvents(events: BallEvent[]) {
  let totalRuns = 0;
  let legalBalls = 0;
  let wickets = 0;
  const result: Array<{ wicketNumber: number; batsmanId: string }> = [];
  for (const e of events) {
    totalRuns += e.runs;
    if (e.isLegalDelivery) legalBalls += 1;
    if (!eventCountsAsWicket(e)) continue;
    wickets += 1;
    const dismissed = e.dismissedPlayerId || e.strikerId;
    if (!dismissed) continue;
    result.push({ wicketNumber: wickets, batsmanId: dismissed });
  }
  return result;
}

export function partnershipsFromEvents(events: BallEvent[]) {
  let aId: string | undefined;
  let bId: string | undefined;
  let runs = 0;
  let balls = 0;
  const result: Array<{ batterAId: string; batterBId: string; runs: number; balls: number }> = [];

  function setCrease(striker?: string, nonStriker?: string) {
    if (striker && nonStriker && striker !== nonStriker) {
      aId = striker;
      bId = nonStriker;
      return;
    }
    if (striker) {
      if (!aId || aId === striker || bId === striker) aId ??= striker;
      else if (!bId) bId = striker;
      else if (aId && !bId) bId = striker;
      else if (bId && !aId) aId = striker;
    }
    if (nonStriker) {
      if (!bId && nonStriker !== aId) bId = nonStriker;
      else if (!aId && nonStriker !== bId) aId = nonStriker;
    }
  }

  for (const e of events) {
    if (e.eventType === "lineupChange" || e.eventType === "batterSwap") {
      setCrease(e.strikerId, e.nonStrikerId);
      continue;
    }
    runs += e.runs;
    if (e.isLegalDelivery) balls += 1;
    setCrease(e.strikerId, e.nonStrikerId);
    if (e.eventType === "wicket" && (e.retiredHurt || e.wicketType === "retiredHurt" || e.wicketType === "retired")) {
      const retired = e.dismissedPlayerId || e.strikerId;
      if (retired) {
        if (retired === aId) aId = undefined;
        if (retired === bId) bId = undefined;
      }
      continue;
    }
    if (!eventCountsAsWicket(e)) continue;
    const left = e.strikerId || aId;
    const right = e.nonStrikerId || bId;
    if ((runs > 0 || balls > 0) && left && right && left !== right) {
      const sorted = [left, right].sort();
      result.push({ batterAId: sorted[0], batterBId: sorted[1], runs, balls });
    }
    runs = 0;
    balls = 0;
    const dismissed = e.dismissedPlayerId || e.strikerId;
    if (dismissed) {
      const survivor = left === dismissed ? right : right === dismissed ? left : undefined;
      aId = survivor;
      bId = undefined;
    } else {
      aId = undefined;
      bId = undefined;
    }
  }
  return result;
}

function runsAgainstBowler(event: BallEvent): number {
  if (event.eventType === "bye" || event.eventType === "legBye") return 0;
  return event.runs;
}

export function maidenOversFromEvents(events: BallEvent[], rules: MatchRules): Record<string, number> {
  const eventsByOver = new Map<string, BallEvent[]>();
  for (const e of events) {
    if (e.countsInOver === false || e.countsToBowler === false) continue;
    const bowlerId = (e.bowlerId ?? "").trim();
    if (!bowlerId) continue;
    const key = `${e.inningsNumber}|${e.overNumber}`;
    const list = eventsByOver.get(key) ?? [];
    list.push(e);
    eventsByOver.set(key, list);
  }
  const maidens: Record<string, number> = {};
  const ballsPerOver = clamp(rules.ballsPerOver || 6, 1, 12);
  for (const overEvents of eventsByOver.values()) {
    const legalBalls = overEvents.filter((e) => e.isLegalDelivery).length;
    if (legalBalls < ballsPerOver) continue;
    const bowlers = new Set(
      overEvents.map((e) => (e.bowlerId ?? "").trim()).filter(Boolean),
    );
    if (bowlers.size !== 1) continue;
    const runsConceded = overEvents.reduce((total, event) => total + runsAgainstBowler(event), 0);
    if (runsConceded === 0) {
      const bowlerId = [...bowlers][0];
      maidens[bowlerId] = (maidens[bowlerId] ?? 0) + 1;
    }
  }
  return maidens;
}

export function parRunRate(totalOvers: number): number {
  if (totalOvers <= 4) return 10.0;
  if (totalOvers <= 5) return 9.5;
  if (totalOvers <= 6) return 9.2;
  if (totalOvers <= 8) return 9.0;
  if (totalOvers <= 10) return 8.5;
  if (totalOvers <= 15) return 7.5;
  if (totalOvers <= 20) return 7.0;
  if (totalOvers <= 30) return 6.0;
  if (totalOvers <= 40) return 5.5;
  return 5.0;
}

export function formatExpectedRuns(totalOvers: number, isTest: boolean): number {
  if (isTest) return 280.0;
  return totalOvers * parRunRate(totalOvers);
}

export function parStrikeRate(totalOvers: number, isTest: boolean): number {
  if (isTest) return 52.0;
  if (totalOvers <= 8) return 145.0;
  if (totalOvers <= 10) return 135.0;
  if (totalOvers <= 15) return 120.0;
  if (totalOvers <= 20) return 115.0;
  if (totalOvers <= 30) return 95.0;
  return 82.0;
}

export function parEconomy(totalOvers: number, isTest: boolean): number {
  if (isTest) return 3.2;
  if (totalOvers <= 8) return 8.0;
  if (totalOvers <= 10) return 7.8;
  if (totalOvers <= 15) return 7.2;
  if (totalOvers <= 20) return 7.0;
  if (totalOvers <= 30) return 6.2;
  return 5.5;
}

export function strikeRateWeight(totalOvers: number, isTest: boolean): number {
  if (isTest) return 0.12;
  if (totalOvers <= 8) return 1.05;
  if (totalOvers <= 10) return 1.0;
  if (totalOvers <= 15) return 0.82;
  if (totalOvers <= 20) return 0.72;
  if (totalOvers <= 30) return 0.55;
  return 0.42;
}

export function economyWeight(totalOvers: number, isTest: boolean): number {
  if (isTest) return 0.55;
  if (totalOvers <= 8) return 1.05;
  if (totalOvers <= 10) return 1.0;
  if (totalOvers <= 20) return 0.85;
  if (totalOvers <= 30) return 0.72;
  return 0.62;
}

export function runsWeight(totalOvers: number, isTest: boolean): number {
  if (isTest) return 1.15;
  if (totalOvers <= 8) return 0.88;
  if (totalOvers <= 20) return 1.0;
  return 1.08;
}

export function wicketValue(battingOrder: number, maxWickets: number): number {
  const order = clamp(battingOrder, 1, clamp(maxWickets, 1, 10));
  const weight = 1.0 - (order - 1) * 0.075;
  return clamp(weight, 0.35, 1.0) * 1.25;
}

function losingTeamId(match: Match): string | undefined {
  const winner = match.winnerTeamId;
  if (!winner) return undefined;
  if (winner === match.teamAId) return match.teamBId;
  if (winner === match.teamBId) return match.teamAId;
  return undefined;
}

export function formatContext(match: Match, rules: MatchRules): MvpFormatContext {
  const test = isTestMatch(rules);
  const totalOvers = test ? 90 : clamp(rules.totalOvers || 20, 1, 999);
  const ballsPerOver = clamp(rules.ballsPerOver || 6, 1, 12);
  const inningsTotals = (match.innings ?? [])
    .filter((i) => i.totalRuns > 0)
    .map((i) => i.totalRuns);
  const formatPar = formatExpectedRuns(totalOvers, test);
  let parRuns = formatPar;
  if (inningsTotals.length) {
    const matchAvg = inningsTotals.reduce((a, b) => a + b, 0) / inningsTotals.length;
    const matchPeak = inningsTotals.reduce((a, b) => (a > b ? a : b), 0);
    parRuns = clamp(formatPar * 0.35 + matchAvg * 0.35 + matchPeak * 0.3, 8, 800);
  }
  return {
    totalOvers,
    ballsPerOver,
    totalLegalBalls: totalOvers * ballsPerOver,
    isTestMatch: test,
    parRunsPerInnings: parRuns,
    parStrikeRate: parStrikeRate(totalOvers, test),
    parEconomy: parEconomy(totalOvers, test),
    strikeRateWeight: strikeRateWeight(totalOvers, test),
    economyWeight: economyWeight(totalOvers, test),
    runsWeight: runsWeight(totalOvers, test),
  };
}

function battingMvp(p: PlayerAccum, ctx: MvpFormatContext): number {
  if (p.balls === 0 && p.runs === 0) return 0;
  const runsScore = (p.runs / ctx.parRunsPerInnings) * 4.2 * ctx.runsWeight;
  const sr = p.balls === 0 ? 0 : (p.runs / p.balls) * 100;
  const srDelta = sr - ctx.parStrikeRate;
  const srBonus = srDelta > 0 ? (srDelta / ctx.parStrikeRate) * ctx.strikeRateWeight * 1.75 : 0;
  const boundaryBalls = p.fours + p.sixes;
  const boundaryPct = p.balls > 0 ? boundaryBalls / p.balls : 0;
  const boundaryBonus = boundaryPct * ctx.strikeRateWeight * 0.85;
  const deathBonus =
    p.deathBatRuns > 0 ? (p.deathBatRuns / ctx.parRunsPerInnings) * ctx.strikeRateWeight * 0.9 : 0;
  return runsScore + srBonus + boundaryBonus + deathBonus;
}

function bowlingMvp(p: PlayerAccum, ctx: MvpFormatContext): number {
  if (p.legalBallsBowled === 0 && p.wickets === 0) return 0;
  const oversBowled = p.legalBallsBowled / ctx.ballsPerOver;
  const economy =
    p.legalBallsBowled <= 0 ? 0 : p.runsConceded / (p.legalBallsBowled / ctx.ballsPerOver);
  const econDelta = ctx.parEconomy - economy;
  const econScore =
    econDelta > 0 ? (econDelta / ctx.parEconomy) * ctx.economyWeight * oversBowled * 0.38 : 0;
  const wicketScore = p.wicketValueSum * ctx.economyWeight * 1.05;
  const dotPct = p.legalBallsBowled > 0 ? p.dotBallsBowled / p.legalBallsBowled : 0;
  const dotScore = dotPct * oversBowled * 0.28;
  const maidenScore = p.maidens * 0.42 * ctx.economyWeight;
  const deathScore = p.deathWickets * 0.65 + p.deathDotBalls * 0.018;
  return wicketScore + econScore + dotScore + maidenScore + deathScore;
}

function fieldingMvp(p: PlayerAccum, ctx: MvpFormatContext): number {
  if (p.catches === 0 && p.runOuts === 0 && p.directHitRunOuts === 0 && p.stumpings === 0) return 0;
  const scale = ctx.isTestMatch ? 1.15 : 1.0;
  return (
    scale *
    (p.catches * 0.78 +
      p.importantCatches * 0.42 +
      (p.runOuts - p.directHitRunOuts) * 0.55 +
      p.directHitRunOuts * 1.35 +
      p.stumpings * 0.88)
  );
}

export function applyAwards(opts: {
  players: MvpPlayerScore[];
  losingTeamId?: string;
  winnerTeamId?: string;
  teamAId?: string;
  teamBId?: string;
  format: MvpFormatContext;
  isLive?: boolean;
}): MatchMvpSnapshot {
  const { players, losingTeamId, winnerTeamId, teamAId, teamBId, format, isLive = false } = opts;
  if (!players.length) {
    return { players: [], hasData: false, isLive, formatContext: format, losingTeamId, teamAId, teamBId };
  }
  const decided = Boolean(winnerTeamId && (winnerTeamId === teamAId || winnerTeamId === teamBId));
  const potm = decided ? players.find((p) => p.teamId === winnerTeamId) ?? players[0] : players[0];
  let result = players.map((p) => ({ ...p, isPlayerOfTheMatch: p.playerId === potm.playerId }));
  let fighterId: string | undefined;
  if (losingTeamId && winnerTeamId && potm.teamId !== losingTeamId) {
    const losingSorted = result
      .filter((p) => p.teamId === losingTeamId)
      .slice()
      .sort((a, b) => b.totalMvp - a.totalMvp);
    const eligibleIds = new Set(losingSorted.slice(0, 3).map((p) => p.playerId));
    for (const p of result) {
      if (eligibleIds.has(p.playerId)) {
        fighterId = p.playerId;
        break;
      }
    }
  }
  if (fighterId) {
    result = result.map((p) => ({ ...p, isFighterOfTheMatch: p.playerId === fighterId }));
  }
  return {
    players: result,
    hasData: true,
    isLive,
    formatContext: format,
    losingTeamId,
    teamAId,
    teamBId,
  };
}

type SetupPlayer = { id: string; name: string; photoUrl?: string };

function setupPlayers(setup: Record<string, unknown> | undefined, key: string): SetupPlayer[] {
  const list = setup?.[key];
  if (!Array.isArray(list)) return [];
  const out: SetupPlayer[] = [];
  for (const item of list) {
    if (!item || typeof item !== "object") continue;
    const rec = item as Record<string, unknown>;
    const id = String(rec.id ?? "");
    if (!id) continue;
    out.push({
      id,
      name: String(rec.name ?? ""),
      photoUrl: typeof rec.photoUrl === "string" ? rec.photoUrl : undefined,
    });
  }
  return out;
}

export function buildMatchMvp(match: Match, ballEvents: BallEvent[]): MatchMvpSnapshot {
  if (!ballEvents.length) {
    return { players: [], hasData: false, isLive: match.status === "live" };
  }
  const rules = match.rules;
  const format = formatContext(match, rules);
  const setup = (match.setup as Record<string, unknown> | undefined) ?? undefined;
  const registry = new Map<string, { name: string; teamId: string; teamName: string; photoUrl?: string }>();
  const addList = (
    list: Array<{ id: string; name: string; photoUrl?: string }>,
    teamId: string,
    teamName: string,
  ) => {
    for (const p of list) {
      registry.set(p.id, { name: p.name, teamId, teamName, photoUrl: p.photoUrl });
    }
  };
  addList(setupPlayers(setup, "teamAPlayingPlayers"), match.teamAId ?? "", match.teamAName);
  addList(setupPlayers(setup, "teamASubstitutePlayers"), match.teamAId ?? "", match.teamAName);
  addList(setupPlayers(setup, "teamBPlayingPlayers"), match.teamBId ?? "", match.teamBName);
  addList(setupPlayers(setup, "teamBSubstitutePlayers"), match.teamBId ?? "", match.teamBName);

  const accum = new Map<string, PlayerAccum>();
  const ensurePlayer = (playerId: string, name: string, teamId: string, teamName: string) => {
    if (!playerId) return;
    const existing = accum.get(playerId);
    if (existing) {
      if (!existing.playerName && name) existing.playerName = name;
      if (!existing.teamId && teamId) {
        existing.teamId = teamId;
        existing.teamName = teamName;
      }
      return;
    }
    const meta = registry.get(playerId);
    accum.set(playerId, {
      playerId,
      playerName: name || meta?.name || "Player",
      teamId: teamId || meta?.teamId || "",
      teamName: teamName || meta?.teamName || "",
      photoUrl: meta?.photoUrl,
      runs: 0,
      balls: 0,
      fours: 0,
      sixes: 0,
      deathBatRuns: 0,
      wickets: 0,
      runsConceded: 0,
      legalBallsBowled: 0,
      dotBallsBowled: 0,
      maidens: 0,
      wicketValueSum: 0,
      deathWickets: 0,
      deathDotBalls: 0,
      catches: 0,
      importantCatches: 0,
      runOuts: 0,
      directHitRunOuts: 0,
      stumpings: 0,
      clutchBonus: 0,
      partnershipBonus: 0,
    });
  };

  const teamNameFor = (teamId?: string) => {
    if (!teamId) return "";
    if (teamId === match.teamAId) return match.teamAName;
    if (teamId === match.teamBId) return match.teamBName;
    return "";
  };

  const winnerId = match.winnerTeamId;
  const losingId = losingTeamId(match);

  for (const lineupInnings of match.innings ?? []) {
    const events = eventsForInnings(ballEvents, lineupInnings.inningsNumber);
    if (!events.length) continue;
    const innings: Innings = lineupInnings;
    const battingTeamId = innings.battingTeamId;
    const bowlingTeamId = innings.bowlingTeamId;
    const battingTeamName = teamNameFor(battingTeamId);
    const bowlingTeamName = teamNameFor(bowlingTeamId);
    const isChaseInnings = innings.inningsNumber >= 2;
    const battingWon = Boolean(winnerId && winnerId === battingTeamId);
    const bowlingWon = Boolean(winnerId && winnerId === bowlingTeamId);
    const fow = fallOfWicketsFromEvents(events);
    const battingOrder: Record<string, number> = {};
    for (const f of fow) battingOrder[f.batsmanId] = f.wicketNumber;
    const maidens = maidenOversFromEvents(events, rules);

    for (const b of innings.batsmen ?? []) {
      if (!b.playerId) continue;
      ensurePlayer(b.playerId, b.playerName, battingTeamId, battingTeamName);
      const p = accum.get(b.playerId)!;
      p.runs += b.runs;
      p.balls += b.balls;
      p.fours += b.fours;
      p.sixes += b.sixes;
    }
    for (const b of innings.bowlers ?? []) {
      if (!b.playerId) continue;
      ensurePlayer(b.playerId, b.playerName, bowlingTeamId, bowlingTeamName);
      const p = accum.get(b.playerId)!;
      p.runsConceded += b.runsConceded;
      p.legalBallsBowled += b.oversBowledBalls;
      p.wickets += b.wickets;
      p.maidens += maidens[b.playerId] ?? 0;
    }

    // If scorecards are empty (or only lineup stubs), derive batting/bowling
    // totals from events — the Dart service gets these from ScoringEngine replay.
    const batCardBalls = new Map<string, number>();
    for (const b of innings.batsmen ?? []) batCardBalls.set(b.playerId, (batCardBalls.get(b.playerId) ?? 0) + b.balls);
    const bowlCardBalls = new Map<string, number>();
    for (const b of innings.bowlers ?? []) bowlCardBalls.set(b.playerId, (bowlCardBalls.get(b.playerId) ?? 0) + b.oversBowledBalls);
    for (const e of events) {
      if (e.strikerId && (e.countsAsBallFaced || (e.isLegalDelivery && e.eventType !== "wide" && e.eventType !== "noBall"))) {
        if (!(batCardBalls.get(e.strikerId) ?? 0)) {
          ensurePlayer(e.strikerId, "", battingTeamId, battingTeamName);
          const p = accum.get(e.strikerId)!;
          const br = e.batsmanRuns || (e.eventType === "runs" ? e.runs : 0);
          p.balls += 1;
          p.runs += br;
          if (e.isBoundary || br >= 4) {
            if (e.boundaryType === "six" || br >= 6) p.sixes += 1;
            else p.fours += 1;
          }
        }
      }
      if (e.bowlerId && e.countsToBowler !== false) {
        if (!(bowlCardBalls.get(e.bowlerId) ?? 0)) {
          ensurePlayer(e.bowlerId, "", bowlingTeamId, bowlingTeamName);
          const p = accum.get(e.bowlerId)!;
          if (e.isLegalDelivery) p.legalBallsBowled += 1;
          if (e.eventType !== "bye" && e.eventType !== "legBye") p.runsConceded += e.runs;
          if (e.bowlerGetsWicket) p.wickets += 1;
        }
      }
    }
    for (const [id, count] of Object.entries(maidens)) {
      if (!(bowlCardBalls.get(id) ?? 0)) {
        ensurePlayer(id, "", bowlingTeamId, bowlingTeamName);
        accum.get(id)!.maidens += count;
      }
    }

    scanEvents({
      events,
      rules,
      accum,
      battingOrder,
      bowlingTeamId,
      bowlingTeamName,
      ensurePlayer,
      isChaseInnings,
      battingWon,
      bowlingWon,
      battingTeamId,
      battingTeamName,
    });

    const partnerships = partnershipsFromEvents(events);
    const threshold = format.parRunsPerInnings * 0.22;
    for (const partnership of partnerships) {
      if (partnership.runs < threshold) continue;
      const bonus = clamp(partnership.runs / format.parRunsPerInnings, 0, 1.2) * 0.55;
      for (const id of [partnership.batterAId, partnership.batterBId]) {
        if (!id) continue;
        ensurePlayer(id, "", battingTeamId, battingTeamName);
        accum.get(id)!.partnershipBonus += bonus / 2;
      }
    }
  }

  const scored = [...accum.values()]
    .map((p) => {
      const batting = battingMvp(p, format);
      const bowling = bowlingMvp(p, format);
      const fielding = fieldingMvp(p, format);
      const total = batting + bowling + fielding + p.clutchBonus + p.partnershipBonus;
      return {
        playerId: p.playerId,
        playerName: p.playerName,
        teamId: p.teamId,
        teamName: p.teamName,
        photoUrl: p.photoUrl,
        rank: 0,
        battingMvp: batting,
        bowlingMvp: bowling,
        fieldingMvp: fielding,
        clutchBonus: p.clutchBonus,
        partnershipBonus: p.partnershipBonus,
        totalMvp: total,
        isPlayerOfTheMatch: false,
        isFighterOfTheMatch: false,
      } satisfies MvpPlayerScore;
    })
    .filter((s) => s.totalMvp > 0.001)
    .sort((a, b) => b.totalMvp - a.totalMvp)
    .map((s, i) => ({ ...s, rank: i + 1 }));

  return applyAwards({
    players: scored,
    losingTeamId: losingId,
    winnerTeamId: winnerId,
    teamAId: match.teamAId,
    teamBId: match.teamBId,
    isLive: match.status === "live",
    format,
  });
}

function scanEvents(opts: {
  events: BallEvent[];
  rules: MatchRules;
  accum: Map<string, PlayerAccum>;
  battingOrder: Record<string, number>;
  bowlingTeamId: string;
  bowlingTeamName: string;
  ensurePlayer: (id: string, name: string, teamId: string, teamName: string) => void;
  isChaseInnings: boolean;
  battingWon: boolean;
  bowlingWon: boolean;
  battingTeamId: string;
  battingTeamName: string;
}) {
  let recentWicketBallIndex = -999;
  let wicketsInBurst = 0;
  for (let i = 0; i < opts.events.length; i++) {
    const e = opts.events[i];
    const isDeath = classifyOver(e.overNumber, opts.rules) === "death";
    if (e.bowlerId && e.isLegalDelivery) {
      opts.ensurePlayer(e.bowlerId, "", opts.bowlingTeamId, opts.bowlingTeamName);
      const bowler = opts.accum.get(e.bowlerId)!;
      if (e.runs === 0 && e.eventType !== "wide" && e.eventType !== "noBall") {
        bowler.dotBallsBowled += 1;
        if (isDeath) bowler.deathDotBalls += 1;
      }
    }
    if (e.strikerId && e.isLegalDelivery && e.runs > 0) {
      opts.ensurePlayer(e.strikerId, "", opts.battingTeamId, opts.battingTeamName);
      const batter = opts.accum.get(e.strikerId)!;
      if (isDeath) batter.deathBatRuns += e.runs;
    }
    if (!eventCountsAsWicket(e)) continue;
    const dismissedId = e.dismissedPlayerId || e.strikerId || "";
    const order = opts.battingOrder[dismissedId] ?? 8;
    const wicketVal = wicketValue(order, opts.rules.maxWickets ?? 10);
    if (e.bowlerId) {
      opts.ensurePlayer(e.bowlerId, "", opts.bowlingTeamId, opts.bowlingTeamName);
      const bowler = opts.accum.get(e.bowlerId)!;
      if (e.wicketType !== "runOut") {
        bowler.wicketValueSum += wicketVal;
        if (isDeath) bowler.deathWickets += 1;
      }
    }
    creditFielding(e, order, opts);
    if (i - recentWicketBallIndex <= 6) wicketsInBurst += 1;
    else wicketsInBurst = 1;
    recentWicketBallIndex = i;
    if (wicketsInBurst >= 2 && e.bowlerId) {
      opts.ensurePlayer(e.bowlerId, "", opts.bowlingTeamId, opts.bowlingTeamName);
      opts.accum.get(e.bowlerId)!.clutchBonus += 0.38;
    }
    if (opts.isChaseInnings && opts.battingWon && isDeath && e.strikerId) {
      opts.ensurePlayer(e.strikerId, "", opts.battingTeamId, opts.battingTeamName);
      opts.accum.get(e.strikerId)!.clutchBonus += 0.12;
    }
    if (!opts.isChaseInnings && opts.bowlingWon && isDeath && e.bowlerId) {
      opts.ensurePlayer(e.bowlerId, "", opts.bowlingTeamId, opts.bowlingTeamName);
      opts.accum.get(e.bowlerId)!.clutchBonus += 0.14;
    }
  }
}

function creditFielding(
  e: BallEvent,
  order: number,
  opts: {
    accum: Map<string, PlayerAccum>;
    bowlingTeamId: string;
    bowlingTeamName: string;
    ensurePlayer: (id: string, name: string, teamId: string, teamName: string) => void;
  },
) {
  const type = e.wicketType;
  if (!type) return;
  const credit = (
    id: string,
    flags: { isCatch?: boolean; runOut?: boolean; direct?: boolean; stumping?: boolean },
  ) => {
    if (!id) return;
    opts.ensurePlayer(id, "", opts.bowlingTeamId, opts.bowlingTeamName);
    const p = opts.accum.get(id)!;
    if (flags.isCatch) {
      p.catches += 1;
      if (order <= 3) p.importantCatches += 1;
    }
    if (flags.runOut && !flags.direct) p.runOuts += 1;
    if (flags.direct) {
      p.runOuts += 1;
      p.directHitRunOuts += 1;
    }
    if (flags.stumping) p.stumpings += 1;
  };
  if (type === "caught" || type === "caughtBehind") {
    credit(e.primaryFielderId || e.fielderId || e.wicketKeeperId || "", { isCatch: true });
  } else if (type === "caughtAndBowled") {
    // no fielding credit
  } else if (type === "runOut") {
    const directId = e.primaryFielderId || e.fielderId;
    const assistIds = (e.fielders ?? []).map((f) => f.playerId).filter(Boolean);
    if (directId) {
      const isDirect = assistIds.length === 0 || (assistIds.length === 1 && assistIds[0] === directId);
      credit(directId, { runOut: !isDirect, direct: isDirect });
    }
    for (const assist of assistIds) {
      if (assist === directId) continue;
      credit(assist, { runOut: true });
    }
  } else if (type === "stumped") {
    credit(e.wicketKeeperId || e.primaryFielderId || "", { stumping: true });
  }
}
