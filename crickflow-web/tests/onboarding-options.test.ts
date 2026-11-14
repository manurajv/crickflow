import { beforeEach, describe, expect, it } from "vitest";
import {
  dialCodeForCountry,
  stashPendingNext,
  takePendingNext,
} from "@/lib/cricket/onboarding-options";

function installSessionStorage() {
  const store = new Map<string, string>();
  const api = {
    getItem: (k: string) => (store.has(k) ? store.get(k)! : null),
    setItem: (k: string, v: string) => {
      store.set(k, String(v));
    },
    removeItem: (k: string) => {
      store.delete(k);
    },
    clear: () => store.clear(),
    key: (i: number) => [...store.keys()][i] ?? null,
    get length() {
      return store.size;
    },
  };
  Object.defineProperty(globalThis, "sessionStorage", { value: api, configurable: true });
  Object.defineProperty(globalThis, "window", { value: { sessionStorage: api }, configurable: true });
}

describe("onboarding pending next", () => {
  beforeEach(() => installSessionStorage());

  it("stashes and takes next paths", () => {
    stashPendingNext("/matches");
    expect(takePendingNext("/")).toBe("/matches/");
  });

  it("ignores register as pending next", () => {
    stashPendingNext("/register/");
    expect(takePendingNext("/")).toBe("/");
  });

  it("rejects protocol-relative pending next", () => {
    stashPendingNext("//evil.com");
    stashPendingNext("https://evil.com");
    expect(takePendingNext("/")).toBe("/");
  });

  it("maps country dial codes like the app", () => {
    expect(dialCodeForCountry("Sri Lanka")).toBe("+94");
    expect(dialCodeForCountry("India")).toBe("+91");
  });
});
