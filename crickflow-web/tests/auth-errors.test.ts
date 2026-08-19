import { describe, expect, it } from "vitest";
import { authErrorMessage } from "@/lib/auth-errors";

describe("authErrorMessage", () => {
  it("maps common Firebase codes", () => {
    expect(authErrorMessage({ code: "auth/invalid-credential" })).toMatch(/incorrect/i);
    expect(authErrorMessage({ code: "auth/operation-not-allowed" })).toMatch(/disabled/i);
    expect(authErrorMessage({ code: "auth/invalid-phone-number" })).toMatch(/\+94/);
  });
});
