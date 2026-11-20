/**
 * Org leaderboard — a TypeScript port of the app's org standings so the web
 * shows exactly what the Flutter app shows:
 *
 *  - points table: lib/domain/services/series/org_standings.dart +
 *    points_table_engine_service.dart (P W L T NR Pts NRR)
 *  - player rankings: lib/domain/services/player_rankings/player_rankings_service.dart
 *    (21 categories: batting 10, bowling 7, fielding 4)
 *
 * The app replays ball events on the device; the web cannot, so the stats that
 * need replay (fielding, dot balls, maidens, fastest 50/100) come from the
 * per-match digests the server writes (functions/src/series/orgMatchDigest.js).
 * Everything else is computed from the match documents, like the app.
 *
 * Parity is enforced by tests/org-leaderboard.test.ts, which replays the same
 * golden fixture the Dart engines are checked against
 * (test/fixtures/org_leaderboard_golden.json).
 *
 * Walk-ins: only players whose `players` doc has a userId are ranked. Match-only
 * guests (no doc) and roster entries without an account are skipped, exactly as
 * in the app.
 */
import type { CricketBallType } from "@/types/enums";
import type { Match } from "@/types/models";

export const ORG_STANDALONE_FILTER = "__standalone__";

export type OrgRankingSection = "batting" | "bowling" | "fielding";

export type OrgRankingCategory =
  | "mostRuns"
  | "highestScore"
  | "bestAverage"
  | "strikeRate"
  | "mostFifties"
  | "mostHundreds"
  | "mostSixes"
  | "mostFours"
  | "fastestFifty"
  | "fastestHundred"
  | "mostWickets"
  | "bestBowlingFigures"
  | "economy"
  | "bowlingStrikeRate"
  | "maidens"
  | "dotBalls"
  | "fiveWicketHauls"
  | "mostCatches"
  | "mostRunOuts"
  | "mostStumpings"
  | "mostDirectHits";

export const ORG_RANKING_SECTIONS: OrgRankingSection[] = ["batting", "bowling", "fielding"];

export const ORG_SECTION_LABELS: Record<OrgRankingSection, string> = {
  batting: "Batting",
  bowling: "Bowling",
  fielding: "Fielding",
};

/** Same order and titles as the app. */
export const ORG_SECTION_CATEGORIES: Record<OrgRankingSection, OrgRankingCategory[]> = {
  batting: [
    "mostRuns",
    "highestScore",
    "bestAverage",
    "strikeRate",
    "mostFifties",
    "mostHundreds",
    "mostSixes",
    "mostFours",
    "fastestFifty",
    "fastestHundred",
  ],
  bowling: [
    "mostWickets",
    "bestBowlingFigures",
    "economy",
    "bowlingStrikeRate",
    "maidens",
    "dotBalls",
    "fiveWicketHauls",
  ],
  fielding: ["mostCatches", "mostRunOuts", "mostStumpings", "mostDirectHits"],
};

export const ORG_CATEGORY_TITLES: Record<OrgRankingCategory, string> = {
  mostRuns: "Most Runs",
  highestScore: "Highest Score",
  bestAverage: "Best Average",
  strikeRate: "Strike Rate",
  mostFifties: "Most Fifties",
  mostHundreds: "Most Hundreds",
  mostSixes: "Most Sixes",
  mostFours: "Most Fours",
  fastestFifty: "Fastest Fifty",
  fastestHundred: "Fastest Hundred",
  mostWickets: "Most Wickets",
  bestBowlingFigures: "Best Bowling Figures",
  economy: "Economy",
  bowlingStrikeRate: "Strike Rate",
  maidens: "Maidens",
  dotBalls: "Dot Balls",
  fiveWicketHauls: "Five Wicket Hauls",
  mostCatches: "Most Catches",
  mostRunOuts: "Most Run Outs",
  mostStumpings: "Most Stumpings",
  mostDirectHits: "Most Direct Hits",
};

export const ORG_BALL_LABELS: Record<CricketBallType, string> = {
  leather: "Leather",
  tennis: "Tennis",
  indoor: "Indoor",
};

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

export interface OrgTeam {
  /** series_clubs document id. */
  id: string;
  name: string;
  status: string;
  /** The CrickFlow team that plays for the org team. */
  linkedTeamId?: string;
}

export interface OrgRankingRules {
  winPoints: number;
  lossPoints: number;
  tiePoints: number;
  noResultPoints: number;
  useNetRunRate: boolean;
}

export const DEFAULT_RANKING_RULES: OrgRankingRules = {
  winPoints: 2,
  lossPoints: 0,
  tiePoints: 1,
  noResultPoints: 1,
  useNetRunRate: true,
};

export interface DigestPlayer {
  catches: number;
  runOuts: number;
  stumpings: number;
  dotBalls: number;
  maidens: number;
  fastestFiftyBalls: number | null;
  fastestHundredBalls: number | null;
}

export interface MatchDigest {
  matchId: string;
  players: Record<string, DigestPlayer>;
}

export interface OrgPlayerInfo {
  id: string;
  name: string;
  /** Only players with an account (userId) can rank. */
  userId?: string;
  playerId?: string;
  photoUrl?: string;
  role?: string;
  teamName?: string;
}

// ---------------------------------------------------------------------------
// Which matches count (org_standings.dart)
// ---------------------------------------------------------------------------

function isOrgApproved(m: Match): boolean {
  return Boolean(m.seriesId) && m.seriesOfficialStatus === "approved";
}

/** Approved, non-quick, finished (or abandoned), between two org teams. */
export function countsForOrgStandings(m: Match): boolean {
  if (!isOrgApproved(m) || m.matchMode === "quick") return false;
  const status = String(m.status);
  if (status !== "completed" && status !== "abandoned") return false;
  return Boolean(m.seriesClubAId) && Boolean(m.seriesClubBId);
}

export function matchPassesTournamentFilter(m: Match, filter?: string | null): boolean {
  if (!filter) return true;
  const tid = m.tournamentId ?? "";
  if (filter === ORG_STANDALONE_FILTER) return tid === "";
  return tid === filter;
}

export function orgRankingMatches(matches: Match[], tournamentFilter?: string | null): Match[] {
  return matches
    .filter(countsForOrgStandings)
    .filter((m) => matchPassesTournamentFilter(m, tournamentFilter));
}

// ---------------------------------------------------------------------------
// Points table (points_table_engine_service.dart)
// ---------------------------------------------------------------------------

export interface PointsRow {
  teamId: string;
  teamName: string;
  played: number;
  won: number;
  lost: number;
  tied: number;
  noResult: number;
  points: number;
  netRunRate: number;
  position: number;
  runsFor: number;
  oversFaced: number;
  runsAgainst: number;
  oversBowled: number;
}

function emptyRow(teamId: string, teamName: string): PointsRow {
  return {
    teamId,
    teamName,
    played: 0,
    won: 0,
    lost: 0,
    tied: 0,
    noResult: 0,
    points: 0,
    netRunRate: 0,
    position: 0,
    runsFor: 0,
    oversFaced: 0,
    runsAgainst: 0,
    oversBowled: 0,
  };
}

/** Dart: completed + remainder / ballsPerOver. */
function oversFromBalls(balls: number, ballsPerOver: number): number {
  if (ballsPerOver <= 0 || balls <= 0) return 0;
  const completed = Math.trunc(balls / ballsPerOver);
  const rem = balls % ballsPerOver;
  return completed + rem / ballsPerOver;
}

function matchWhen(m: Match): number {
  return (m.completedAt ?? m.startedAt ?? m.scheduledAt)?.getTime() ?? 0;
}

function applyMatchResult(rows: PointsRow[], match: Match, rules: OrgRankingRules): void {
  const teamA = match.teamAId;
  const teamB = match.teamBId;
  if (!teamA || !teamB) return;

  const winner = match.winnerTeamId;
  const summary = (match.resultSummary || "").toLowerCase();
  const isNoResult =
    String(match.status) === "abandoned" ||
    summary.includes("no result") ||
    summary.includes("abandoned");
  const isTie = !isNoResult && (!winner || summary.includes("tie"));

  const ballsPerOver = match.rules.ballsPerOver;
  const maxWickets = match.rules.maxWickets ?? 10;
  const fullOvers = match.rules.totalOvers;

  const bump = (
    teamId: string,
    teamName: string,
    o: { won: boolean; lost: boolean; tied: boolean; noResult: boolean },
  ) => {
    let row = rows.find((r) => r.teamId === teamId);
    if (!row) {
      row = emptyRow(teamId, teamName);
      rows.push(row);
    }
    const batting = match.innings
      .filter((i) => i.battingTeamId === teamId && !i.isSuperOver)
      .reduce((s, i) => s + i.totalRuns, 0);
    const against = match.innings
      .filter((i) => i.bowlingTeamId === teamId && !i.isSuperOver)
      .reduce((s, i) => s + i.totalRuns, 0);

    // ICC rule: an all-out side counts the full quota of overs.
    let oversFaced = 0;
    for (const inn of match.innings) {
      if (inn.battingTeamId !== teamId || inn.isSuperOver) continue;
      oversFaced += inn.totalWickets >= maxWickets ? fullOvers : oversFromBalls(inn.legalBalls, ballsPerOver);
    }
    let oversBowled = 0;
    for (const inn of match.innings) {
      if (inn.bowlingTeamId !== teamId || inn.isSuperOver) continue;
      oversBowled += inn.totalWickets >= maxWickets ? fullOvers : oversFromBalls(inn.legalBalls, ballsPerOver);
    }

    row.played += 1;
    if (o.noResult) {
      row.noResult += 1;
      row.points += rules.noResultPoints;
    } else if (o.tied) {
      row.tied += 1;
      row.points += rules.tiePoints;
    } else if (o.won) {
      row.won += 1;
      row.points += rules.winPoints;
    } else if (o.lost) {
      row.lost += 1;
      row.points += rules.lossPoints;
    }
    if (teamName) row.teamName = teamName;

    row.runsFor += batting;
    row.runsAgainst += against;
    row.oversFaced += oversFaced;
    row.oversBowled += oversBowled;
    const rpoFor = row.oversFaced > 0 ? row.runsFor / row.oversFaced : 0;
    const rpoAgainst = row.oversBowled > 0 ? row.runsAgainst / row.oversBowled : 0;
    row.netRunRate = Number((rpoFor - rpoAgainst).toFixed(3));
  };

  if (isNoResult) {
    bump(teamA, match.teamAName, { won: false, lost: false, tied: false, noResult: true });
    bump(teamB, match.teamBName, { won: false, lost: false, tied: false, noResult: true });
  } else if (isTie) {
    bump(teamA, match.teamAName, { won: false, lost: false, tied: true, noResult: false });
    bump(teamB, match.teamBName, { won: false, lost: false, tied: true, noResult: false });
  } else {
    bump(teamA, match.teamAName, { won: winner === teamA, lost: winner === teamB, tied: false, noResult: false });
    bump(teamB, match.teamBName, { won: winner === teamB, lost: winner === teamA, tied: false, noResult: false });
  }
}

/** Approved org teams linked to a CrickFlow team. */
export function playableTeams(teams: OrgTeam[]): OrgTeam[] {
  return teams.filter((t) => t.status === "approved" && Boolean(t.linkedTeamId));
}

/**
 * Rows for the org points table, built like a tournament's with the org's own
 * points rules. `tournamentFilter` narrows it to standalone matches or one org
 * tournament; `seedTeamIds` (a tournament's teams) lists teams that have not
 * played yet.
 */
export function buildOrgPointsTable(input: {
  teams: OrgTeam[];
  matches: Match[];
  rules?: Partial<OrgRankingRules>;
  tournamentFilter?: string | null;
  seedTeamIds?: string[];
}): PointsRow[] {
  const rules = { ...DEFAULT_RANKING_RULES, ...input.rules };
  const nameByTeamId = new Map(playableTeams(input.teams).map((t) => [t.linkedTeamId as string, t.name]));
  const counted = orgRankingMatches(input.matches, input.tournamentFilter)
    .map((m, i) => ({ m, i }))
    .sort((a, b) => matchWhen(a.m) - matchWhen(b.m) || a.i - b.i)
    .map((x) => x.m);

  const filter = input.tournamentFilter;
  const oneTournament = Boolean(filter) && filter !== ORG_STANDALONE_FILTER;
  const seedIds = !oneTournament
    ? [...nameByTeamId.keys()]
    : (input.seedTeamIds ?? []).filter((id) => nameByTeamId.has(id));

  const rows: PointsRow[] = [...new Set(seedIds)].map((id) => emptyRow(id, nameByTeamId.get(id) ?? ""));
  for (const match of counted) applyMatchResult(rows, match, rules);

  const named = rows.map((r) => ({ ...r, teamName: (nameByTeamId.get(r.teamId) ?? r.teamName).trim() }));
  named.sort((a, b) => {
    if (b.points !== a.points) return b.points - a.points;
    if (rules.useNetRunRate && b.netRunRate !== a.netRunRate) return b.netRunRate - a.netRunRate;
    if (b.won !== a.won) return b.won - a.won;
    const an = a.teamName.toLowerCase();
    const bn = b.teamName.toLowerCase();
    return an < bn ? -1 : an > bn ? 1 : 0;
  });
  return named.map((r, i) => ({ ...r, position: i + 1 }));
}

// ---------------------------------------------------------------------------
// Player rankings (player_rankings_service.dart)
// ---------------------------------------------------------------------------

/** Mirrors resolveBallType in functions/src/utils/stats.js. */
function resolvedBall(match: Match): CricketBallType {
  const explicit = String(match.rules.ballType || "").toLowerCase();
  if (explicit === "indoor") return "tennis";
  if (explicit === "leather" || explicit === "tennis") return explicit;
  const format = String(match.rules.format || "").toLowerCase();
  if (format === "tennis" || format === "custom") return "tennis";
  return "leather";
}

/** Ball chip filter (overs / year / location filters are not used in orgs). */
export function matchPassesBall(match: Match, ball: CricketBallType): boolean {
  if (ball === "indoor") {
    const type = String(match.rules.cricketMatchType || "").toLowerCase();
    const explicit = String(match.rules.ballType || "").toLowerCase();
    return type === "indoor" || explicit === "indoor";
  }
  return resolvedBall(match) === ball;
}

/** Ball types that have at least one counted match, in the app's order. */
export function ballTypesPresent(matches: Match[]): CricketBallType[] {
  return (["leather", "tennis", "indoor"] as CricketBallType[]).filter((b) =>
    matches.some((m) => matchPassesBall(m, b)),
  );
}

/** The ball with the most matches (first wins ties), like the app. */
export function defaultBall(matches: Match[]): CricketBallType {
  let best: CricketBallType = "leather";
  let bestCount = -1;
  for (const b of ["leather", "tennis", "indoor"] as CricketBallType[]) {
    const count = matches.filter((m) => matchPassesBall(m, b)).length;
    if (count > bestCount) {
      best = b;
      bestCount = count;
    }
  }
  return best;
}

export interface OrgPlayerStats {
  runs: number;
  ballsFaced: number;
  fours: number;
  sixes: number;
  wickets: number;
  oversBowledBalls: number;
  runsConceded: number;
  matchesPlayed: number;
  inningsPlayed: number;
  bowlingInnings: number;
  dismissals: number;
  highScore: number;
  fifties: number;
  hundreds: number;
  fiveWickets: number;
  catches: number;
  runOuts: number;
  stumpings: number;
  fastestFiftyBalls: number | null;
  fastestHundredBalls: number | null;
  bestBowlingWickets: number;
  bestBowlingRuns: number;
  maidens: number;
  dotBalls: number;
}

function emptyStats(): OrgPlayerStats {
  return {
    runs: 0,
    ballsFaced: 0,
    fours: 0,
    sixes: 0,
    wickets: 0,
    oversBowledBalls: 0,
    runsConceded: 0,
    matchesPlayed: 0,
    inningsPlayed: 0,
    bowlingInnings: 0,
    dismissals: 0,
    highScore: 0,
    fifties: 0,
    hundreds: 0,
    fiveWickets: 0,
    catches: 0,
    runOuts: 0,
    stumpings: 0,
    fastestFiftyBalls: null,
    fastestHundredBalls: null,
    bestBowlingWickets: 0,
    bestBowlingRuns: 0,
    maidens: 0,
    dotBalls: 0,
  };
}

/**
 * Aggregates batting / bowling from the match documents and fielding / replay
 * stats from the digests (innings fielders when a match has no digest yet).
 */
export function aggregateOrgPlayerStats(
  matches: Match[],
  ball: CricketBallType,
  digests: Record<string, MatchDigest> = {},
): Map<string, OrgPlayerStats> {
  const byId = new Map<string, OrgPlayerStats>();
  const ensure = (id: string) => {
    let s = byId.get(id);
    if (!s) {
      s = emptyStats();
      byId.set(id, s);
    }
    return s;
  };

  for (const match of matches) {
    if (!matchPassesBall(match, ball)) continue;
    const played = new Set<string>();

    for (const inn of match.innings) {
      for (const b of inn.batsmen) {
        if (!b.playerId) continue;
        played.add(b.playerId);
        const agg = ensure(b.playerId);
        agg.inningsPlayed += 1;
        agg.runs += b.runs;
        agg.ballsFaced += b.balls;
        agg.fours += b.fours;
        agg.sixes += b.sixes;
        if (b.isOut) agg.dismissals += 1;
        if (b.runs >= 100) agg.hundreds += 1;
        else if (b.runs >= 50) agg.fifties += 1;
        if (b.runs > agg.highScore) agg.highScore = b.runs;
      }
      for (const bowler of inn.bowlers) {
        if (!bowler.playerId) continue;
        played.add(bowler.playerId);
        const agg = ensure(bowler.playerId);
        agg.bowlingInnings += 1;
        agg.wickets += bowler.wickets;
        agg.oversBowledBalls += bowler.oversBowledBalls;
        agg.runsConceded += bowler.runsConceded;
        if (bowler.wickets >= 5) agg.fiveWickets += 1;
        if (
          bowler.wickets > agg.bestBowlingWickets ||
          (bowler.wickets === agg.bestBowlingWickets &&
            bowler.wickets > 0 &&
            bowler.runsConceded < agg.bestBowlingRuns)
        ) {
          agg.bestBowlingWickets = bowler.wickets;
          agg.bestBowlingRuns = bowler.runsConceded;
        }
      }
    }

    const digest = digests[match.id];
    const credit = (id: string, catches: number, runOuts: number, stumpings: number) => {
      if (!id || (!catches && !runOuts && !stumpings)) return;
      played.add(id);
      const agg = ensure(id);
      agg.catches += catches;
      agg.runOuts += runOuts;
      agg.stumpings += stumpings;
    };
    if (digest) {
      for (const [id, d] of Object.entries(digest.players)) {
        credit(id, d.catches, d.runOuts, d.stumpings);
        const agg = ensure(id);
        agg.dotBalls += d.dotBalls;
        agg.maidens += d.maidens;
        if (d.fastestFiftyBalls != null && d.fastestFiftyBalls > 0) {
          if (agg.fastestFiftyBalls == null || d.fastestFiftyBalls < agg.fastestFiftyBalls) {
            agg.fastestFiftyBalls = d.fastestFiftyBalls;
          }
        }
        if (d.fastestHundredBalls != null && d.fastestHundredBalls > 0) {
          if (agg.fastestHundredBalls == null || d.fastestHundredBalls < agg.fastestHundredBalls) {
            agg.fastestHundredBalls = d.fastestHundredBalls;
          }
        }
      }
    } else {
      for (const inn of match.innings) {
        for (const f of inn.fielders ?? []) credit(f.playerId, f.catches, f.runOuts, f.stumpings);
      }
    }

    for (const id of played) ensure(id).matchesPlayed += 1;
  }
  return byId;
}

interface Metric {
  value: number;
  label: string;
  include: boolean;
  ascendingBetter?: boolean;
}

/** Dart `double.toStringAsFixed`. */
const fixed = (n: number, digits: number) => n.toFixed(digits);

function battingAverage(runs: number, dismissals: number): number {
  return dismissals === 0 ? runs : runs / dismissals;
}

function strikeRate(runs: number, balls: number): number {
  return balls === 0 ? 0 : (runs / balls) * 100;
}

function economyRate(runs: number, balls: number): number {
  const overs = balls <= 0 ? 0 : balls / 6;
  return overs === 0 ? 0 : runs / overs;
}

export function metricFor(s: OrgPlayerStats, category: OrgRankingCategory): Metric {
  const count = (n: number): Metric => ({ value: n, label: `${n}`, include: n > 0 });
  switch (category) {
    case "mostRuns":
      return count(s.runs);
    case "highestScore":
      return count(s.highScore);
    case "bestAverage": {
      const avg = battingAverage(s.runs, s.dismissals);
      return { value: avg, label: fixed(avg, 1), include: s.ballsFaced >= 1 && s.runs > 0 };
    }
    case "strikeRate": {
      const sr = strikeRate(s.runs, s.ballsFaced);
      return { value: sr, label: fixed(sr, 1), include: s.ballsFaced >= 10 };
    }
    case "mostFifties":
      return count(s.fifties);
    case "mostHundreds":
      return count(s.hundreds);
    case "mostSixes":
      return count(s.sixes);
    case "mostFours":
      return count(s.fours);
    case "mostWickets":
      return count(s.wickets);
    case "economy": {
      const eco = economyRate(s.runsConceded, s.oversBowledBalls);
      return { value: eco, label: fixed(eco, 2), include: s.oversBowledBalls >= 12, ascendingBetter: true };
    }
    case "bowlingStrikeRate": {
      const finite = s.wickets !== 0;
      const bsr = finite ? s.oversBowledBalls / s.wickets : Infinity;
      return {
        value: finite ? bsr : 9999,
        label: finite ? fixed(bsr, 1) : "—",
        include: s.wickets >= 2,
        ascendingBetter: true,
      };
    }
    case "fiveWicketHauls":
      return count(s.fiveWickets);
    case "mostCatches":
      return count(s.catches);
    case "mostRunOuts":
    case "mostDirectHits":
      return count(s.runOuts);
    case "mostStumpings":
      return count(s.stumpings);
    case "fastestFifty": {
      const b = s.fastestFiftyBalls;
      return {
        value: b ?? 9999,
        label: b == null ? "—" : `${b} balls`,
        include: b != null && b > 0,
        ascendingBetter: true,
      };
    }
    case "fastestHundred": {
      const b = s.fastestHundredBalls;
      return {
        value: b ?? 9999,
        label: b == null ? "—" : `${b} balls`,
        include: b != null && b > 0,
        ascendingBetter: true,
      };
    }
    case "bestBowlingFigures":
      return {
        value: s.bestBowlingWickets * 100000 - s.bestBowlingRuns,
        label: `${s.bestBowlingWickets}/${s.bestBowlingRuns}`,
        include: s.bestBowlingWickets > 0,
      };
    case "maidens":
      return count(s.maidens);
    case "dotBalls":
      return count(s.dotBalls);
  }
}

export function sectionOf(category: OrgRankingCategory): OrgRankingSection {
  for (const section of ORG_RANKING_SECTIONS) {
    if (ORG_SECTION_CATEGORIES[section].includes(category)) return section;
  }
  return "batting";
}

function detailStats(section: OrgRankingSection, s: OrgPlayerStats): Array<[string, string]> {
  const avg = battingAverage(s.runs, s.dismissals);
  const batSr = strikeRate(s.runs, s.ballsFaced);
  const eco = economyRate(s.runsConceded, s.oversBowledBalls);
  const bowlSr = s.wickets === 0 ? null : s.oversBowledBalls / s.wickets;
  const dismissals = s.catches + s.stumpings + s.runOuts;
  if (section === "batting") {
    return [
      ["Inn", `${s.inningsPlayed}`],
      ["R", `${s.runs}`],
      ["Avg", fixed(avg, 1)],
      ["SR", fixed(batSr, 1)],
    ];
  }
  if (section === "bowling") {
    return [
      ["Inn", `${s.bowlingInnings}`],
      ["W", `${s.wickets}`],
      ["Eco", fixed(eco, 2)],
      ["SR", bowlSr == null ? "—" : fixed(bowlSr, 1)],
    ];
  }
  return [
    ["Mat", `${s.matchesPlayed}`],
    ["Dis", `${dismissals}`],
    ["Ct", `${s.catches}`],
    ["St", `${s.stumpings}`],
    ["RO", `${s.runOuts}`],
  ];
}

export interface OrgRankingEntry {
  rank: number;
  playerId: string;
  playerName: string;
  publicPlayerId?: string;
  photoUrl?: string;
  role: string;
  teamName: string;
  userId: string;
  value: number;
  valueLabel: string;
  detail: Array<[string, string]>;
}

/** Ranks registered players for one category. Walk-ins (no userId) never rank. */
export function rankOrgPlayers(
  players: OrgPlayerInfo[],
  stats: Map<string, OrgPlayerStats>,
  category: OrgRankingCategory,
): OrgRankingEntry[] {
  const section = sectionOf(category);
  const scored: Array<{ player: OrgPlayerInfo; stats: OrgPlayerStats; metric: Metric }> = [];
  for (const player of players) {
    if (!(player.userId ?? "").trim()) continue;
    const s = stats.get(player.id) ?? emptyStats();
    const metric = metricFor(s, category);
    if (!metric.include) continue;
    scored.push({ player, stats: s, metric });
  }
  scored.sort((a, b) => {
    const cmp = a.metric.ascendingBetter ? a.metric.value - b.metric.value : b.metric.value - a.metric.value;
    if (cmp !== 0) return cmp;
    const an = a.player.name.toLowerCase();
    const bn = b.player.name.toLowerCase();
    return an < bn ? -1 : an > bn ? 1 : 0;
  });
  return scored.map((x, i) => ({
    rank: i + 1,
    playerId: x.player.id,
    playerName: x.player.name,
    publicPlayerId: x.player.playerId,
    photoUrl: x.player.photoUrl,
    role: x.player.role ?? "",
    teamName: x.player.teamName ?? "",
    userId: (x.player.userId ?? "").trim(),
    value: x.metric.value,
    valueLabel: x.metric.label,
    detail: detailStats(section, x.stats),
  }));
}

/** Ids of everyone who appears in the stats (to load their player docs). */
export function playerIdsInStats(stats: Map<string, OrgPlayerStats>): string[] {
  return [...stats.keys()];
}

/** Counted matches that still have no digest (admins can rebuild them). */
export function matchesMissingDigest(matches: Match[], digests: Record<string, MatchDigest>): Match[] {
  return orgRankingMatches(matches).filter((m) => m.innings.length > 0 && !digests[m.id]);
}
