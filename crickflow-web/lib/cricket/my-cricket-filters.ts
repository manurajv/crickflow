import type { Match, Player, Team, Tournament } from "@/types/models";

/** Your · Played · Network · All — same scopes as the mobile My Cricket tabs. */
export type MyCricketListScope = "yours" | "played" | "network" | "all";

export type MyCricketSort = "newest" | "oldest" | "name";

export type TeamListScope = "yours" | "opponents" | "all";

export type FollowedPlayerRefs = {
  linkedIds: Set<string>;
  cfPlayerIds: Set<string>;
};

const EMPTY_FOLLOWED: FollowedPlayerRefs = {
  linkedIds: new Set(),
  cfPlayerIds: new Set(),
};

export function emptyFollowedPlayers(): FollowedPlayerRefs {
  return { linkedIds: new Set(), cfPlayerIds: new Set() };
}

export function followedPlayerRefsFromPlayers(
  players: Array<{ userId?: string; id?: string; playerId?: string }>,
): FollowedPlayerRefs {
  const linkedIds = new Set<string>();
  const cfPlayerIds = new Set<string>();
  for (const p of players) {
    if (p.userId) linkedIds.add(p.userId);
    if (p.id) linkedIds.add(p.id);
    if (p.playerId) cfPlayerIds.add(p.playerId);
  }
  return { linkedIds, cfPlayerIds };
}

export function effectiveTeamIds(player?: Player | null): string[] {
  if (!player) return [];
  const ids = new Set<string>();
  if (player.teamId) ids.add(player.teamId);
  for (const id of player.teamIds ?? []) {
    if (id) ids.add(id);
  }
  return [...ids];
}

export function memberTeamIds(opts: {
  teams: Team[];
  uid?: string | null;
  player?: Player | null;
}): Set<string> {
  const ids = new Set<string>(effectiveTeamIds(opts.player));
  const uid = opts.uid;
  if (!uid) return ids;
  for (const t of opts.teams) {
    if (t.playerIds.includes(uid)) ids.add(t.id);
    if (opts.player?.id && t.playerIds.includes(opts.player.id)) ids.add(t.id);
  }
  return ids;
}

export function opponentTeamIds(opts: {
  matches: Match[];
  memberTeamIds: Set<string>;
}): Set<string> {
  const ids = new Set<string>();
  if (opts.memberTeamIds.size === 0) return ids;
  for (const m of opts.matches) {
    const a = m.teamAId;
    const b = m.teamBId;
    if (!a || !b) continue;
    if (opts.memberTeamIds.has(a) && !opts.memberTeamIds.has(b)) ids.add(b);
    else if (opts.memberTeamIds.has(b) && !opts.memberTeamIds.has(a)) ids.add(a);
  }
  return ids;
}

function matchSortDate(match: Match): number {
  const d = match.completedAt ?? match.startedAt ?? match.scheduledAt ?? match.createdAt;
  return d ? d.getTime() : 0;
}

function tournamentSortDate(t: Tournament): number {
  const d =
    (String(t.status) === "completed" ? t.endDate : null) ?? t.startDate ?? t.createdAt ?? t.endDate;
  return d ? d.getTime() : 0;
}

export function sortMyCricketMatches(matches: Match[], sort: MyCricketSort): Match[] {
  const result = [...matches];
  result.sort((a, b) => {
    if (sort === "name") {
      const left = (a.title || `${a.teamAName} vs ${a.teamBName}`).toLowerCase();
      const right = (b.title || `${b.teamAName} vs ${b.teamBName}`).toLowerCase();
      return left.localeCompare(right);
    }
    const cmp = matchSortDate(a) - matchSortDate(b);
    return sort === "oldest" ? cmp : -cmp;
  });
  return result;
}

export function sortMyCricketTournaments(list: Tournament[], sort: MyCricketSort): Tournament[] {
  const result = [...list];
  result.sort((a, b) => {
    if (sort === "name") return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
    const cmp = tournamentSortDate(a) - tournamentSortDate(b);
    return sort === "oldest" ? cmp : -cmp;
  });
  return result;
}

export function userOwnsOrScoresMatch(m: Match, uid?: string | null): boolean {
  if (!uid) return false;
  if (m.createdBy === uid) return true;
  if (m.scorerIds?.includes(uid)) return true;
  return m.scorer1UserId === uid || m.scorer2UserId === uid || m.currentScorerId === uid;
}

function idsFromSetup(setup: Record<string, unknown> | undefined): string[] {
  if (!setup) return [];
  const ids: string[] = [];
  const pushSnap = (list: unknown) => {
    if (!Array.isArray(list)) return;
    for (const item of list) {
      if (!item || typeof item !== "object") continue;
      const rec = item as Record<string, unknown>;
      for (const key of ["id", "playerId", "userId"] as const) {
        const v = rec[key];
        if (typeof v === "string" && v) ids.push(v);
      }
    }
  };
  pushSnap(setup.teamAPlayingPlayers);
  pushSnap(setup.teamASubstitutePlayers);
  pushSnap(setup.teamBPlayingPlayers);
  pushSnap(setup.teamBSubstitutePlayers);
  for (const key of [
    "teamACaptainId",
    "teamAViceCaptainId",
    "teamAWicketKeeperId",
    "teamBCaptainId",
    "teamBViceCaptainId",
    "teamBWicketKeeperId",
  ]) {
    const v = setup[key];
    if (typeof v === "string" && v) ids.push(v);
  }
  return ids;
}

function playerIdMatches(
  player: Player,
  opts: { docId?: string; cfPlayerId?: string },
): boolean {
  const { docId, cfPlayerId } = opts;
  if (docId) {
    if (docId === player.id) return true;
    if (player.userId && docId === player.userId) return true;
    if (player.playerId && docId === player.playerId) return true;
  }
  if (cfPlayerId && player.playerId && cfPlayerId === player.playerId) return true;
  return false;
}

export function userTeamParticipatedInMatch(
  m: Match,
  opts: { player?: Player | null; userTeamIds?: Set<string> } = {},
): boolean {
  for (const teamId of effectiveTeamIds(opts.player ?? null)) {
    if (m.teamAId === teamId || m.teamBId === teamId) return true;
  }
  const userTeamIds = opts.userTeamIds ?? new Set<string>();
  if (m.teamAId && userTeamIds.has(m.teamAId)) return true;
  if (m.teamBId && userTeamIds.has(m.teamBId)) return true;
  return false;
}

export function userParticipatedInMatch(
  m: Match,
  opts: { uid?: string | null; player?: Player | null; userTeamIds?: Set<string> } = {},
): boolean {
  if (userOwnsOrScoresMatch(m, opts.uid)) return true;
  return userTeamParticipatedInMatch(m, opts);
}

export function isCompletedMatch(m: Match): boolean {
  return String(m.status).toLowerCase() === "completed";
}

export function playerAppearedInMatch(m: Match, player: Player): boolean {
  if (!player.id) return false;
  if (playerIdMatches(player, { docId: m.playerOfMatchId })) return true;
  if (m.matchHero?.playerId && playerIdMatches(player, { docId: m.matchHero.playerId })) {
    return true;
  }
  for (const id of idsFromSetup(m.setup)) {
    if (playerIdMatches(player, { docId: id, cfPlayerId: id })) return true;
  }
  for (const inn of m.innings ?? []) {
    for (const id of [inn.strikerId, inn.nonStrikerId /* not always present */]) {
      if (id && playerIdMatches(player, { docId: id })) return true;
    }
    for (const batter of inn.batsmen ?? []) {
      if (batter.playerId && playerIdMatches(player, { docId: batter.playerId })) return true;
    }
    for (const bowler of inn.bowlers ?? []) {
      if (bowler.playerId && playerIdMatches(player, { docId: bowler.playerId })) return true;
    }
  }
  return false;
}

function refsMatch(refs: FollowedPlayerRefs, docId?: string, cfPlayerId?: string): boolean {
  if (docId && refs.linkedIds.has(docId)) return true;
  if (cfPlayerId && refs.cfPlayerIds.has(cfPlayerId)) return true;
  return false;
}

export function matchInvolvesFollowedPlayer(m: Match, refs: FollowedPlayerRefs): boolean {
  if (refs.linkedIds.size === 0 && refs.cfPlayerIds.size === 0) return false;
  for (const uid of refs.linkedIds) {
    if (userOwnsOrScoresMatch(m, uid)) return true;
  }
  if (refsMatch(refs, m.playerOfMatchId)) return true;
  if (m.matchHero?.playerId && refsMatch(refs, m.matchHero.playerId)) return true;
  for (const id of idsFromSetup(m.setup)) {
    if (refsMatch(refs, id, id)) return true;
  }
  return false;
}

export function filterMatchByScope(
  m: Match,
  scope: MyCricketListScope,
  opts: {
    uid?: string | null;
    player?: Player | null;
    userTeamIds?: Set<string>;
    followedPlayers?: FollowedPlayerRefs;
  } = {},
): boolean {
  const followed = opts.followedPlayers ?? EMPTY_FOLLOWED;
  switch (scope) {
    case "all":
      return true;
    case "yours":
      return userTeamParticipatedInMatch(m, opts);
    case "played":
      return isCompletedMatch(m) && userParticipatedInMatch(m, opts);
    case "network":
      if (userParticipatedInMatch(m, opts)) return false;
      return matchInvolvesFollowedPlayer(m, followed);
    default:
      return true;
  }
}

export function tournamentOrganizerId(t: Tournament): string {
  return t.organizerId || t.createdBy || "";
}

export function userHostsTournament(t: Tournament, uid?: string | null): boolean {
  return Boolean(uid && tournamentOrganizerId(t) === uid);
}

export function userTeamParticipatedInTournament(
  t: Tournament,
  userTeamIds: Set<string> = new Set(),
): boolean {
  return t.teamIds.some((id) => userTeamIds.has(id));
}

export function userParticipatedInTournament(
  t: Tournament,
  opts: { uid?: string | null; userTeamIds?: Set<string> } = {},
): boolean {
  if (userHostsTournament(t, opts.uid)) return true;
  return userTeamParticipatedInTournament(t, opts.userTeamIds ?? new Set());
}

export function filterTournamentByScope(
  t: Tournament,
  scope: MyCricketListScope,
  opts: {
    uid?: string | null;
    userTeamIds?: Set<string>;
    followedPlayers?: FollowedPlayerRefs;
  } = {},
): boolean {
  const followed = opts.followedPlayers ?? EMPTY_FOLLOWED;
  switch (scope) {
    case "all":
      return true;
    case "yours":
      return userParticipatedInTournament(t, opts);
    case "played":
      return String(t.status).toLowerCase() === "completed" && userParticipatedInTournament(t, opts);
    case "network":
      if (userParticipatedInTournament(t, opts)) return false;
      return Boolean(tournamentOrganizerId(t) && followed.linkedIds.has(tournamentOrganizerId(t)));
    default:
      return true;
  }
}

export function filterTeamByScope(
  t: Team,
  scope: TeamListScope,
  opts: { memberTeamIds: Set<string>; opponentTeamIds: Set<string> },
): boolean {
  switch (scope) {
    case "yours":
      return opts.memberTeamIds.has(t.id);
    case "opponents":
      return opts.opponentTeamIds.has(t.id);
    case "all":
    default:
      return true;
  }
}

/** Completed matches the signed-in user created, scored, or played in (Highlights tab). */
export function highlightMatchesForUser(
  matches: Match[],
  opts: { uid?: string | null; player?: Player | null; userTeamIds?: Set<string> },
): Match[] {
  return sortMyCricketMatches(
    matches.filter(
      (m) =>
        isCompletedMatch(m) &&
        (userOwnsOrScoresMatch(m, opts.uid) || userTeamParticipatedInMatch(m, opts)),
    ),
    "newest",
  ).slice(0, 20);
}
