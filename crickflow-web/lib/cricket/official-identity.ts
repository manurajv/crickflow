export type OfficialIdentityProfile = {
  displayName?: string | null;
  name?: string | null;
  playerId?: string | null;
  cfPlayerId?: string | null;
} | null | undefined;

/** Name and CrickFlow ID always come from the player's real profile. */
export function officialIdentityFromProfile(profile: OfficialIdentityProfile): {
  fullName: string;
  crickFlowPlayerId: string;
} {
  const data = profile && typeof profile === "object" ? profile : {};
  return {
    fullName: String(data.displayName || data.name || "").trim(),
    crickFlowPlayerId: String(data.playerId || data.cfPlayerId || "").trim(),
  };
}

export function applyOfficialIdentity<T extends Record<string, unknown>>(
  input: T,
  profile: OfficialIdentityProfile,
): T & { fullName: string; displayName: string; crickFlowPlayerId: string } {
  const identity = officialIdentityFromProfile(profile);
  return {
    ...input,
    fullName: identity.fullName,
    displayName: identity.fullName,
    crickFlowPlayerId: identity.crickFlowPlayerId,
  };
}

export function canRequestToJoinOrgTeam(input: {
  signedIn: boolean;
  isApproved: boolean;
  isTeamAdmin: boolean;
  isOnSquad: boolean;
}): boolean {
  return input.isApproved && !input.isTeamAdmin && !input.isOnSquad;
}
