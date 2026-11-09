import { describe, expect, it } from "vitest";
import { profileNeedsPlayerOnboarding } from "@/lib/auth/platform-admin";

describe("profileNeedsPlayerOnboarding", () => {
  it("forces incomplete non-admin users", () => {
    expect(profileNeedsPlayerOnboarding(null, false)).toBe(true);
    expect(profileNeedsPlayerOnboarding({ onboardingCompleted: false }, false)).toBe(true);
  });

  it("never forces platform admins", () => {
    expect(profileNeedsPlayerOnboarding(null, true)).toBe(false);
    expect(profileNeedsPlayerOnboarding({ onboardingCompleted: false }, true)).toBe(false);
  });

  it("allows completed players", () => {
    expect(profileNeedsPlayerOnboarding({ onboardingCompleted: true }, false)).toBe(false);
  });
});
