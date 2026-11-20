import { calculateOvers } from "@/lib/cricket/format";
import {
  effectiveTeamIds,
  playerAppearedInMatch,
  userParticipatedInMatch,
} from "@/lib/cricket/my-cricket-filters";
import type {
  BallEvent,
  Innings,
  InningsFielder,
  Match,
  MatchRules,
  Player,
  PlayerStats,
  Team,
} from "@/types/models";
import { TROPHY_LABELS as TROPHY_KIND_META, type PlayerTrophyKind } from "@/lib/cricket/player-trophies";

export const BALL_TYPES = ["leather", "tennis", "indoor"] as const;
export type CricketBallType = (typeof BALL_TYPES)[number];

export const PROFILE_OVERS_FILTER_OPTIONS = [5, 10, 15, 20, 25, 30, 40, 50];

export type ProfileMatchFilters = {
  overs?: number | null;
  ballType?: CricketBallType | null;
  matchType?: string | null;
  year?: number | null;
  teamId?: string | null;
  tournamentId?: string | null;
};

export type PlayerTypedStatsResult = {
  stats: PlayerStats;
  ballsPerOver?: number;
  bowlingActualOvers?: number;
  dotBalls: number;
  wides: number;
  noBalls: number;
};

export type PlayerStatsSection = PlayerTypedStatsResult & { title: string };

export type PlayerStatsBreakdown = {
  overall: PlayerStats;
  typedSections: PlayerStatsSection[];
  overallDotBalls: number;
  overallWides: number;
  overallNoBalls: number;
  overallBallsPerOver?: number;
  overallBowlingActualOvers?: number;
};

export type CaptainYearStats = { year: number; matches: number; wins: number; losses: number };
export type CaptainFormatStats = { label: string; matches: number; wins: number; losses: number };
export type CaptainTimelinePoint = {
  date: Date;
  result: "W" | "L" | "T";
  matchTitle: string;
  teamScore: number;
  opponentScore: number;
};

export type CaptainStatsSnapshot = {
  matchesAsCaptain: number;
  wins: number;
  losses: number;
  ties: number;
  tossesWon: number;
  tossesTotal: number;
  highestTeamScore: number;
  lowestDefendedScore: number;
  successfulChases: number;
  chaseAttempts: number;
  avgTeamScore: number;
  avgConcededScore: number;
  byYear: CaptainYearStats[];
  byFormat: CaptainFormatStats[];
  timeline: CaptainTimelinePoint[];
  winPct: number;
};

export type PlayerTeamProfile = {
  teamId: string;
  teamName: string;
  logoUrl?: string;
  since?: Date | null;
  matches: number;
  wins: number;
  losses: number;
  runs: number;
  wickets: number;
  captainMatches: number;
  teamRole: string;
  avgScore: number;
  strikeRate: number;
  winPct: number;
};

export type {
  BattingClusterType,
  BattingPatternStats,
  BowlingClusterType,
  BowlingPatternStats,
  PlayerClusters,
} from "@/lib/cricket/player-clusters";
export { computeClusters, clusterTagLabels, BATTING_CLUSTER_LABELS, BOWLING_CLUSTER_LABELS } from "@/lib/cricket/player-clusters";
export type { PlayerTrophy, PlayerTrophyKind } from "@/lib/cricket/player-trophies";
export { computeTrophies, isEligibleManOfTheMatch } from "@/lib/cricket/player-trophies";
export type { PlayerBadgeProgress, PlayerBadgeDefinition, PlayerBadgeRecord } from "@/lib/cricket/player-badges";
export { evaluateBadgeCatalog, BADGE_CATALOG } from "@/lib/cricket/player-badges";

export const TROPHY_LABELS: Record<PlayerTrophyKind, string> = {
  playerOfMatch: TROPHY_KIND_META.playerOfMatch.label,
  fighterOfMatch: TROPHY_KIND_META.fighterOfMatch.label,
  bestBatter: TROPHY_KIND_META.bestBatter.label,
  bestBowler: TROPHY_KIND_META.bestBowler.label,
  bestFielder: TROPHY_KIND_META.bestFielder.label,
};

export function emptyPlayerStats(): PlayerStats {
  return {
    runs: 0,
    ballsFaced: 0,
    fours: 0,
    sixes: 0,
    wickets: 0,
    oversBowledBalls: 0,
    runsConceded: 0,
    catches: 0,
    runOuts: 0,
    stumpings: 0,
    matchesPlayed: 0,
    inningsPlayed: 0,
    dismissals: 0,
    highScore: 0,
    thirties: 0,
    fifties: 0,
    hundreds: 0,
    ducks: 0,
    threeWickets: 0,
    fiveWickets: 0,
  };
}

export function cricketBallTypeLabel(type: string): string {
  switch (type) {
    case "leather":
      return "Leather ball";
    case "tennis":
      return "Tennis ball";
    case "indoor":
      return "Indoor";
    default:
      return type;
  }
}

export function profileMatchTypeFilterLabel(type: string): string {
  switch (type) {
    case "limitedOvers":
      return "Limited overs";
    case "indoor":
      return "Indoor";
    case "testMatch":
      return "Test";
    default:
      return type;
  }
}

export function profileMatchOversFilterLabel(overs: number): string {
  return overs === -1 ? "Test" : `${overs} overs`;
}

/** Mirrors MatchRulesModel.resolvedBallType on the mobile app. */
export function resolvedBallType(rules: MatchRules): string {
  const explicit = String(rules.ballType || "").trim().toLowerCase();
  if (explicit) return explicit;
  const type = String(rules.cricketMatchType || "").toLowerCase();
  if (type === "indoor") return "indoor";
  return "leather";
}

export function isCaughtBehindEvent(event: BallEvent): boolean {
  return event.dismissalSubType === "caughtBehind" || event.wicketType === "caughtBehind";
}

export function isRetiredHurtEvent(event: BallEvent): boolean {
  if (event.eventType !== "wicket") return false;
  return Boolean(event.retiredHurt) || event.wicketType === "retiredHurt" || event.wicketType === "retired";
}

export function isRetiredOutEvent(event: BallEvent): boolean {
  return event.eventType === "wicket" && event.wicketType === "retiredOut";
}

function countsAsWicket(type?: string, isMankad = false): boolean {
  if (!type) return false;
  if (type === "retiredHurt" || type === "retired") return false;
  const creditsBowler =
    type === "bowled" ||
    type === "caught" ||
    type === "caughtAndBowled" ||
    type === "caughtBehind" ||
    type === "lbw" ||
    type === "stumped" ||
    type === "hitWicket" ||
    isMankad;
  return (
    creditsBowler ||
    type === "runOut" ||
    type === "mankad" ||
    type === "retiredOut" ||
    type === "obstructingField" ||
    type === "timedOut" ||
    type === "handledBall" ||
    type === "hitBallTwice" ||
    type === "other"
  );
}

export function eventCountsAsWicket(event: BallEvent): boolean {
  if (event.eventType !== "wicket") return false;
  if (isRetiredHurtEvent(event)) return false;
  if (event.isWicket) return true;
  if (isRetiredOutEvent(event)) return true;
  if (!countsAsWicket(event.wicketType, Boolean(event.isMankad))) return false;
  if (event.isFreeHit && event.wicketType !== "runOut") return false;
  return true;
}

export function fieldersFromEvents(events: BallEvent[]): InningsFielder[] {
  const map = new Map<string, InningsFielder>();
  for (const event of events) {
    if (!eventCountsAsWicket(event)) continue;
    if (isRetiredOutEvent(event)) continue;
    const type = event.wicketType;
    let fielderId = event.primaryFielderId || event.fielderId;
    if (!type || !fielderId) {
      if (type === "stumped" && event.wicketKeeperId) {
        fielderId = event.wicketKeeperId;
      } else {
        continue;
      }
    }
    let catches = 0;
    let runOuts = 0;
    let stumpings = 0;
    if (isCaughtBehindEvent(event) || type === "caughtBehind") {
      catches = 1;
      fielderId = event.wicketKeeperId || fielderId;
    } else if (type === "caught" || type === "caughtAndBowled") {
      catches = 1;
    } else if (type === "runOut") {
      runOuts = 1;
    } else if (type === "stumped") {
      stumpings = 1;
      fielderId = event.wicketKeeperId || fielderId;
    } else {
      continue;
    }
    if (!fielderId) continue;
    const existing = map.get(fielderId) ?? { playerId: fielderId, catches: 0, runOuts: 0, stumpings: 0 };
    map.set(fielderId, {
      playerId: fielderId,
      catches: existing.catches + catches,
      runOuts: existing.runOuts + runOuts,
      stumpings: existing.stumpings + stumpings,
    });
  }
  return [...map.values()];
}

export function filterProfileMatches(matches: Match[], filters: ProfileMatchFilters): Match[] {
  return matches.filter((m) => matchesFilters(m, filters));
}

function matchesFilters(m: Match, filters: ProfileMatchFilters): boolean {
  if (filters.overs != null) {
    if (filters.overs === -1) {
      if (m.rules.cricketMatchType !== "testMatch") return false;
    } else if (m.rules.totalOvers !== filters.overs) {
      return false;
    }
  }
  if (filters.ballType && resolvedBallType(m.rules) !== filters.ballType) return false;
  if (filters.matchType && m.rules.cricketMatchType !== filters.matchType) return false;
  if (filters.year != null) {
    const date = m.completedAt ?? m.scheduledAt ?? m.startedAt;
    if (!date || date.getFullYear() !== filters.year) return false;
  }
  if (filters.teamId) {
    if (m.teamAId !== filters.teamId && m.teamBId !== filters.teamId) return false;
  }
  if (filters.tournamentId) {
    if (m.tournamentId !== filters.tournamentId) return false;
  }
  return true;
}

export function profileMatchFilterOptions(matches: Match[]) {
  const years = new Set<number>();
  const teamIds: Record<string, string> = {};
  const tournamentIds: Record<string, string> = {};
  for (const m of matches) {
    const date = m.completedAt ?? m.scheduledAt ?? m.startedAt;
    if (date) years.add(date.getFullYear());
    if (m.teamAId && m.teamAName) teamIds[m.teamAId] = m.teamAName;
    if (m.teamBId && m.teamBName) teamIds[m.teamBId] = m.teamBName;
    if (m.tournamentId) {
      tournamentIds[m.tournamentId] = m.title.includes(" — ")
        ? m.title.split(" — ")[0]
        : m.title;
    }
  }
  return {
    years: [...years].sort((a, b) => b - a),
    teamIds,
    tournamentIds,
  };
}

type Agg = PlayerStats & { dotBalls: number; wides: number; noBalls: number; bowlingActualOvers: number };

function emptyAgg(): Agg {
  return { ...emptyPlayerStats(), dotBalls: 0, wides: 0, noBalls: 0, bowlingActualOvers: 0 };
}

function playedMatch(
  match: Match,
  player: Player,
  authUid?: string,
  userTeamIds?: Set<string>,
): boolean {
  return userParticipatedInMatch(match, {
    uid: authUid,
    player,
    userTeamIds: userTeamIds ?? new Set(effectiveTeamIds(player)),
  });
}

function accumulateInnings(agg: Agg, inn: Innings, playerId: string, ballsPerOver: number): boolean {
  let found = false;
  for (const b of inn.batsmen ?? []) {
    if (b.playerId !== playerId) continue;
    found = true;
    agg.inningsPlayed += 1;
    agg.runs += b.runs;
    agg.ballsFaced += b.balls;
    agg.fours += b.fours;
    agg.sixes += b.sixes;
    if (b.isOut) {
      agg.dismissals += 1;
      if (b.runs === 0) agg.ducks += 1;
    }
    if (b.runs >= 100) agg.hundreds += 1;
    else if (b.runs >= 50) agg.fifties += 1;
    else if (b.runs >= 30) agg.thirties += 1;
    if (b.runs > agg.highScore) agg.highScore = b.runs;
  }
  let matchWickets = 0;
  for (const bowler of inn.bowlers ?? []) {
    if (bowler.playerId !== playerId) continue;
    found = true;
    agg.wickets += bowler.wickets;
    agg.oversBowledBalls += bowler.oversBowledBalls;
    agg.runsConceded += bowler.runsConceded;
    agg.wides += bowler.wides;
    agg.noBalls += bowler.noBalls;
    agg.bowlingActualOvers += calculateOvers(bowler.oversBowledBalls, ballsPerOver);
    matchWickets += bowler.wickets;
  }
  if (matchWickets >= 5) agg.fiveWickets += 1;
  else if (matchWickets >= 3) agg.threeWickets += 1;
  return found;
}

function accumulateMatch(
  agg: Agg,
  match: Match,
  playerId: string,
  events?: BallEvent[],
): boolean {
  let found = false;
  for (const inn of match.innings ?? []) {
    found = accumulateInnings(agg, inn, playerId, match.rules.ballsPerOver || 6) || found;
  }
  if (events && events.length > 0) {
    for (const event of events) {
      if (event.bowlerId !== playerId) continue;
      if (event.countsToBowler === false) continue;
      if (!event.isLegalDelivery || event.runs !== 0) continue;
      found = true;
      agg.dotBalls += 1;
    }
    for (const fielder of fieldersFromEvents(events)) {
      if (fielder.playerId !== playerId) continue;
      found = true;
      agg.catches += fielder.catches;
      agg.runOuts += fielder.runOuts;
      agg.stumpings += fielder.stumpings;
    }
  } else {
    for (const inn of match.innings ?? []) {
      for (const fielder of inn.fielders ?? []) {
        if (fielder.playerId !== playerId) continue;
        found = true;
        agg.catches += fielder.catches;
        agg.runOuts += fielder.runOuts;
        agg.stumpings += fielder.stumpings;
      }
    }
  }
  return found;
}

function resultFromAgg(agg: Agg, bpoCounts: Map<number, number>): PlayerTypedStatsResult {
  const { dotBalls, wides, noBalls, bowlingActualOvers, ...stats } = agg;
  const uniqueBpo = [...bpoCounts.keys()];
  return {
    stats,
    ballsPerOver: uniqueBpo.length === 1 ? uniqueBpo[0] : undefined,
    bowlingActualOvers: bowlingActualOvers > 0 ? bowlingActualOvers : undefined,
    dotBalls,
    wides,
    noBalls,
  };
}

export function aggregateDetailedForType(opts: {
  completedMatches: Match[];
  player: Player;
  ballType: CricketBallType;
  authUid?: string;
  userTeamIds?: Set<string>;
  ballEventsByMatchId?: Record<string, BallEvent[]>;
}): PlayerTypedStatsResult {
  const agg = emptyAgg();
  const bpoCounts = new Map<number, number>();
  for (const match of opts.completedMatches) {
    if (resolvedBallType(match.rules) !== opts.ballType) continue;
    if (!playedMatch(match, opts.player, opts.authUid, opts.userTeamIds)) continue;
    const played = accumulateMatch(agg, match, opts.player.id, opts.ballEventsByMatchId?.[match.id]);
    if (played) {
      agg.matchesPlayed += 1;
      const bpo = match.rules.ballsPerOver || 6;
      bpoCounts.set(bpo, (bpoCounts.get(bpo) ?? 0) + 1);
    }
  }
  return resultFromAgg(agg, bpoCounts);
}

export function aggregateOverallDetailed(opts: {
  completedMatches: Match[];
  player: Player;
  authUid?: string;
  userTeamIds?: Set<string>;
  ballEventsByMatchId?: Record<string, BallEvent[]>;
}): PlayerTypedStatsResult {
  const agg = emptyAgg();
  const bpoCounts = new Map<number, number>();
  for (const match of opts.completedMatches) {
    if (!playedMatch(match, opts.player, opts.authUid, opts.userTeamIds)) continue;
    const played = accumulateMatch(agg, match, opts.player.id, opts.ballEventsByMatchId?.[match.id]);
    if (played) {
      agg.matchesPlayed += 1;
      const bpo = match.rules.ballsPerOver || 6;
      bpoCounts.set(bpo, (bpoCounts.get(bpo) ?? 0) + 1);
    }
  }
  return resultFromAgg(agg, bpoCounts);
}

export function buildProfileFilteredStatsBreakdown(opts: {
  player: Player;
  participatedMatches: Match[];
  filters: ProfileMatchFilters;
  ballEventsByMatchId?: Record<string, BallEvent[]>;
}): PlayerStatsBreakdown {
  const filtered = filterProfileMatches(opts.participatedMatches, opts.filters);
  const completed = filtered.filter((m) => m.status === "completed");
  const authUid = opts.player.userId ?? opts.player.id;
  const userTeamIds = new Set(effectiveTeamIds(opts.player));
  const typedSections: PlayerStatsSection[] = [];
  for (const type of BALL_TYPES) {
    const fromMatches = aggregateDetailedForType({
      completedMatches: completed,
      player: opts.player,
      ballType: type,
      authUid,
      userTeamIds,
      ballEventsByMatchId: opts.ballEventsByMatchId,
    });
    if (fromMatches.stats.matchesPlayed > 0) {
      typedSections.push({ title: cricketBallTypeLabel(type), ...fromMatches });
    }
  }
  const overall = aggregateOverallDetailed({
    completedMatches: completed,
    player: opts.player,
    authUid,
    userTeamIds,
    ballEventsByMatchId: opts.ballEventsByMatchId,
  });
  return {
    overall: overall.stats,
    typedSections,
    overallDotBalls: overall.dotBalls,
    overallWides: overall.wides,
    overallNoBalls: overall.noBalls,
    overallBallsPerOver: overall.ballsPerOver,
    overallBowlingActualOvers: overall.bowlingActualOvers,
  };
}

function setupRecord(match: Match): Record<string, unknown> | undefined {
  const setup = match.setup as Record<string, unknown> | undefined;
  return setup && typeof setup === "object" ? setup : undefined;
}

export function computeCaptainStats(playerId: string, completedMatches: Match[]): CaptainStatsSnapshot {
  let matchesAsCaptain = 0;
  let wins = 0;
  let losses = 0;
  let ties = 0;
  let tossesWon = 0;
  let tossesTotal = 0;
  let highestTeamScore = 0;
  let lowestDefended = 999999;
  let hasDefended = false;
  let successfulChases = 0;
  let chaseAttempts = 0;
  let totalTeamScore = 0;
  let totalConceded = 0;
  let scoreSamples = 0;
  let concededSamples = 0;
  const yearMap = new Map<number, CaptainYearStats>();
  const formatMap = new Map<string, CaptainFormatStats>();
  const timeline: CaptainTimelinePoint[] = [];

  for (const match of completedMatches) {
    const setup = setupRecord(match);
    if (!setup) continue;
    const isTeamACaptain = setup.teamACaptainId === playerId;
    const isTeamBCaptain = setup.teamBCaptainId === playerId;
    if (!isTeamACaptain && !isTeamBCaptain) continue;
    const captainTeamId = isTeamACaptain ? match.teamAId : match.teamBId;
    if (!captainTeamId) continue;

    matchesAsCaptain += 1;
    const date = match.completedAt ?? match.scheduledAt ?? new Date();
    const year = date.getFullYear();
    const yearStats = yearMap.get(year) ?? { year, matches: 0, wins: 0, losses: 0 };
    yearMap.set(year, { ...yearStats, matches: yearStats.matches + 1 });

    const formatLabel = captainFormatLabel(match);
    const fmtStats = formatMap.get(formatLabel) ?? { label: formatLabel, matches: 0, wins: 0, losses: 0 };

    let won = false;
    let lost = false;
    if (match.winnerTeamId === captainTeamId) {
      wins += 1;
      won = true;
    } else if (match.winnerTeamId) {
      losses += 1;
      lost = true;
    } else {
      ties += 1;
    }
    const updatedYear = yearMap.get(year)!;
    yearMap.set(year, {
      ...updatedYear,
      wins: updatedYear.wins + (won ? 1 : 0),
      losses: updatedYear.losses + (lost ? 1 : 0),
    });
    formatMap.set(formatLabel, {
      label: formatLabel,
      matches: fmtStats.matches + 1,
      wins: fmtStats.wins + (won ? 1 : 0),
      losses: fmtStats.losses + (lost ? 1 : 0),
    });

    if (setup.tossWinnerIsTeamA != null) {
      tossesTotal += 1;
      const captainWonToss =
        (isTeamACaptain && setup.tossWinnerIsTeamA === true) ||
        (isTeamBCaptain && setup.tossWinnerIsTeamA === false);
      if (captainWonToss) tossesWon += 1;
    }

    const teamInnings = (match.innings ?? []).filter((inn) => inn.battingTeamId === captainTeamId);
    const oppInnings = (match.innings ?? []).filter(
      (inn) => inn.battingTeamId && inn.battingTeamId !== captainTeamId,
    );
    for (const inn of teamInnings) {
      if (inn.totalRuns > highestTeamScore) highestTeamScore = inn.totalRuns;
      totalTeamScore += inn.totalRuns;
      scoreSamples += 1;
    }
    for (const inn of oppInnings) {
      totalConceded += inn.totalRuns;
      concededSamples += 1;
    }

    const isChase =
      teamInnings.length === 2 ||
      (teamInnings.length > 0 &&
        setup.tossWinnerBatsFirst != null &&
        !(
          (isTeamACaptain && setup.tossWinnerIsTeamA === true && setup.tossWinnerBatsFirst === true) ||
          (isTeamBCaptain && setup.tossWinnerIsTeamA === false && setup.tossWinnerBatsFirst === true)
        ));
    if (teamInnings.length >= 2 || isChase) {
      chaseAttempts += 1;
      if (won) successfulChases += 1;
    }
    if (oppInnings.length && teamInnings.length && won) {
      const defended = teamInnings[0].totalRuns;
      const chased = oppInnings[0].totalRuns;
      if (defended > 0 && chased < defended) {
        hasDefended = true;
        if (defended < lowestDefended) lowestDefended = defended;
      }
    }
    timeline.push({
      date,
      result: won ? "W" : lost ? "L" : "T",
      matchTitle: match.title,
      teamScore: teamInnings.length ? teamInnings[teamInnings.length - 1].totalRuns : 0,
      opponentScore: oppInnings.length ? oppInnings[oppInnings.length - 1].totalRuns : 0,
    });
  }

  timeline.sort((a, b) => a.date.getTime() - b.date.getTime());
  return {
    matchesAsCaptain,
    wins,
    losses,
    ties,
    tossesWon,
    tossesTotal,
    highestTeamScore,
    lowestDefendedScore: hasDefended ? lowestDefended : 0,
    successfulChases,
    chaseAttempts,
    avgTeamScore: scoreSamples === 0 ? 0 : totalTeamScore / scoreSamples,
    avgConcededScore: concededSamples === 0 ? 0 : totalConceded / concededSamples,
    byYear: [...yearMap.values()].sort((a, b) => a.year - b.year),
    byFormat: [...formatMap.values()].sort((a, b) => b.matches - a.matches),
    timeline,
    winPct: matchesAsCaptain === 0 ? 0 : (wins / matchesAsCaptain) * 100,
  };
}

function captainFormatLabel(match: Match): string {
  if (match.rules.cricketMatchType === "testMatch") return "Test";
  const overs = match.rules.totalOvers;
  if (overs <= 12) return "T10";
  if (overs <= 20) return "T20";
  if (overs <= 30) return `${overs} Over`;
  if (overs <= 50) return "ODI";
  return `${overs} Over`;
}

export function computeTeamProfiles(opts: {
  player: Player;
  teams: Team[];
  completedMatches: Match[];
  authUid?: string;
  userTeamIds?: Set<string>;
}): PlayerTeamProfile[] {
  const teamMap = new Map(opts.teams.map((t) => [t.id, t]));
  const profiles: PlayerTeamProfile[] = [];
  for (const teamId of effectiveTeamIds(opts.player)) {
    const team = teamMap.get(teamId);
    if (!team) continue;
    let matches = 0;
    let wins = 0;
    let losses = 0;
    let runs = 0;
    let wickets = 0;
    let balls = 0;
    let captainMatches = 0;
    let since: Date | undefined;
    for (const match of opts.completedMatches) {
      const isTeamA = match.teamAId === teamId;
      const isTeamB = match.teamBId === teamId;
      if (!isTeamA && !isTeamB) continue;
      if (
        !userParticipatedInMatch(match, {
          uid: opts.authUid,
          player: opts.player,
          userTeamIds: opts.userTeamIds ?? new Set(effectiveTeamIds(opts.player)),
        })
      ) {
        continue;
      }
      matches += 1;
      const date = match.completedAt ?? match.scheduledAt;
      if (date && (!since || date < since)) since = date;
      if (match.winnerTeamId === teamId) wins += 1;
      else if (match.winnerTeamId) losses += 1;
      const setup = setupRecord(match);
      if (setup && (setup.teamACaptainId === opts.player.id || setup.teamBCaptainId === opts.player.id)) {
        captainMatches += 1;
      }
      for (const inn of match.innings ?? []) {
        for (const b of inn.batsmen ?? []) {
          if (b.playerId !== opts.player.id) continue;
          runs += b.runs;
          balls += b.balls;
        }
        for (const bowler of inn.bowlers ?? []) {
          if (bowler.playerId !== opts.player.id) continue;
          wickets += bowler.wickets;
        }
      }
    }
    let teamRole = "Player";
    if (team.captainId === opts.player.id) teamRole = "Captain";
    else if (team.viceCaptainId === opts.player.id) teamRole = "Vice Captain";
    else if (team.createdBy === opts.player.id) teamRole = "Owner";
    profiles.push({
      teamId,
      teamName: team.name,
      logoUrl: team.logoUrl,
      since: since ?? null,
      matches,
      wins,
      losses,
      runs,
      wickets,
      captainMatches,
      teamRole,
      avgScore: matches === 0 ? 0 : runs / matches,
      strikeRate: balls === 0 ? 0 : (runs / balls) * 100,
      winPct: matches === 0 ? 0 : (wins / matches) * 100,
    });
  }
  return profiles;
}
