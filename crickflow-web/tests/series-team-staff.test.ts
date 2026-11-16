import { describe, expect, it } from "vitest";
import {
  canInviteClubAdmin,
  clubAdminStatusLabel,
  isEffectiveClubAdmin,
  isListedSquadMember,
  isOpenClubAdminInvite,
  squadStatusLabel,
} from "@/lib/cricket/series-team-staff";

describe("club admin invitations", () => {
  it("does not treat an invitation as an admin grant", () => {
    expect(isEffectiveClubAdmin("invited")).toBe(false);
    expect(isEffectiveClubAdmin("active")).toBe(true);
    expect(isOpenClubAdminInvite("invited")).toBe(true);
  });

  it("allows a new invite after cancel, decline, or removal", () => {
    expect(canInviteClubAdmin(null)).toBe(true);
    expect(canInviteClubAdmin("cancelled")).toBe(true);
    expect(canInviteClubAdmin("active")).toBe(false);
    expect(canInviteClubAdmin("invited")).toBe(false);
  });

  it("labels invitations as Pending", () => {
    expect(clubAdminStatusLabel("invited")).toBe("Pending");
    expect(clubAdminStatusLabel("active")).toBe("Active");
  });
});

describe("squad lists", () => {
  it("keeps removal-pending players on the squad", () => {
    expect(isListedSquadMember("active")).toBe(true);
    expect(isListedSquadMember("pendingRemoval")).toBe(true);
    expect(isListedSquadMember("removed")).toBe(false);
    expect(squadStatusLabel("pendingRemoval")).toBe("Removal pending");
  });
});
