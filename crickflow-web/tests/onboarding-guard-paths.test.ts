import { describe, expect, it } from "vitest";
import { normalizePathname, pathsEqual } from "@/lib/routing/paths";

/** Mirrors OnboardingGuard exempt logic without React. */
function isOnboardingExempt(pathname: string) {
  const path = normalizePathname(pathname);
  if (pathsEqual(path, "/login") || pathsEqual(path, "/register")) return true;
  if (path === "/invite" || path.startsWith("/invite/")) return true;
  if (path === "/legal" || path.startsWith("/legal/")) return true;
  return false;
}

describe("onboarding guard path exemption (t41u regression)", () => {
  it("treats /register/ as exempt so the form can render", () => {
    expect(isOnboardingExempt("/register/")).toBe(true);
    expect(isOnboardingExempt("/register")).toBe(true);
    expect(isOnboardingExempt("/login/")).toBe(true);
  });

  it("still forces onboarding off home and matches", () => {
    expect(isOnboardingExempt("/")).toBe(false);
    expect(isOnboardingExempt("/matches/")).toBe(false);
    expect(isOnboardingExempt("/home/")).toBe(false);
  });
});
