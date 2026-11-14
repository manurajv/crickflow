import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { mapMatch } from "@/lib/firebase/mappers";
import {
  ORG_RANKING_SECTIONS,
  ORG_SECTION_CATEGORIES,
  ORG_STANDALONE_FILTER,
  aggregateOrgPlayerStats,
  ballTypesPresent,
  buildOrgPointsTable,
  countsForOrgStandings,
  defaultBall,
  matchesMissingDigest,
  orgRankingMatches,
  rankOrgPlayers,
  type MatchDigest,
  type OrgPlayerInfo,
  type OrgRankingCategory,
} from "@/lib/cricket/org-leaderboard";
import type { CricketBallType } from "@/types/enums";

/**
 * The same golden file the Flutter engines are verified against
 * (test/org_leaderboard_golden_test.dart). `expected` is produced by the app.
 */
const fixture = JSON.parse(
  readFileSync(resolve(__dirname, "../../test/fixtures/org_leaderboard_golden.json"), "utf8"),
) as {
  series: { rankingRules: Record<string, number | boolean> };
  teams: Array<{ id: string; name: string; status: string; linkedTeamId?: string }>;
  tournaments: Array<{ id: string; teamIds: string[] }>;
  players: Array<{ id: string; name: string; userId: string }>;
  matches: Array<Record<string, unknown> & { id: string }>;
  expected: {
    table: Record<string, Array<Record<string, unknown>>>;
    digests: Record<string, MatchDigest["players"]>;
    rankings: Record<
      string,
      Array<{ playerId: string; rank: number; value: number; valueLabel: string; detail: string[][] }>
    >;
  };
};

const matches = fixture.matches.map((m) => mapMatch(m.id, m));
const digests: Record<string, MatchDigest> = Object.fromEntries(
  Object.entries(fixture.expected.digests).map(([matchId, players]) => [matchId, { matchId, players }]),
);
const players: OrgPlayerInfo[] = fixture.players.map((p) => ({
  id: p.id,
  name: p.name,
  userId: p.userId || undefined,
}));
const rules = fixture.series.rankingRules as never;

describe("org points table matches the app", () => {
  for (const key of ["all", ORG_STANDALONE_FILTER, "tn1"]) {
    it(`filter ${key}`, () => {
      const rows = buildOrgPointsTable({
        teams: fixture.teams,
        matches,
        rules,
        tournamentFilter: key === "all" ? null : key,
        seedTeamIds: key === "tn1" ? fixture.tournaments[0].teamIds : undefined,
      });
      const expected = fixture.expected.table[key];
      expect(rows.map((r) => ({
        teamId: r.teamId,
        teamName: r.teamName,
        played: r.played,
        won: r.won,
        lost: r.lost,
        tied: r.tied,
        noResult: r.noResult,
        points: r.points,
        netRunRate: r.netRunRate,
        position: r.position,
      }))).toEqual(expected);
    });
  }

  it("counts only approved, finished, non-quick matches between org teams", () => {
    const counted = matches.filter(countsForOrgStandings).map((m) => m.id).sort();
    expect(counted).toEqual(["m1", "m2", "m3", "m4"]);
  });

  it("keeps NRR correct: all-out sides use the full quota of overs", () => {
    // m2: Bravo (t2) all out for 50 in 45 balls chasing; faced counts 10 overs.
    const rows = buildOrgPointsTable({
      teams: fixture.teams,
      matches: matches.filter((m) => m.id === "m2"),
      rules,
      tournamentFilter: "tn1",
      seedTeamIds: ["t2", "t3"],
    });
    const bravo = rows.find((r) => r.teamId === "t2");
    expect(bravo?.oversFaced).toBe(10);
    const charlie = rows.find((r) => r.teamId === "t3");
    // Charlie faced 62 legal balls (10.2 overs, not all out), bowled the full 10 overs.
    expect(charlie?.oversFaced).toBeCloseTo(10 + 2 / 6, 10);
    expect(charlie?.oversBowled).toBe(10);
    expect(rows[0].netRunRate).toBe(-rows[1].netRunRate);
  });

  it("breaks ties on net run rate only when the org uses it", () => {
    const a = buildOrgPointsTable({ teams: fixture.teams, matches, rules });
    const b = buildOrgPointsTable({ teams: fixture.teams, matches, rules: { ...(rules as object), useNetRunRate: false } });
    expect(a.map((r) => r.points)).toEqual([...a.map((r) => r.points)].sort((x, y) => y - x));
    expect(b.length).toBe(a.length);
  });

  it("seeds every playable team, never pending or unlinked ones", () => {
    const rows = buildOrgPointsTable({ teams: fixture.teams, matches: [], rules });
    expect(rows.map((r) => r.teamId).sort()).toEqual(["t1", "t2", "t3"]);
    expect(rows.every((r) => r.played === 0 && r.points === 0)).toBe(true);
  });
});

describe("org player rankings match the app, category by category", () => {
  const balls: CricketBallType[] = ["leather", "tennis"];
  const filters: Array<string | null> = [null, ORG_STANDALONE_FILTER, "tn1"];

  it("covers all 21 categories (batting 10, bowling 7, fielding 4)", () => {
    expect(ORG_SECTION_CATEGORIES.batting).toHaveLength(10);
    expect(ORG_SECTION_CATEGORIES.bowling).toHaveLength(7);
    expect(ORG_SECTION_CATEGORIES.fielding).toHaveLength(4);
    expect(ORG_RANKING_SECTIONS).toEqual(["batting", "bowling", "fielding"]);
  });

  for (const ball of balls) {
    for (const filter of filters) {
      for (const section of ORG_RANKING_SECTIONS) {
        for (const category of ORG_SECTION_CATEGORIES[section] as OrgRankingCategory[]) {
          const key = `${ball}|${filter ?? "all"}|${category}`;
          it(key, () => {
            const scoped = orgRankingMatches(matches, filter);
            const stats = aggregateOrgPlayerStats(scoped, ball, digests);
            const ranked = rankOrgPlayers(players, stats, category);
            const expected = fixture.expected.rankings[key];
            expect(ranked.map((e) => e.playerId)).toEqual(expected.map((e) => e.playerId));
            expect(ranked.map((e) => e.rank)).toEqual(expected.map((e) => e.rank));
            expect(ranked.map((e) => e.valueLabel)).toEqual(expected.map((e) => e.valueLabel));
            ranked.forEach((e, i) => expect(e.value).toBeCloseTo(expected[i].value, 9));
            expect(ranked.map((e) => e.detail)).toEqual(expected.map((e) => e.detail));
          });
        }
      }
    }
  }
});

describe("walk-ins and ball filters", () => {
  const stats = aggregateOrgPlayerStats(orgRankingMatches(matches), "tennis", digests);

  it("walk-ins appear in the stats but never rank", () => {
    expect(stats.has("guest_g1")).toBe(true);
    expect(stats.has("w1")).toBe(true);
    for (const section of ORG_RANKING_SECTIONS) {
      for (const category of ORG_SECTION_CATEGORIES[section]) {
        const ids = rankOrgPlayers(players, stats, category).map((e) => e.playerId);
        expect(ids).not.toContain("guest_g1");
        expect(ids).not.toContain("w1");
      }
    }
  });

  it("a registered player with an account ranks as soon as they have the stat", () => {
    const ids = rankOrgPlayers(players, stats, "mostRuns").map((e) => e.playerId);
    expect(ids).toEqual(["p1", "p9", "p2"]);
  });

  it("shows ball chips only for balls that were played", () => {
    expect(ballTypesPresent(orgRankingMatches(matches))).toEqual(["leather", "tennis"]);
    expect(defaultBall(orgRankingMatches(matches))).toBe("leather");
    expect(defaultBall([])).toBe("leather");
  });
});

describe("digest availability", () => {
  it("reports counted matches that still need a digest", () => {
    expect(matchesMissingDigest(matches, digests)).toEqual([]);
    const missing = matchesMissingDigest(matches, {});
    expect(missing.map((m) => m.id).sort()).toEqual(["m1", "m2", "m3"]);
  });

  it("falls back to the innings' fielders when a match has no digest", () => {
    const stats = aggregateOrgPlayerStats(matches.filter((m) => m.id === "m3"), "tennis", {});
    expect(stats.get("p10")?.catches).toBe(2);
    expect(stats.get("p1")?.stumpings).toBe(1);
  });
});
