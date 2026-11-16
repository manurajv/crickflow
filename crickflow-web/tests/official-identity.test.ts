import { describe, expect, it } from "vitest";
import {
  applyOfficialIdentity,
  canRequestToJoinOrgTeam,
  officialIdentityFromProfile,
} from "@/lib/cricket/official-identity";

describe("officialIdentityFromProfile", () => {
  it("prefers displayName and playerId", () => {
    expect(
      officialIdentityFromProfile({
        displayName: "Real Player",
        name: "Legacy Name",
        playerId: "CF-1001",
      }),
    ).toEqual({ fullName: "Real Player", crickFlowPlayerId: "CF-1001" });
  });

  it("falls back to name and cfPlayerId", () => {
    expect(
      officialIdentityFromProfile({ name: "Only Name", cfPlayerId: "CF-2" }),
    ).toEqual({ fullName: "Only Name", crickFlowPlayerId: "CF-2" });
  });

  it("returns empty strings when the profile is missing", () => {
    expect(officialIdentityFromProfile(null)).toEqual({
      fullName: "",
      crickFlowPlayerId: "",
    });
  });
});

describe("applyOfficialIdentity", () => {
  it("overrides a spoofed name and CrickFlow ID", () => {
    const stored = applyOfficialIdentity(
      {
        fullName: "Hacker Alias",
        displayName: "Hacker Alias",
        crickFlowPlayerId: "FAKE-999",
        phoneNumber: "0770000000",
      },
      { displayName: "Real Player", playerId: "CF-1001" },
    );
    expect(stored.fullName).toBe("Real Player");
    expect(stored.displayName).toBe("Real Player");
    expect(stored.crickFlowPlayerId).toBe("CF-1001");
    expect(stored.phoneNumber).toBe("0770000000");
  });
});

describe("canRequestToJoinOrgTeam", () => {
  const base = { signedIn: true, isApproved: true, isTeamAdmin: false, isOnSquad: false };

  it("shows Request to join for outsiders and guests on an approved team", () => {
    expect(canRequestToJoinOrgTeam(base)).toBe(true);
    expect(canRequestToJoinOrgTeam({ ...base, signedIn: false })).toBe(true);
  });

  it("hides the action for squad members and team admins", () => {
    expect(canRequestToJoinOrgTeam({ ...base, isOnSquad: true })).toBe(false);
    expect(canRequestToJoinOrgTeam({ ...base, isTeamAdmin: true })).toBe(false);
    expect(canRequestToJoinOrgTeam({ ...base, isApproved: false })).toBe(false);
  });
});
