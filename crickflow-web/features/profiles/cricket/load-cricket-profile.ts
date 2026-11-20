"use client";

import { queryLimits } from "@/config/site";
import { playerAppearedInMatch, effectiveTeamIds } from "@/lib/cricket/my-cricket-filters";
import {
  buildProfileFilteredStatsBreakdown,
  computeCaptainStats,
  computeClusters,
  computeTeamProfiles,
  computeTrophies,
  evaluateBadgeCatalog,
  filterProfileMatches,
  type PlayerBadgeProgress,
  type PlayerClusters,
  type PlayerStatsBreakdown,
  type PlayerTeamProfile,
  type PlayerTrophy,
  type CaptainStatsSnapshot,
  type ProfileMatchFilters,
} from "@/lib/cricket/player-cricket-profile";
import {
  getPlayer,
  getPlayerByUserId,
  listBallEvents,
  listFollowedPlayers,
  listMatches,
  listPlayerFollowers,
  listTeams,
} from "@/repositories";
import type { BallEvent, Match, Player, Team } from "@/types/models";

export const CRICKET_PROFILE_MATCH_TAKE = queryLimits.rankingsPool;
export const CRICKET_PROFILE_EVENT_TAKE = 500;
export const CRICKET_PROFILE_EVENT_MATCH_CAP = 30;

export type CricketProfileData = {
  player: Player;
  participatedMatches: Match[];
  completedMatches: Match[];
  teams: Team[];
  ballEventsByMatchId: Record<string, BallEvent[]>;
  following: Player[];
  followers: Player[];
};

export async function loadBallEventsForMatches(
  matches: Match[],
  opts: { maxMatches?: number; take?: number; batchSize?: number } = {},
): Promise<Record<string, BallEvent[]>> {
  const maxMatches = opts.maxMatches ?? matches.length;
  const take = opts.take ?? CRICKET_PROFILE_EVENT_TAKE;
  const batchSize = opts.batchSize ?? 15;
  const slice = matches.slice(0, maxMatches);
  const out: Record<string, BallEvent[]> = {};
  for (let i = 0; i < slice.length; i += batchSize) {
    const chunk = slice.slice(i, i + batchSize);
    const results = await Promise.all(
      chunk.map(async (match) => {
        try {
          const events = await listBallEvents(match.id, take);
          return [match.id, events] as const;
        } catch {
          return [match.id, [] as BallEvent[]] as const;
        }
      }),
    );
    for (const [id, events] of results) {
      if (events.length) out[id] = events;
    }
  }
  return out;
}

export async function loadCricketProfileByPlayerId(playerId: string): Promise<CricketProfileData | null> {
  if (!playerId) return null;
  const player = await getPlayer(playerId);
  if (!player) return null;
  return assembleCricketProfile(player);
}

export async function loadCricketProfileByUserId(userId: string): Promise<CricketProfileData | null> {
  if (!userId) return null;
  const player = await getPlayerByUserId(userId);
  if (!player) return null;
  return assembleCricketProfile(player);
}

async function assembleCricketProfile(player: Player): Promise<CricketProfileData> {
  const [matches, teams, following, followers] = await Promise.all([
    listMatches({ take: CRICKET_PROFILE_MATCH_TAKE }),
    listTeams(CRICKET_PROFILE_MATCH_TAKE),
    player.userId ? listFollowedPlayers(player.userId) : Promise.resolve([]),
    player.userId ? listPlayerFollowers(player.userId) : Promise.resolve([]),
  ]);
  const participatedMatches = matches.filter((m) => playerAppearedInMatch(m, player));
  const completedMatches = participatedMatches.filter((m) => m.status === "completed");
  const forEvents = completedMatches.slice(0, CRICKET_PROFILE_EVENT_MATCH_CAP);
  const ballEventsByMatchId = await loadBallEventsForMatches(forEvents, {
    maxMatches: CRICKET_PROFILE_EVENT_MATCH_CAP,
    take: CRICKET_PROFILE_EVENT_TAKE,
  });
  return {
    player,
    participatedMatches,
    completedMatches,
    teams,
    ballEventsByMatchId,
    following,
    followers,
  };
}

export function deriveCricketProfileView(
  data: CricketProfileData,
  filters: ProfileMatchFilters,
) {
  const filteredMatches = filterProfileMatches(data.participatedMatches, filters);
  const breakdown: PlayerStatsBreakdown = buildProfileFilteredStatsBreakdown({
    player: data.player,
    participatedMatches: data.participatedMatches,
    filters,
    ballEventsByMatchId: data.ballEventsByMatchId,
  });
  const captainStats: CaptainStatsSnapshot = computeCaptainStats(
    data.player.id,
    data.completedMatches,
  );
  const trophies: PlayerTrophy[] = computeTrophies(
    data.player.id,
    data.completedMatches,
    data.ballEventsByMatchId,
  );
  const clusters: PlayerClusters = computeClusters(
    data.player.id,
    data.completedMatches,
    data.ballEventsByMatchId,
  );
  const teams: PlayerTeamProfile[] = computeTeamProfiles({
    player: data.player,
    teams: data.teams,
    completedMatches: data.completedMatches,
    authUid: data.player.userId ?? data.player.id,
    userTeamIds: new Set(effectiveTeamIds(data.player)),
  });
  const career = buildProfileFilteredStatsBreakdown({
    player: data.player,
    participatedMatches: data.participatedMatches,
    filters: {},
    ballEventsByMatchId: data.ballEventsByMatchId,
  }).overall;
  const badges: PlayerBadgeProgress[] = evaluateBadgeCatalog({
    playerId: data.player.id,
    completedMatches: data.completedMatches,
    stats: {
      runs: career.runs,
      wickets: career.wickets,
      sixes: career.sixes,
      catches: career.catches,
      matchesPlayed: career.matchesPlayed,
      oversBowledBalls: career.oversBowledBalls,
      runsConceded: career.runsConceded,
    },
    captainStats,
    ballEventsByMatch: data.ballEventsByMatchId,
  });
  return { filteredMatches, breakdown, captainStats, trophies, clusters, teams, badges };
}
