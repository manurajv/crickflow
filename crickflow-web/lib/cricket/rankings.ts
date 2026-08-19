import type { CricketBallType, OversFilter, RankingsCategory } from "@/types/enums";
import type { Match, Player, PlayerStats } from "@/types/models";

export const RANKING_YEAR_OPTIONS = [2026, 2025, 2024] as const;

export const OVERS_LABELS: Record<OversFilter, string> = {
  all: "All overs",
  overs1to12: "1–12",
  overs13to20: "13–20",
  overs21to99: "21+",
  testMatch: "Test",
};

export interface RankingsFilter {
  ballType: CricketBallType;
  indoorBallMaterial?: CricketBallType | null;
  category: RankingsCategory;
  year: number | null;
  overs: OversFilter;
}

export interface RankedPlayer {
  player: Player;
  value: number;
}

function emptyStats(): PlayerStats {
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

/** Aligns with Cloud Functions / mobile `resolveBallType`. */
export function rankingsBallType(match: Match): CricketBallType {
  const explicit = String(match.rules.ballType || "").toLowerCase();
  if (explicit === "indoor") return "tennis";
  if (explicit === "leather" || explicit === "tennis") return explicit;
  const format = String(match.rules.format || "").toLowerCase();
  if (format === "tennis" || format === "custom") return "tennis";
  return "leather";
}

function matchesBall(match: Match, filter: RankingsFilter): boolean {
  const type = String(match.rules.cricketMatchType || "").toLowerCase();
  const explicit = String(match.rules.ballType || "").toLowerCase();
  if (filter.ballType === "indoor") {
    const indoor = type === "indoor" || explicit === "indoor";
    if (!indoor) return false;
    if (!filter.indoorBallMaterial) return true;
    return rankingsBallType(match) === filter.indoorBallMaterial;
  }
  return rankingsBallType(match) === filter.ballType;
}

function effectiveTotalOvers(match: Match): number {
  const type = String(match.rules.cricketMatchType || "").toLowerCase();
  const total = match.rules.totalOvers;
  if (type === "testmatch") return 0;
  if (type === "indoor") return total > 0 ? total : 6;
  if (total > 0) return total;
  if (String(match.rules.ballType || "").toLowerCase() === "indoor") return 6;
  return 20;
}

function matchesOvers(match: Match, overs: OversFilter): boolean {
  if (overs === "all") return true;
  const type = String(match.rules.cricketMatchType || "").toLowerCase();
  if (overs === "testMatch") return type === "testmatch";
  if (type === "testmatch") return false;
  const total = effectiveTotalOvers(match);
  if (total <= 0) return false;
  if (overs === "overs1to12") return total >= 1 && total <= 12;
  if (overs === "overs13to20") return total >= 13 && total <= 20;
  return total >= 21 && total <= 99;
}

export function matchPassesRankingsFilters(match: Match, filter: RankingsFilter): boolean {
  if (String(match.status) !== "completed") return false;
  if (!matchesBall(match, filter)) return false;
  if (!matchesOvers(match, filter.overs)) return false;
  if (filter.year != null) {
    const date = match.completedAt ?? match.startedAt ?? match.scheduledAt;
    if (!date || date.getFullYear() !== filter.year) return false;
  }
  return true;
}

export function aggregateRankingsFromMatches(
  matches: Match[],
  filter: RankingsFilter,
): Map<string, PlayerStats> {
  const byId = new Map<string, PlayerStats>();
  const ensure = (id: string) => {
    const existing = byId.get(id);
    if (existing) return existing;
    const created = emptyStats();
    byId.set(id, created);
    return created;
  };

  for (const match of matches) {
    if (!matchPassesRankingsFilters(match, filter)) continue;
    const played = new Set<string>();

    for (const inn of match.innings) {
      for (const batter of inn.batsmen) {
        if (!batter.playerId) continue;
        played.add(batter.playerId);
        const agg = ensure(batter.playerId);
        agg.inningsPlayed += 1;
        agg.runs += batter.runs;
        agg.ballsFaced += batter.balls;
        agg.fours += batter.fours;
        agg.sixes += batter.sixes;
        if (batter.isOut) {
          agg.dismissals += 1;
          if (batter.runs === 0) agg.ducks += 1;
        }
        if (batter.runs >= 100) agg.hundreds += 1;
        else if (batter.runs >= 50) agg.fifties += 1;
        else if (batter.runs >= 30) agg.thirties += 1;
        if (batter.runs > agg.highScore) agg.highScore = batter.runs;
      }

      for (const bowler of inn.bowlers) {
        if (!bowler.playerId) continue;
        played.add(bowler.playerId);
        const agg = ensure(bowler.playerId);
        agg.wickets += bowler.wickets;
        agg.oversBowledBalls += bowler.oversBowledBalls;
        agg.runsConceded += bowler.runsConceded;
        if (bowler.wickets >= 5) agg.fiveWickets += 1;
        else if (bowler.wickets >= 3) agg.threeWickets += 1;
      }

      for (const fielder of inn.fielders ?? []) {
        if (!fielder.playerId) continue;
        if (fielder.catches === 0 && fielder.runOuts === 0 && fielder.stumpings === 0) {
          continue;
        }
        played.add(fielder.playerId);
        const agg = ensure(fielder.playerId);
        agg.catches += fielder.catches;
        agg.runOuts += fielder.runOuts;
        agg.stumpings += fielder.stumpings;
      }
    }

    for (const id of played) {
      ensure(id).matchesPlayed += 1;
    }
  }

  return byId;
}

function metric(stats: PlayerStats, category: RankingsCategory): number | null {
  switch (category) {
    case "mostRuns":
      return stats.runs > 0 ? stats.runs : null;
    case "highestScore":
      return stats.highScore > 0 ? stats.highScore : null;
    case "mostFifties":
      return stats.fifties > 0 ? stats.fifties : null;
    case "mostHundreds":
      return stats.hundreds > 0 ? stats.hundreds : null;
    case "mostWickets":
      return stats.wickets > 0 ? stats.wickets : null;
    case "bestBowlingFigures":
      return null;
    case "mostCatches":
      return stats.catches > 0 ? stats.catches : null;
    case "mostRunOuts":
      return stats.runOuts > 0 ? stats.runOuts : null;
    case "mostStumpings":
      return stats.stumpings > 0 ? stats.stumpings : null;
    default:
      return null;
  }
}

export function rankPlayers(
  players: Player[],
  statsByPlayerId: Map<string, PlayerStats>,
  category: RankingsCategory,
  take = 50,
): RankedPlayer[] {
  const byId = new Map(players.map((player) => [player.id, player]));
  const ranked: RankedPlayer[] = [];

  for (const [id, stats] of statsByPlayerId) {
    const player = byId.get(id);
    if (!player?.userId) continue;
    const value = metric(stats, category);
    if (value == null) continue;
    ranked.push({ player, value });
  }

  ranked.sort((a, b) => {
    if (b.value !== a.value) return b.value - a.value;
    return a.player.name.localeCompare(b.player.name);
  });
  return ranked.slice(0, take);
}
