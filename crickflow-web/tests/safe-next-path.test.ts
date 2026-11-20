import { describe, expect, it } from "vitest";
import { isSafeNextPath, safeNextPath } from "@/lib/auth/safe-next-path";
import { loginUrl } from "@/lib/auth/guest-access";

describe("safeNextPath", () => {
  it("keeps in-app paths", () => {
    expect(safeNextPath("/my-cricket")).toBe("/my-cricket");
    expect(safeNextPath("/series/abc/settings?tab=policy")).toBe("/series/abc/settings?tab=policy");
    expect(safeNextPath("/")).toBe("/");
  });

  it("rejects protocol-relative and scheme redirects", () => {
    expect(safeNextPath("//evil.com")).toBe("/");
    expect(safeNextPath("//evil.com/phish")).toBe("/");
    expect(safeNextPath("https://evil.com")).toBe("/");
    expect(safeNextPath("/\\evil.com")).toBe("/");
    expect(safeNextPath("\\\\evil.com")).toBe("/");
  });

  it("rejects encoded slashes and scripts", () => {
    expect(safeNextPath("/%2fevil.com")).toBe("/");
    expect(safeNextPath("/%2F%2Fevil.com")).toBe("/");
    expect(safeNextPath("%2f%2fevil.com")).toBe("/");
    expect(safeNextPath("/login?next=javascript:alert(1)")).toBe("/");
    expect(safeNextPath("javascript:alert(1)")).toBe("/");
  });

  it("isSafeNextPath matches the resolver", () => {
    expect(isSafeNextPath("/teams")).toBe(true);
    expect(isSafeNextPath("//evil.com")).toBe(false);
    expect(isSafeNextPath("https://x")).toBe(false);
    expect(isSafeNextPath("")).toBe(false);
  });
});

describe("loginUrl", () => {
  it("omits unsafe next values", () => {
    expect(loginUrl("//evil.com", "general")).toBe("/login?msg=general");
    expect(loginUrl("/my-cricket", "my_cricket")).toBe(
      "/login?next=%2Fmy-cricket&msg=my_cricket",
    );
  });
});
