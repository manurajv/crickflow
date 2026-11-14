import { describe, expect, it } from "vitest";
import {
  canStartAnything,
  defaultOrgCompetitionPolicy,
  matchTeamsError,
  orgActionLabel,
  orgCompetitionPolicyFromMap,
  orgCompetitionPolicyToMap,
  orgStartMode,
  type OrgCompetitionAccessInput,
  type OrgCompetitionPolicy,
  type OrgProposeAccess,
  type SeriesRole,
} from "@/lib/cricket/org-competition-access";

const policy = defaultOrgCompetitionPolicy();

function both(a: OrgProposeAccess): OrgCompetitionPolicy {
  return { ...policy, matchProposeAccess: a, tournamentProposeAccess: a };
}

function access(
  role: SeriesRole,
  p: OrgCompetitionPolicy = policy,
  mine: string[] = [],
): OrgCompetitionAccessInput {
  return { role, policy: p, myTeamIds: mine };
}

describe("OrgCompetitionAccess (parity with Flutter)", () => {
  it("owner and admins start directly", () => {
    expect(orgStartMode(access("superAdmin"), true)).toBe("direct");
    expect(orgStartMode(access("seriesAdmin"), false)).toBe("direct");
  });

  it("team admins request; auto-approved when approval off", () => {
    expect(orgStartMode(access("clubAdmin"), false)).toBe("request");
    const relaxed = access("clubAdmin", {
      ...policy,
      matchTeamAdminsNeedApproval: false,
    });
    expect(orgStartMode(relaxed, false)).toBe("requestAutoApproved");
    expect(orgStartMode(relaxed, true)).toBe("request");
  });

  it("players only when org allows; viewers never", () => {
    expect(canStartAnything(access("seriesPlayer"))).toBe(false);
    expect(orgStartMode(access("seriesPlayer", both("everyone")), true)).toBe(
      "request",
    );
    expect(canStartAnything(access("viewer"))).toBe(false);
  });

  it("who can propose: admins / teamAdmins / everyone", () => {
    for (const a of ["admins", "teamAdmins", "everyone"] as OrgProposeAccess[]) {
      expect(orgStartMode(access("superAdmin", both(a)), false)).toBe("direct");
      expect(orgStartMode(access("seriesAdmin", both(a)), true)).toBe("direct");
    }
    expect(canStartAnything(access("clubAdmin", both("admins")))).toBe(false);
    expect(canStartAnything(access("seriesPlayer", both("admins")))).toBe(false);
    expect(orgStartMode(access("clubAdmin", both("teamAdmins")), false)).toBe(
      "request",
    );
    expect(canStartAnything(access("seriesPlayer", both("teamAdmins")))).toBe(
      false,
    );
    expect(orgStartMode(access("clubAdmin", both("everyone")), false)).toBe(
      "request",
    );
    expect(orgStartMode(access("seriesPlayer", both("everyone")), false)).toBe(
      "request",
    );
    expect(canStartAnything(access("viewer", both("everyone")))).toBe(false);
  });

  it("matches and tournaments have separate access", () => {
    const split = {
      ...policy,
      matchProposeAccess: "everyone" as const,
      tournamentProposeAccess: "admins" as const,
    };
    expect(orgStartMode(access("seriesPlayer", split), false)).toBe("request");
    expect(orgStartMode(access("seriesPlayer", split), true)).toBe("none");
    expect(orgStartMode(access("clubAdmin", split), true)).toBe("none");
    expect(orgStartMode(access("seriesAdmin", split), true)).toBe("direct");
  });

  it("approval is separate per kind and per role", () => {
    const p: OrgCompetitionPolicy = {
      ...policy,
      matchProposeAccess: "everyone",
      tournamentProposeAccess: "everyone",
      matchTeamAdminsNeedApproval: false,
      matchPlayersNeedApproval: true,
      tournamentTeamAdminsNeedApproval: true,
      tournamentPlayersNeedApproval: false,
    };
    expect(orgStartMode(access("clubAdmin", p), false)).toBe(
      "requestAutoApproved",
    );
    expect(orgStartMode(access("seriesPlayer", p), false)).toBe("request");
    expect(orgStartMode(access("clubAdmin", p), true)).toBe("request");
    expect(orgStartMode(access("seriesPlayer", p), true)).toBe(
      "requestAutoApproved",
    );
    expect(orgStartMode(access("seriesAdmin", p), false)).toBe("direct");
  });

  it("requesters must include one of their teams", () => {
    const a = access("clubAdmin", policy, ["c1"]);
    expect(matchTeamsError(a, "c2", "c3")).toBeTruthy();
    expect(matchTeamsError(a, "c1", "c3")).toBeNull();
    expect(matchTeamsError(a, "c1", "c1")).toBeTruthy();
    expect(matchTeamsError(access("seriesAdmin"), "c2", "c3")).toBeNull();
  });

  it("policy parses missing keys as safe defaults", () => {
    expect(orgCompetitionPolicyFromMap(null)).toEqual(policy);
    expect(policy.allowWalkIns).toBe(true);
  });

  it("legacy single setting seeds both kinds", () => {
    const legacyOn = orgCompetitionPolicyFromMap({
      membersCanRequest: true,
      matchRequestsNeedApproval: false,
    });
    expect(legacyOn.matchProposeAccess).toBe("everyone");
    expect(legacyOn.tournamentProposeAccess).toBe("everyone");
    expect(legacyOn.matchTeamAdminsNeedApproval).toBe(false);
    expect(legacyOn.matchPlayersNeedApproval).toBe(false);
    expect(legacyOn.tournamentTeamAdminsNeedApproval).toBe(true);
    expect(legacyOn.allowWalkIns).toBe(true);
    expect(
      orgCompetitionPolicyFromMap({ membersCanRequest: false }).matchProposeAccess,
    ).toBe("teamAdmins");
    expect(
      orgCompetitionPolicyFromMap({
        proposeAccess: "admins",
        membersCanRequest: true,
      }).tournamentProposeAccess,
    ).toBe("admins");
    expect(
      orgCompetitionPolicyFromMap({ proposeAccess: "nope" }).matchProposeAccess,
    ).toBe("teamAdmins");
  });

  it("per-kind fields win over legacy", () => {
    const p = orgCompetitionPolicyFromMap({
      proposeAccess: "teamAdmins",
      matchProposeAccess: "everyone",
      tournamentProposeAccess: "admins",
      matchTeamAdminsNeedApproval: false,
      tournamentPlayersNeedApproval: false,
      allowWalkIns: false,
    });
    expect(p.matchProposeAccess).toBe("everyone");
    expect(p.tournamentProposeAccess).toBe("admins");
    expect(p.matchTeamAdminsNeedApproval).toBe(false);
    expect(p.matchPlayersNeedApproval).toBe(true);
    expect(p.tournamentPlayersNeedApproval).toBe(false);
    expect(p.allowWalkIns).toBe(false);
  });

  it("action labels and toMap legacy mirrors", () => {
    expect(orgActionLabel("request", false)).toBe("Request a match");
    expect(orgActionLabel("direct", true)).toBe("Start a tournament");
    const map = orgCompetitionPolicyToMap({
      ...policy,
      matchProposeAccess: "everyone",
      tournamentProposeAccess: "admins",
    });
    expect(map.proposeAccess).toBe("everyone");
    expect(map.membersCanRequest).toBe(true);
  });

  it("scorer starts official competitions; staff viewer cannot", () => {
    expect(orgStartMode(access("scorer"), false)).toBe("direct");
    expect(orgStartMode(access("staffViewer"), false)).toBe("none");
    expect(matchTeamsError(access("scorer"), "c2", "c3")).toBeNull();
  });
});
