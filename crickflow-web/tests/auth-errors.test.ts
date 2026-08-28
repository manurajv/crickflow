import { describe, expect, it } from "vitest";
import { normalizePhoneE164 } from "@/lib/firebase/phone-auth";
import { authErrorMessage } from "@/lib/auth-errors";

describe("authErrorMessage", () => {
  it("maps common Firebase codes", () => {
    expect(authErrorMessage({ code: "auth/invalid-credential" })).toMatch(/incorrect/i);
    expect(authErrorMessage({ code: "auth/operation-not-allowed" })).toMatch(/disabled/i);
    expect(authErrorMessage({ code: "auth/invalid-phone-number" })).toMatch(/\+94/);
    expect(authErrorMessage({ code: "auth/error-code:-39" })).toMatch(/rate limit/i);
  });
});

describe("normalizePhoneE164", () => {
  it("builds E.164", () => {
    expect(normalizePhoneE164("94771234567")).toBe("+94771234567");
    expect(normalizePhoneE164("+94 77 123 4567")).toBe("+94771234567");
  });
});
