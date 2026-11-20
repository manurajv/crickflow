import type { BallEvent, BatsmanInnings, Match, MatchRules } from "@/types/models";

/** Mirrors player_cluster_service.dart exactly. */
export const MIN_BATTING_INNINGS = 5;
export const MIN_BOWLING_MATCHES = 3;

export type BattingClusterType =
  | "steadyBatter"
  | "classicist"
  | "accumulator"
  | "hardHitter"
  | "destroyer";

export type BowlingClusterType = "aspirant" | "wildcard" | "economist" | "spearhead";

export const BATTING_CLUSTER_LABELS: Record<BattingClusterType, string> = {
  steadyBatter: "Steady Batter",
  classicist: "Classicist",
  accumulator: "Accumulator",
  hardHitter: "Hard Hitter",
  destroyer: "Destroyer",
};

export const BOWLING_CLUSTER_LABELS: Record<BowlingClusterType, string> = {
  aspirant: "Aspirant",
  wildcard: "Wildcard",
  economist: "Economist",
  spearhead: "Spearhead",
};

export type BattingPatternStats = {
  balls: number;
  runs: number;
  strikeRate: number;
  dotPct: number;
  singlesPct: number;
  doublesPct: number;
  triplesPct: number;
  boundaryPct: number;
  sixPct: number;
  inningsCount: number;
  matchCount: number;
};

export type BowlingPatternStats = {
  wickets: number;
  economy: number;
  average: number;
  strikeRate: number;
  dotPct: number;
  oversBowled: number;
  matchCount: number;
};

export const emptyBattingPattern: BattingPatternStats = {
  balls: 0,
  runs: 0,
  strikeRate: 0,
  dotPct: 0,
  singlesPct: 0,
  doublesPct: 0,
  triplesPct: 0,
  boundaryPct: 0,
  sixPct: 0,
  inningsCount: 0,
  matchCount: 0,
};

export const emptyBowlingPattern: BowlingPatternStats = {
  wickets: 0,
  economy: 0,
  average: 0,
  strikeRate: 0,
  dotPct: 0,
  oversBowled: 0,
  matchCount: 0,
};

export type PlayerClusters = {
  batting?: BattingClusterType | null;
  bowling?: BowlingClusterType | null;
  battingPattern: BattingPatternStats;
  bowlingPattern: BowlingPatternStats;
};

export function clusterTagLabels(clusters: PlayerClusters): string[] {
  const tags: string[] = [];
  if (clusters.batting) tags.push(BATTING_CLUSTER_LABELS[clusters.batting]);
  if (clusters.bowling) tags.push(BOWLING_CLUSTER_LABELS[clusters.bowling]);
  return tags;
}

export function classifyBatting(s: BattingPatternStats): BattingClusterType {
  if (s.strikeRate >= 160 && s.boundaryPct >= 18) return "destroyer";
  if (s.strikeRate >= 130 && s.boundaryPct >= 12) return "hardHitter";
  if (s.singlesPct >= 35 && s.dotPct <= 45 && s.strikeRate < 120) return "accumulator";
  if (s.doublesPct >= 12 && s.dotPct <= 40) return "classicist";
  if (s.dotPct >= 50 && s.strikeRate < 100) return "steadyBatter";
  if (s.strikeRate >= 120) return "hardHitter";
  if (s.singlesPct >= 30) return "accumulator";
  return "classicist";
}

export function classifyBowling(s: BowlingPatternStats): BowlingClusterType {
  if (s.wickets < 5 && s.oversBowled < 10) return "aspirant";
  if (s.wickets >= 15 && s.economy <= 7 && s.average <= 22) return "spearhead";
  if (s.economy <= 6.5 && s.wickets >= 8) return "economist";
  if (s.wickets >= 10 && s.economy > 8) return "wildcard";
  if (s.economy <= 7) return "economist";
  if (s.wickets >= 8) return "wildcard";
  return "aspirant";
}

function battingFromEvents(playerId: string, events: BallEvent[]): BattingPatternStats {
  let balls = 0;
  let runs = 0;
  let dots = 0;
  let singles = 0;
  let doubles = 0;
  let triples = 0;
  let boundaries = 0;
  let sixes = 0;
  const inningsSeen = new Set<number>();

  for (const e of events) {
    if (e.strikerId !== playerId) continue;
    if (!e.countsAsBallFaced) continue;
    balls += 1;
    inningsSeen.add(e.inningsNumber);
    const br = e.batsmanRuns ?? 0;
    runs += br;
    if (e.isBoundary) {
      boundaries += 1;
      if (e.boundaryType === "six" || br >= 6) sixes += 1;
    } else if (br === 0) {
      dots += 1;
    } else if (br === 1) {
      singles += 1;
    } else if (br === 2) {
      doubles += 1;
    } else if (br === 3) {
      triples += 1;
    } else if (br >= 4) {
      boundaries += 1;
      if (br >= 6) sixes += 1;
    }
  }

  if (balls === 0) return emptyBattingPattern;
  return {
    balls,
    runs,
    strikeRate: (runs / balls) * 100,
    dotPct: (dots / balls) * 100,
    singlesPct: (singles / balls) * 100,
    doublesPct: (doubles / balls) * 100,
    triplesPct: (triples / balls) * 100,
    boundaryPct: (boundaries / balls) * 100,
    sixPct: (sixes / balls) * 100,
    inningsCount: inningsSeen.size,
    matchCount: 1,
  };
}

function clampInt(value: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, value));
}

function estimatePatternFromInnings(b: BatsmanInnings) {
  const boundaryBalls = b.fours + b.sixes;
  const nonBoundaryRuns = b.runs - (b.fours * 4 + b.sixes * 6);
  const nonBoundaryBalls = clampInt(b.balls - boundaryBalls, 0, b.balls);
  let singles = clampInt(nonBoundaryRuns, 0, nonBoundaryBalls);
  let doubles = 0;
  let triples = 0;
  let remainingRuns = nonBoundaryRuns - singles;
  if (remainingRuns > 0 && nonBoundaryBalls > singles) {
    doubles = clampInt(Math.floor(remainingRuns / 2), 0, nonBoundaryBalls - singles);
    remainingRuns -= doubles * 2;
    if (remainingRuns >= 3 && nonBoundaryBalls > singles + doubles) {
      triples = 1;
      remainingRuns -= 3;
    }
    singles += clampInt(remainingRuns, 0, nonBoundaryBalls - doubles - triples);
  }
  const scoringBalls = singles + doubles + triples + boundaryBalls;
  const dots = clampInt(b.balls - scoringBalls, 0, b.balls);
  return { dots, singles, doubles, triples };
}

export function computeClusters(
  playerId: string,
  completedMatches: Match[],
  ballEventsByMatch: Record<string, BallEvent[]> = {},
): PlayerClusters {
  let balls = 0;
  let runs = 0;
  let dots = 0;
  let singles = 0;
  let doubles = 0;
  let triples = 0;
  let boundaries = 0;
  let sixes = 0;
  let inningsCount = 0;
  const batMatchIds = new Set<string>();

  for (const match of completedMatches) {
    const events = ballEventsByMatch[match.id];
    if (events && events.length) {
      const fromEvents = battingFromEvents(playerId, events);
      if (fromEvents.balls === 0) continue;
      balls += fromEvents.balls;
      runs += fromEvents.runs;
      dots += Math.round((fromEvents.dotPct * fromEvents.balls) / 100);
      singles += Math.round((fromEvents.singlesPct * fromEvents.balls) / 100);
      doubles += Math.round((fromEvents.doublesPct * fromEvents.balls) / 100);
      triples += Math.round((fromEvents.triplesPct * fromEvents.balls) / 100);
      boundaries += Math.round((fromEvents.boundaryPct * fromEvents.balls) / 100);
      sixes += Math.round((fromEvents.sixPct * fromEvents.balls) / 100);
      inningsCount += fromEvents.inningsCount;
      batMatchIds.add(match.id);
      continue;
    }
    for (const inn of match.innings ?? []) {
      for (const b of inn.batsmen ?? []) {
        if (b.playerId !== playerId || b.balls <= 0) continue;
        inningsCount += 1;
        batMatchIds.add(match.id);
        balls += b.balls;
        runs += b.runs;
        sixes += b.sixes;
        boundaries += b.fours + b.sixes;
        const est = estimatePatternFromInnings(b);
        dots += est.dots;
        singles += est.singles;
        doubles += est.doubles;
        triples += est.triples;
      }
    }
  }

  const battingPattern: BattingPatternStats =
    balls === 0
      ? emptyBattingPattern
      : {
          balls,
          runs,
          strikeRate: (runs / balls) * 100,
          dotPct: (dots / balls) * 100,
          singlesPct: (singles / balls) * 100,
          doublesPct: (doubles / balls) * 100,
          triplesPct: (triples / balls) * 100,
          boundaryPct: (boundaries / balls) * 100,
          sixPct: (sixes / balls) * 100,
          inningsCount,
          matchCount: batMatchIds.size,
        };

  let wickets = 0;
  let runsConceded = 0;
  let legalBalls = 0;
  let bowlDots = 0;
  let oversBowled = 0;
  const bowlMatchIds = new Set<string>();

  for (const match of completedMatches) {
    const bpo = match.rules.ballsPerOver || 6;
    const events = ballEventsByMatch[match.id];
    let foundInMatch = false;
    let legalBefore = legalBalls;

    if (events && events.length) {
      for (const e of events) {
        if (e.bowlerId !== playerId) continue;
        if (e.countsToBowler === false) continue;
        foundInMatch = true;
        if (e.isLegalDelivery) {
          legalBalls += 1;
          runsConceded += e.runs;
          if (e.runs === 0 && !e.isWicket) bowlDots += 1;
        } else {
          runsConceded += e.runs;
        }
        if (e.bowlerGetsWicket) wickets += 1;
      }
    }

    if (!foundInMatch) {
      for (const inn of match.innings ?? []) {
        for (const bowler of inn.bowlers ?? []) {
          if (bowler.playerId !== playerId) continue;
          foundInMatch = true;
          wickets += bowler.wickets;
          runsConceded += bowler.runsConceded;
          legalBalls += bowler.oversBowledBalls;
          const whole = Math.floor(bowler.oversBowledBalls / bpo);
          const rem = bowler.oversBowledBalls % bpo;
          oversBowled += whole + rem / bpo;
        }
      }
    } else {
      const added = legalBalls - legalBefore;
      const whole = Math.floor(added / bpo);
      const rem = added % bpo;
      oversBowled += whole + rem / bpo;
    }

    if (foundInMatch) bowlMatchIds.add(match.id);
  }

  const bowlingPattern: BowlingPatternStats =
    legalBalls === 0 && oversBowled === 0
      ? emptyBowlingPattern
      : (() => {
          const overs = oversBowled > 0 ? oversBowled : legalBalls / 6;
          const economy = overs === 0 ? 0 : runsConceded / overs;
          const average = wickets === 0 ? 0 : runsConceded / wickets;
          const strikeRate = wickets === 0 ? 0 : legalBalls / wickets;
          return {
            wickets,
            economy,
            average,
            strikeRate,
            dotPct: legalBalls === 0 ? 0 : (bowlDots / legalBalls) * 100,
            oversBowled: overs,
            matchCount: bowlMatchIds.size,
          };
        })();

  return {
    batting: battingPattern.inningsCount >= MIN_BATTING_INNINGS ? classifyBatting(battingPattern) : null,
    bowling: bowlingPattern.matchCount >= MIN_BOWLING_MATCHES ? classifyBowling(bowlingPattern) : null,
    battingPattern,
    bowlingPattern,
  };
}

export function isDeathOver(overNumber: number, rules: MatchRules): boolean {
  if (String(rules.cricketMatchType) === "testMatch") return false;
  const totalOvers = Math.max(1, Math.min(999, rules.totalOvers || 20));
  if (overNumber < 1 || overNumber > (rules.totalOvers || 20)) return false;
  const slots = rules.powerplaySlots;
  if (slots && slots.some((slot) => slot.length)) {
    return (slots[2] ?? []).includes(overNumber);
  }
  if (rules.powerplayOvers != null && overNumber <= rules.powerplayOvers) return false;
  const powerplayEnd = rules.powerplayOvers != null
    ? Math.min(totalOvers, Math.max(1, rules.powerplayOvers))
    : Math.max(1, Math.round(totalOvers * 0.3));
  const deathLength = Math.max(1, Math.round(totalOvers * 0.25));
  let deathStart = Math.max(1, totalOvers - deathLength + 1);
  if (deathStart <= powerplayEnd) deathStart = powerplayEnd + 1;
  const deathEnd = totalOvers;
  const start = deathStart <= deathEnd ? deathStart : deathEnd;
  return overNumber >= start && overNumber <= deathEnd;
}
