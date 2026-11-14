/**
 * Port of Flutter `lib/domain/services/series/org_competition_access.dart`.
 * UI mirror of `functions/src/series/seriesCompetitionOps.js` — server is authority.
 */

export type SeriesRole =
  | "superAdmin"
  | "seriesAdmin"
  | "scorer"
  | "staffViewer"
  | "clubAdmin"
  | "seriesPlayer"
  | "viewer";

export type OrgProposeAccess = "admins" | "teamAdmins" | "everyone";

export type OrgStartMode =
  | "direct"
  | "request"
  | "requestAutoApproved"
  | "none";

export interface OrgCompetitionPolicy {
  matchProposeAccess: OrgProposeAccess;
  tournamentProposeAccess: OrgProposeAccess;
  matchTeamAdminsNeedApproval: boolean;
  matchPlayersNeedApproval: boolean;
  tournamentTeamAdminsNeedApproval: boolean;
  tournamentPlayersNeedApproval: boolean;
  allowWalkIns: boolean;
}

const DEFAULT_POLICY: OrgCompetitionPolicy = {
  matchProposeAccess: "teamAdmins",
  tournamentProposeAccess: "teamAdmins",
  matchTeamAdminsNeedApproval: true,
  matchPlayersNeedApproval: true,
  tournamentTeamAdminsNeedApproval: true,
  tournamentPlayersNeedApproval: true,
  allowWalkIns: true,
};

export function defaultOrgCompetitionPolicy(): OrgCompetitionPolicy {
  return { ...DEFAULT_POLICY };
}

function parseAccess(value: unknown, fallback: OrgProposeAccess): OrgProposeAccess {
  if (value === "admins" || value === "teamAdmins" || value === "everyone") {
    return value;
  }
  return fallback;
}

function flag(map: Record<string, unknown>, key: string, fallback: boolean): boolean {
  return typeof map[key] === "boolean" ? (map[key] as boolean) : fallback;
}

/** Mirrors OrgCompetitionPolicy.fromMap (incl. legacy seeds). */
export function orgCompetitionPolicyFromMap(
  map: Record<string, unknown> | null | undefined,
): OrgCompetitionPolicy {
  if (!map) return defaultOrgCompetitionPolicy();

  let legacy: OrgProposeAccess = "teamAdmins";
  if (
    map.proposeAccess === "admins" ||
    map.proposeAccess === "teamAdmins" ||
    map.proposeAccess === "everyone"
  ) {
    legacy = map.proposeAccess;
  } else if (map.membersCanRequest === true) {
    legacy = "everyone";
  }

  const legacyMatchNeeds = map.matchRequestsNeedApproval !== false;
  const legacyTournamentNeeds = map.tournamentRequestsNeedApproval !== false;

  return {
    matchProposeAccess: parseAccess(map.matchProposeAccess, legacy),
    tournamentProposeAccess: parseAccess(map.tournamentProposeAccess, legacy),
    matchTeamAdminsNeedApproval: flag(map, "matchTeamAdminsNeedApproval", legacyMatchNeeds),
    matchPlayersNeedApproval: flag(map, "matchPlayersNeedApproval", legacyMatchNeeds),
    tournamentTeamAdminsNeedApproval: flag(
      map,
      "tournamentTeamAdminsNeedApproval",
      legacyTournamentNeeds,
    ),
    tournamentPlayersNeedApproval: flag(
      map,
      "tournamentPlayersNeedApproval",
      legacyTournamentNeeds,
    ),
    allowWalkIns: map.allowWalkIns !== false,
  };
}

export function orgCompetitionPolicyToMap(p: OrgCompetitionPolicy): Record<string, unknown> {
  const proposeAccess =
    accessRank(p.matchProposeAccess) >= accessRank(p.tournamentProposeAccess)
      ? p.matchProposeAccess
      : p.tournamentProposeAccess;
  const membersCanRequest = proposeAccess === "everyone";
  const matchRequestsNeedApproval =
    p.matchTeamAdminsNeedApproval || p.matchPlayersNeedApproval;
  const tournamentRequestsNeedApproval =
    p.tournamentTeamAdminsNeedApproval || p.tournamentPlayersNeedApproval;
  return {
    matchProposeAccess: p.matchProposeAccess,
    tournamentProposeAccess: p.tournamentProposeAccess,
    matchTeamAdminsNeedApproval: p.matchTeamAdminsNeedApproval,
    matchPlayersNeedApproval: p.matchPlayersNeedApproval,
    tournamentTeamAdminsNeedApproval: p.tournamentTeamAdminsNeedApproval,
    tournamentPlayersNeedApproval: p.tournamentPlayersNeedApproval,
    allowWalkIns: p.allowWalkIns,
    proposeAccess,
    membersCanRequest,
    matchRequestsNeedApproval,
    tournamentRequestsNeedApproval,
  };
}

function accessRank(a: OrgProposeAccess): number {
  return a === "admins" ? 0 : a === "teamAdmins" ? 1 : 2;
}

export function policyAccessFor(
  policy: OrgCompetitionPolicy,
  tournament: boolean,
): OrgProposeAccess {
  return tournament ? policy.tournamentProposeAccess : policy.matchProposeAccess;
}

export function policyNeedsApprovalFor(
  policy: OrgCompetitionPolicy,
  opts: { tournament: boolean; teamAdmin: boolean },
): boolean {
  if (opts.tournament) {
    return opts.teamAdmin
      ? policy.tournamentTeamAdminsNeedApproval
      : policy.tournamentPlayersNeedApproval;
  }
  return opts.teamAdmin
    ? policy.matchTeamAdminsNeedApproval
    : policy.matchPlayersNeedApproval;
}

export interface OrgCompetitionAccessInput {
  role: SeriesRole;
  policy: OrgCompetitionPolicy;
  myTeamIds?: string[];
}

export function isOrgAdmin(role: SeriesRole): boolean {
  return role === "superAdmin" || role === "seriesAdmin";
}

export function isCompetitionOfficial(role: SeriesRole): boolean {
  return isOrgAdmin(role) || role === "scorer";
}

export function isOrgStaff(role: SeriesRole): boolean {
  return isOrgAdmin(role) || role === "scorer" || role === "staffViewer";
}

export function isOrgOwner(role: SeriesRole): boolean {
  return role === "superAdmin";
}

function canRequest(
  role: SeriesRole,
  policy: OrgCompetitionPolicy,
  tournament: boolean,
): boolean {
  switch (policyAccessFor(policy, tournament)) {
    case "admins":
      return false;
    case "teamAdmins":
      return role === "clubAdmin";
    case "everyone":
      return role === "clubAdmin" || role === "seriesPlayer";
  }
}

export function orgStartMode(
  input: OrgCompetitionAccessInput,
  tournament: boolean,
): OrgStartMode {
  const { role, policy } = input;
  if (isCompetitionOfficial(role)) return "direct";
  if (!canRequest(role, policy, tournament)) return "none";
  const needs = policyNeedsApprovalFor(policy, {
    tournament,
    teamAdmin: role === "clubAdmin",
  });
  return needs ? "request" : "requestAutoApproved";
}

export function canStartAnything(input: OrgCompetitionAccessInput): boolean {
  return (
    orgStartMode(input, true) !== "none" || orgStartMode(input, false) !== "none"
  );
}

export function matchTeamsError(
  input: OrgCompetitionAccessInput,
  teamAId: string | null | undefined,
  teamBId: string | null | undefined,
): string | null {
  if (!teamAId || !teamBId) return "Pick both teams";
  if (teamAId === teamBId) return "Pick two different teams";
  if (isCompetitionOfficial(input.role)) return null;
  const mine = input.myTeamIds ?? [];
  if (!mine.includes(teamAId) && !mine.includes(teamBId)) {
    return "One of the teams must be your team";
  }
  return null;
}

/** App FAB / button labels — Request vs Start. */
export function orgActionLabel(mode: OrgStartMode, tournament: boolean): string {
  const noun = tournament ? "tournament" : "match";
  if (mode === "request") return `Request a ${noun}`;
  return `Start a ${noun}`;
}

export function orgOutcomeMessage(opts: {
  autoApproved: boolean;
  tournament: boolean;
}): string {
  const noun = opts.tournament ? "Tournament" : "Match";
  return opts.autoApproved
    ? `${noun} added to the org`
    : `${noun} sent to the org admins for approval`;
}

export function playableOrgTeams<T extends { status: string; linkedTeamId?: string }>(
  teams: T[],
): T[] {
  return teams.filter(
    (t) => t.status === "approved" && Boolean(t.linkedTeamId),
  );
}

export function resolveSeriesRole(opts: {
  userId?: string | null;
  superAdminUserId?: string | null;
  isSeriesAdminActive?: boolean;
  isClubAdminActive?: boolean;
  isActiveMember?: boolean;
}): SeriesRole {
  const uid = opts.userId;
  if (!uid) return "viewer";
  if (opts.superAdminUserId && opts.superAdminUserId === uid) return "superAdmin";
  if (opts.isSeriesAdminActive) return "seriesAdmin";
  if (opts.isClubAdminActive) return "clubAdmin";
  if (opts.isActiveMember) return "seriesPlayer";
  return "viewer";
}

export function proposeAccessLabel(a: OrgProposeAccess): string {
  switch (a) {
    case "admins":
      return "Org admins only";
    case "teamAdmins":
      return "Team admins only";
    case "everyone":
      return "Everyone in the team";
  }
}
