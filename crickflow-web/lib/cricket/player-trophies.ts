import { buildMatchMvp, type MvpPlayerScore } from "@/lib/cricket/match-mvp";
import type { BallEvent, Match } from "@/types/models";

export type PlayerTrophyKind =
  | "playerOfMatch"
  | "fighterOfMatch"
  | "bestBatter"
  | "bestBowler"
  | "bestFielder";

export const TROPHY_LABELS: Record<PlayerTrophyKind, { label: string; emoji: string }> = {
  playerOfMatch: { label: "Player Of The Match", emoji: "🏆" },
  fighterOfMatch: { label: "Fighter Of The Match", emoji: "💪" },
  bestBatter: { label: "Best Batter", emoji: "🏏" },
  bestBowler: { label: "Best Bowler", emoji: "🎯" },
  bestFielder: { label: "Best Fielder", emoji: "🧤" },
};

export type PlayerTrophy = {
  id: string;
  kind: PlayerTrophyKind;
  title: string;
  tier: "gold";
  category: "tournament" | "match";
  date?: Date;
  matchId: string;
  tournamentId?: string;
  matchTitle: string;
  performance: string;
  teamName: string;
  emoji: string;
};

function setupList(setup: Record<string, unknown> | undefined, key: string) {
  const list = setup?.[key];
  if (!Array.isArray(list)) return [] as Array<Record<string, unknown>>;
  return list.filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === "object");
}

export function decidedWinnerTeamId(match: Match, winnerTeamId?: string): string | undefined {
  const w = (winnerTeamId ?? match.winnerTeamId)?.trim();
  if (!w) return undefined;
  if (w !== match.teamAId && w !== match.teamBId) return undefined;
  return w;
}

export function playerTeamIds(match: Match, playerId: string): Set<string> {
  const teams = new Set<string>();
  for (const inn of match.innings ?? []) {
    if ((inn.batsmen ?? []).some((b) => b.playerId === playerId)) teams.add(inn.battingTeamId);
    if ((inn.bowlers ?? []).some((b) => b.playerId === playerId)) teams.add(inn.bowlingTeamId);
  }
  const setup = match.setup as Record<string, unknown> | undefined;
  if (setup) {
    if (setupList(setup, "teamAPlayingPlayers").some((p) => String(p.id ?? "") === playerId)) {
      if (match.teamAId) teams.add(match.teamAId);
    }
    if (setupList(setup, "teamBPlayingPlayers").some((p) => String(p.id ?? "") === playerId)) {
      if (match.teamBId) teams.add(match.teamBId);
    }
  }
  for (const t of [...teams]) {
    if (!t) teams.delete(t);
  }
  return teams;
}

export function isEligibleManOfTheMatch(match: Match, playerId: string): boolean {
  if (match.playerOfMatchId !== playerId) return false;
  const winner = decidedWinnerTeamId(match);
  if (!winner) return true;
  const teams = playerTeamIds(match, playerId);
  if (teams.size === 0) return true;
  return teams.has(winner);
}

function losingTeamId(match: Match): string | undefined {
  const winnerId = match.winnerTeamId;
  if (!winnerId) return undefined;
  if (winnerId === match.teamAId) return match.teamBId;
  if (winnerId === match.teamBId) return match.teamAId;
  return undefined;
}

function playerTeamName(match: Match, playerId: string): string {
  const setup = match.setup as Record<string, unknown> | undefined;
  if (!setup) return "";
  if (setupList(setup, "teamAPlayingPlayers").some((p) => String(p.id ?? "") === playerId)) {
    return match.teamAName;
  }
  if (setupList(setup, "teamBPlayingPlayers").some((p) => String(p.id ?? "") === playerId)) {
    return match.teamBName;
  }
  return "";
}

function battingLine(match: Match, playerId: string): string {
  let runs = 0;
  let balls = 0;
  for (const inn of match.innings ?? []) {
    for (const b of inn.batsmen ?? []) {
      if (b.playerId === playerId) {
        runs += b.runs;
        balls += b.balls;
      }
    }
  }
  if (runs === 0 && balls === 0) return "";
  return `${runs} (${balls})`;
}

function bowlingLine(match: Match, playerId: string): string {
  let wickets = 0;
  let runs = 0;
  let balls = 0;
  for (const inn of match.innings ?? []) {
    for (const b of inn.bowlers ?? []) {
      if (b.playerId === playerId) {
        wickets += b.wickets;
        runs += b.runsConceded;
        balls += b.oversBowledBalls;
      }
    }
  }
  if (wickets === 0 && balls === 0) return "";
  return `${wickets}/${runs}`;
}

function fieldingLine(match: Match, playerId: string): string {
  let catches = 0;
  let runOuts = 0;
  let stumpings = 0;
  for (const inn of match.innings ?? []) {
    for (const f of inn.fielders ?? []) {
      if (f.playerId !== playerId) continue;
      catches += f.catches;
      runOuts += f.runOuts;
      stumpings += f.stumpings;
    }
  }
  const parts: string[] = [];
  if (catches > 0) parts.push(`${catches} ct`);
  if (runOuts > 0) parts.push(`${runOuts} ro`);
  if (stumpings > 0) parts.push(`${stumpings} st`);
  return parts.join(" · ");
}

function overallMvpPerformance(match: Match, playerId: string, mvpScore?: number): string {
  const parts: string[] = [];
  if (mvpScore != null && mvpScore > 0) {
    parts.push(`MVP ${mvpScore.toFixed(1)}`);
  }
  const bat = battingLine(match, playerId);
  if (bat) parts.push(bat);
  const bowl = bowlingLine(match, playerId);
  if (bowl) parts.push(bowl);
  return parts.join(" · ");
}

function performanceForKind(
  match: Match,
  playerId: string,
  kind: PlayerTrophyKind,
  player: MvpPlayerScore,
): string {
  if (kind === "playerOfMatch" || kind === "fighterOfMatch") {
    return overallMvpPerformance(match, playerId, player.totalMvp);
  }
  if (kind === "bestBatter") return battingLine(match, playerId);
  if (kind === "bestBowler") return bowlingLine(match, playerId);
  return fieldingLine(match, playerId);
}

function makeTrophy(
  playerId: string,
  match: Match,
  kind: PlayerTrophyKind,
  performance: string,
): PlayerTrophy {
  const meta = TROPHY_LABELS[kind];
  return {
    id: `${kind}_${match.id}_${playerId}`,
    kind,
    title: meta.label,
    tier: "gold",
    category: match.tournamentId ? "tournament" : "match",
    date: match.completedAt ?? match.scheduledAt ?? undefined,
    matchId: match.id,
    tournamentId: match.tournamentId,
    matchTitle: match.title,
    performance,
    teamName: playerTeamName(match, playerId),
    emoji: meta.emoji,
  };
}

type ScorecardStats = {
  playerId: string;
  teamId: string;
  runs: number;
  wickets: number;
  catches: number;
  runOuts: number;
  stumpings: number;
  totalScore: number;
};

function dismissals(p: ScorecardStats): number {
  return p.catches + p.runOuts + p.stumpings;
}

function aggregateScorecardStats(match: Match): Map<string, ScorecardStats> {
  const stats = new Map<string, ScorecardStats>();
  const ensure = (playerId: string, teamId: string) => {
    if (!stats.has(playerId)) {
      stats.set(playerId, {
        playerId,
        teamId,
        runs: 0,
        wickets: 0,
        catches: 0,
        runOuts: 0,
        stumpings: 0,
        totalScore: 0,
      });
    }
  };
  for (const inn of match.innings ?? []) {
    for (const b of inn.batsmen ?? []) {
      if (!b.playerId) continue;
      ensure(b.playerId, inn.battingTeamId);
      stats.get(b.playerId)!.runs += b.runs;
    }
    for (const b of inn.bowlers ?? []) {
      if (!b.playerId) continue;
      ensure(b.playerId, inn.bowlingTeamId);
      stats.get(b.playerId)!.wickets += b.wickets;
    }
    for (const f of inn.fielders ?? []) {
      if (!f.playerId) continue;
      ensure(f.playerId, inn.bowlingTeamId);
      const p = stats.get(f.playerId)!;
      p.catches += f.catches;
      p.runOuts += f.runOuts;
      p.stumpings += f.stumpings;
    }
  }
  for (const p of stats.values()) {
    p.totalScore = p.runs + p.wickets * 25 + dismissals(p) * 12;
  }
  return stats;
}

function addMvpTrophies(
  trophies: PlayerTrophy[],
  playerId: string,
  match: Match,
  mvp: ReturnType<typeof buildMatchMvp>,
) {
  const add = (kind: PlayerTrophyKind, player?: MvpPlayerScore) => {
    if (!player || player.playerId !== playerId) return;
    trophies.push(makeTrophy(playerId, match, kind, performanceForKind(match, playerId, kind, player)));
  };
  add("playerOfMatch", mvp.players.find((p) => p.isPlayerOfTheMatch));
  add("fighterOfMatch", mvp.players.find((p) => p.isFighterOfTheMatch));
  const bestBatter = mvp.players.filter((p) => p.battingMvp > 0).slice().sort((a, b) => b.battingMvp - a.battingMvp);
  if (bestBatter[0]) add("bestBatter", bestBatter[0]);
  const bestBowler = mvp.players.filter((p) => p.bowlingMvp > 0).slice().sort((a, b) => b.bowlingMvp - a.bowlingMvp);
  if (bestBowler[0]) add("bestBowler", bestBowler[0]);
  const bestFielder = mvp.players.filter((p) => p.fieldingMvp > 0).slice().sort((a, b) => b.fieldingMvp - a.fieldingMvp);
  if (bestFielder[0]) add("bestFielder", bestFielder[0]);
}

function addScorecardTrophies(trophies: PlayerTrophy[], playerId: string, match: Match) {
  if (isEligibleManOfTheMatch(match, playerId)) {
    trophies.push(makeTrophy(playerId, match, "playerOfMatch", overallMvpPerformance(match, playerId)));
  }
  const stats = aggregateScorecardStats(match);
  if (!stats.size) return;
  const ranked = [...stats.values()].sort((a, b) => b.totalScore - a.totalScore);
  const losingId = losingTeamId(match);
  const winnerId = match.winnerTeamId;
  const potmId = match.playerOfMatchId ?? ranked[0]?.playerId;
  let fighterId: string | undefined;
  if (losingId && winnerId && potmId && stats.get(potmId)?.teamId !== losingId) {
    const losingSorted = new Set(
      ranked.filter((p) => p.teamId === losingId).slice(0, 3).map((p) => p.playerId),
    );
    for (const p of ranked) {
      if (losingSorted.has(p.playerId)) {
        fighterId = p.playerId;
        break;
      }
    }
  }
  if (fighterId === playerId) {
    trophies.push(makeTrophy(playerId, match, "fighterOfMatch", overallMvpPerformance(match, playerId)));
  }
  const bestBatter = [...stats.values()].sort((a, b) => b.runs - a.runs);
  if (bestBatter[0] && bestBatter[0].runs > 0 && bestBatter[0].playerId === playerId) {
    trophies.push(makeTrophy(playerId, match, "bestBatter", battingLine(match, playerId)));
  }
  const bestBowler = [...stats.values()].sort((a, b) => b.wickets - a.wickets);
  if (bestBowler[0] && bestBowler[0].wickets > 0 && bestBowler[0].playerId === playerId) {
    trophies.push(makeTrophy(playerId, match, "bestBowler", bowlingLine(match, playerId)));
  }
  const bestFielder = [...stats.values()].sort((a, b) => dismissals(b) - dismissals(a));
  if (bestFielder[0] && dismissals(bestFielder[0]) > 0 && bestFielder[0].playerId === playerId) {
    trophies.push(makeTrophy(playerId, match, "bestFielder", `${dismissals(bestFielder[0])} dismissals`));
  }
}

export function computeTrophies(
  playerId: string,
  completedMatches: Match[],
  ballEventsByMatch: Record<string, BallEvent[]> = {},
): PlayerTrophy[] {
  const trophies: PlayerTrophy[] = [];
  for (const match of completedMatches) {
    const events = ballEventsByMatch[match.id] ?? [];
    const mvp = buildMatchMvp(match, events);
    if (mvp.hasData) addMvpTrophies(trophies, playerId, match, mvp);
    else addScorecardTrophies(trophies, playerId, match);
  }
  trophies.sort((a, b) => (b.date?.getTime() ?? 0) - (a.date?.getTime() ?? 0));
  return trophies;
}
