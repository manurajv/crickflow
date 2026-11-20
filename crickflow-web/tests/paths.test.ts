import { describe, expect, it } from "vitest";
import { normalizePathname, pathsEqual, pathStartsWith } from "@/lib/routing/paths";

describe("normalizePathname (trailingSlash parity)", () => {
  it("strips trailing slashes except root", () => {
    expect(normalizePathname("/register/")).toBe("/register");
    expect(normalizePathname("/register")).toBe("/register");
    expect(normalizePathname("/")).toBe("/");
    expect(normalizePathname("/login/")).toBe("/login");
  });

  it("matches login/register exempt paths", () => {
    expect(pathsEqual("/register/", "/register")).toBe(true);
    expect(pathStartsWith("/invite/abc/", "/invite")).toBe(true);
    expect(pathStartsWith("/legal/privacy/", "/legal")).toBe(true);
  });
});
