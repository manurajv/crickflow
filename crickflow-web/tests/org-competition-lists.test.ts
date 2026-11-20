import { describe, expect, it } from "vitest";
import type { Match, Tournament } from "@/types/models";
import {
  ORG_STANDALONE_FILTER,
  groupOrgMatches,
  groupOrgTournaments,
  listedOrgMatches,
  orgBucketCounts,
  orgItemVisible,
  orgMatchBucket,
  visibleOrgMatches,
} from "@/lib/cricket/org-competition-lists";

const now = new Date("2026-11-20T06:30:00Z");
const daysFromNow = (d: number) => new Date(now.getTime() + d * 86_400_000);
const daysAgo = (d: number) => new Date(now.getTime() - d * 86_400_000);

function match(id: string, extra: Partial<Match> = {}): Match {
  return {
    id,
    title: id,
    status: "scheduled",
    teamAName: "Aces",
    teamBName: "Blazers",
    seriesId: "s1",
    seriesOfficialStatus: "approved",
    innings: [],
    currentInningsIndex: 0,
    ...extra,
  } as Match;
}

function tour(id: string, extra: Partial<Tournament> = {}): Tournament {
  return {
    id,
    name: `Cup ${id}`,
    format: "league",
    status: "upcoming",
    teamIds: [],
    matchIds: [],
    pointsTable: [],
    bracketRounds: [],
    location: {},
    grounds: [],
    seriesId: "s1",
    seriesOfficialStatus: "approved",
    ...extra,
  } as Tournament;
}

describe("visibility", () => {
  it("approved is public; pending only for admins and the requester", () => {
    expect(orgItemVisible({ officialStatus: "approved", createdBy: "u", isAdmin: false })).toBe(true);
    expect(orgItemVisible({ officialStatus: "pendingApproval", createdBy: "u", isAdmin: false })).toBe(false);
    expect(orgItemVisible({ officialStatus: "pendingApproval", createdBy: "u", isAdmin: true })).toBe(true);
    expect(orgItemVisible({ officialStatus: "pendingApproval", createdBy: "u", isAdmin: false, uid: "u" })).toBe(true);
    expect(orgItemVisible({ officialStatus: "rejected", createdBy: "u", isAdmin: true })).toBe(false);
    expect(orgItemVisible({ officialStatus: null, createdBy: "u", isAdmin: true })).toBe(false);
  });

  it("quick matches never show", () => {
    const list = visibleOrgMatches([match("a"), match("q", { matchMode: "quick" })], { isAdmin: true });
    expect(list.map((m) => m.id)).toEqual(["a"]);
  });
});

describe("matches grouping", () => {
  const live = match("live", { status: "live" });
  const soon = match("soon", { scheduledAt: daysFromNow(5) });
  const later = match("later", { scheduledAt: daysFromNow(20) });
  const old = match("old", { status: "completed", completedAt: new Date("2026-01-01T00:00:00Z") });
  const recent = match("recent", { status: "completed", completedAt: new Date("2026-03-01T00:00:00Z") });
  const all = [old, later, live, recent, soon];

  it("Live → Upcoming (soonest first) → Completed (latest first)", () => {
    const sections = groupOrgMatches(all, { now });
    expect(sections.map((s) => s.bucket)).toEqual(["live", "upcoming", "completed"]);
    expect(sections[1].items.map((m) => m.id)).toEqual(["soon", "later"]);
    expect(sections[2].items.map((m) => m.id)).toEqual(["recent", "old"]);
    expect(sections.map((s) => s.title)).toEqual(["Live now", "Upcoming", "Completed"]);
  });

  it("status filter keeps one section; empty sections are dropped", () => {
    const done = groupOrgMatches(all, { status: "completed", now });
    expect(done).toHaveLength(1);
    expect(done[0].bucket).toBe("completed");
    expect(groupOrgMatches([old], { status: "live", now })).toEqual([]);
  });

  it("tournament filter: standalone, one tournament, search", () => {
    const inCup = match("cup", { tournamentId: "t1", scheduledAt: daysFromNow(6) });
    const list = [soon, inCup];
    expect(groupOrgMatches(list, { tournamentFilter: "t1", now }).at(0)?.items.at(0)?.id).toBe("cup");
    expect(groupOrgMatches(list, { tournamentFilter: ORG_STANDALONE_FILTER, now }).at(0)?.items.at(0)?.id).toBe("soon");
    expect(groupOrgMatches([match("x", { teamAName: "Tigers" })], { query: "tig", now })).toHaveLength(1);
    expect(groupOrgMatches([match("x", { teamAName: "Tigers" })], { query: "zzz", now })).toEqual([]);
  });

  it("counts per status chip", () => {
    const counts = orgBucketCounts(all, orgMatchBucket);
    expect(counts.all).toBe(5);
    expect(counts.live).toBe(1);
    expect(counts.upcoming).toBe(2);
    expect(counts.completed).toBe(2);
  });

  it("toss done counts as live, abandoned as completed", () => {
    expect(orgMatchBucket(match("t", { status: "tossCompleted" }))).toBe("live");
    expect(orgMatchBucket(match("a", { status: "abandoned" }))).toBe("completed");
    expect(orgMatchBucket(match("d", { status: "draft" }))).toBe("upcoming");
  });

  it("drops unfinished matches older than 30 days from lists and All counts", () => {
    const staleLive = match("stale", { status: "live", startedAt: daysAgo(40) });
    const fresh = match("fresh", { status: "scheduled", scheduledAt: daysFromNow(2) });
    expect(listedOrgMatches([staleLive, fresh], now).map((m) => m.id)).toEqual(["fresh"]);
    const sections = groupOrgMatches([staleLive, fresh], { now });
    expect(sections).toHaveLength(1);
    expect(sections[0].items.map((m) => m.id)).toEqual(["fresh"]);
  });
});

describe("tournaments grouping", () => {
  it("live, upcoming (draft included), completed (cancelled included)", () => {
    const sections = groupOrgTournaments([
      tour("done", { status: "completed", endDate: new Date("2026-02-01T00:00:00Z") }),
      tour("cancel", { status: "cancelled", endDate: new Date("2026-03-01T00:00:00Z") }),
      tour("draft", { status: "draft", startDate: new Date("2026-09-01T00:00:00Z") }),
      tour("next", { startDate: new Date("2026-08-01T00:00:00Z") }),
      tour("on", { status: "live" }),
    ]);
    expect(sections.map((s) => s.bucket)).toEqual(["live", "upcoming", "completed"]);
    expect(sections[1].items.map((t) => t.id)).toEqual(["next", "draft"]);
    expect(sections[2].items.map((t) => t.id)).toEqual(["cancel", "done"]);
  });

  it("status filter and search", () => {
    const list = [tour("a"), tour("b", { status: "live" })];
    expect(groupOrgTournaments(list, { status: "live" }).at(0)?.items.at(0)?.id).toBe("b");
    expect(groupOrgTournaments(list, { query: "cup a" }).at(0)?.items.at(0)?.id).toBe("a");
  });
});
