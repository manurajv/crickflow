import { describe, expect, it } from "vitest";
import { isStaleUnfinishedMatch, matchStaleAnchor, withoutStaleMatches } from "@/lib/cricket/match-staleness";

const now = new Date("2026-11-01T12:00:00Z");
const daysAgo = (d: number) => new Date(now.getTime() - d * 86_400_000);

describe("stale unfinished matches (30-day rule, same as the app)", () => {
  it("scheduled / live older than 30 days are stale", () => {
    expect(isStaleUnfinishedMatch({ status: "scheduled", scheduledAt: daysAgo(31) }, now)).toBe(true);
    expect(isStaleUnfinishedMatch({ status: "scheduled", scheduledAt: daysAgo(29) }, now)).toBe(false);
    for (const status of ["draft", "tossCompleted", "live", "inningsBreak"]) {
      expect(isStaleUnfinishedMatch({ status, startedAt: daysAgo(40) }, now)).toBe(true);
    }
  });

  it("completed and abandoned are never stale", () => {
    expect(isStaleUnfinishedMatch({ status: "completed", scheduledAt: daysAgo(400) }, now)).toBe(false);
    expect(isStaleUnfinishedMatch({ status: "abandoned", scheduledAt: daysAgo(400) }, now)).toBe(false);
  });

  it("anchor is the later of scheduled/started, else createdAt", () => {
    expect(matchStaleAnchor({ scheduledAt: daysAgo(60), startedAt: daysAgo(3) })).toEqual(daysAgo(3));
    expect(isStaleUnfinishedMatch({ status: "live", scheduledAt: daysAgo(60), startedAt: daysAgo(3) }, now)).toBe(false);
    expect(isStaleUnfinishedMatch({ status: "scheduled", createdAt: daysAgo(31) }, now)).toBe(true);
    expect(isStaleUnfinishedMatch({ status: "scheduled" }, now)).toBe(false);
  });

  it("withoutStaleMatches keeps fresh and finished matches", () => {
    const list = [
      { id: "fresh", status: "live", startedAt: daysAgo(1) },
      { id: "old", status: "live", startedAt: daysAgo(45) },
      { id: "done", status: "completed", scheduledAt: daysAgo(200) },
    ];
    expect(withoutStaleMatches(list, now).map((m) => m.id)).toEqual(["fresh", "done"]);
  });
});
