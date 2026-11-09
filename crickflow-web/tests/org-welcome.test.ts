import { beforeEach, describe, expect, it } from "vitest";
import {
  markOrgWelcomeSeen,
  shouldShowOrgWelcome,
} from "@/features/series/org-welcome";

function installMemoryLocalStorage() {
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
  Object.defineProperty(globalThis, "localStorage", {
    value: api,
    configurable: true,
  });
  Object.defineProperty(globalThis, "window", {
    value: { localStorage: api },
    configurable: true,
  });
}

describe("org welcome prefs", () => {
  beforeEach(() => {
    installMemoryLocalStorage();
  });

  it("shows after create once, then not again for that org", () => {
    expect(shouldShowOrgWelcome("u1", "s1", true)).toBe(true);
    markOrgWelcomeSeen("u1", "s1", false);
    expect(shouldShowOrgWelcome("u1", "s1", false)).toBe(false);
    expect(shouldShowOrgWelcome("u1", "s2", false)).toBe(true);
  });

  it("never again suppresses all orgs", () => {
    markOrgWelcomeSeen("u1", "s1", true);
    expect(shouldShowOrgWelcome("u1", "s9", true)).toBe(false);
  });
});
