import { describe, expect, it } from "vitest";
import {
  canViewPrivateProfileFields,
  cfPlayerIdLabel,
  displayBattingStyle,
  displayBowlingStyle,
  displayPlayingRole,
  formatProfileDate,
  initialsForName,
  roleStylesLine,
} from "@/lib/cricket/profile-display";
import { PRIMARY_NAV } from "@/lib/layout/site-nav";

describe("private profile fields", () => {
  it("hides email, phone, and date of birth from guests and other users", () => {
    expect(canViewPrivateProfileFields(null, "owner")).toBe(false);
    expect(canViewPrivateProfileFields("viewer", "owner")).toBe(false);
    expect(canViewPrivateProfileFields("owner", "owner")).toBe(true);
  });
});

describe("cricket profile labels", () => {
  it("labels a CrickFlow ID without exposing a missing value", () => {
    expect(cfPlayerIdLabel("CF000042")).toBe("ID: CF000042");
    expect(cfPlayerIdLabel("")).toBe("");
    expect(cfPlayerIdLabel(undefined)).toBe("");
  });

  it("renders stored role and style enums as human labels", () => {
    expect(displayPlayingRole("allRounder")).toBe("All Rounder");
    expect(displayBattingStyle("rightHandBatsman")).toBe("Right Hand Batsman");
    expect(displayBowlingStyle("rightArmOffSpin")).toBe("Right Arm Off Spin");
    expect(
      roleStylesLine({
        role: "batsman",
        battingStyle: "leftHandBatsman",
        bowlingStyle: "doNotBowl",
      }),
    ).toBe("Batsman · Left Hand Batsman · Do Not Bowl");
  });

  it("formats initials and dates", () => {
    expect(initialsForName("Manuraj Vimukthi")).toBe("MV");
    expect(initialsForName("")).toBe("?");
    expect(formatProfileDate("1998-04-12")).toBe("12 Apr 1998");
  });
});

describe("website primary nav", () => {
  it("does not include My Cricket", () => {
    expect(PRIMARY_NAV.map((item) => item.href)).not.toContain("/my-cricket");
    expect(PRIMARY_NAV.map((item) => item.label)).not.toContain("My Cricket");
  });
});
