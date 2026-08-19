import { describe, expect, it } from "vitest";
import {
  aggregateRankingsFromMatches,
  matchPassesRankingsFilters,
  rankingsBallType,
  rankPlayers,
} from "@/lib/cricket/rankings";
import type { Match, Player } from "@/types/models";

function match(overrides: Partial<Match> & Pick<Match, "id">): Match {
  return {
    title: "A vs B",
    matchType: "single",
    status: "completed",
    teamAName: "A",
    teamBName: "B",
    rules: {
      cricketMatchType: "limitedOvers",
      format: "standard",
      ballType: "leather",
      totalOvers: 20,
      ballsPerOver: 6,
      freeHitEnabled: true,
    },
    innings: [],
    currentInningsIndex: 0,
    location: { country: "", stateProvince: "", district: "", city: "", placeName: "" },
    venue: "",
    resultSummary: "",
    stream: {
      status: "idle",
      destination: "youtube",
      viewerCount: 0,
      webrtcEnabled: false,
      cameraALabel: "Main camera",
      cameraBLabel: "Camera 2",
    },
    ...overrides,
  };
}

const filter = {
  ballType: "leather" as const,
  category: "mostRuns" as const,
  year: null as number | null,
  overs: "all" as const,
};

describe("rankings filters", () => {
  it("treats tennis format as tennis when ballType is missing", () => {
    const tennis = match({
      id: "t",
      rules: {
        cricketMatchType: "limitedOvers",
        format: "tennis",
        ballType: "",
        totalOvers: 8,
        ballsPerOver: 6,
        freeHitEnabled: true,
      },
    });
    expect(rankingsBallType(tennis)).toBe("tennis");
  });

  it("maps legacy indoor ball enum to tennis material", () => {
    const indoor = match({
      id: "i",
      rules: {
        cricketMatchType: "indoor",
        format: "standard",
        ballType: "indoor",
        totalOvers: 6,
        ballsPerOver: 6,
        freeHitEnabled: true,
      },
    });
    expect(rankingsBallType(indoor)).toBe("tennis");
    expect(
      matchPassesRankingsFilters(indoor, { ...filter, ballType: "indoor" }),
    ).toBe(true);
    expect(matchPassesRankingsFilters(indoor, filter)).toBe(false);
  });

  it("applies year and overs filters", () => {
    const m = match({
      id: "y",
      completedAt: new Date("2025-03-01T12:00:00Z"),
      rules: {
        cricketMatchType: "limitedOvers",
        format: "standard",
        ballType: "leather",
        totalOvers: 10,
        ballsPerOver: 6,
        freeHitEnabled: true,
      },
    });
    expect(matchPassesRankingsFilters(m, { ...filter, year: 2025, overs: "overs1to12" })).toBe(true);
    expect(matchPassesRankingsFilters(m, { ...filter, year: 2026 })).toBe(false);
    expect(matchPassesRankingsFilters(m, { ...filter, overs: "overs13to20" })).toBe(false);
  });
});

describe("rankings aggregation", () => {
  it("sums runs from completed leather matches and skips walk-ins", () => {
    const completed = match({
      id: "m1",
      innings: [
        {
          inningsNumber: 1,
          battingTeamId: "a",
          bowlingTeamId: "b",
          status: "completed",
          totalRuns: 80,
          totalWickets: 1,
          legalBalls: 60,
          extras: 0,
          batsmen: [
            {
              playerId: "p1",
              playerName: "Registered",
              runs: 55,
              balls: 40,
              fours: 4,
              sixes: 1,
              isOut: true,
              dismissalInfo: "caught",
              retiredHurt: false,
              isEligibleToReturn: false,
            },
            {
              playerId: "walkin",
              playerName: "Guest",
              runs: 40,
              balls: 20,
              fours: 2,
              sixes: 2,
              isOut: false,
              dismissalInfo: "",
              retiredHurt: false,
              isEligibleToReturn: false,
            },
          ],
          bowlers: [],
          fielders: [],
          partnershipRuns: 0,
          partnershipBalls: 0,
          isFreeHitActive: false,
          partnerships: [],
          fallOfWickets: [],
        },
      ],
    });
    const tennis = match({
      id: "m2",
      rules: {
        cricketMatchType: "limitedOvers",
        format: "tennis",
        ballType: "tennis",
        totalOvers: 8,
        ballsPerOver: 6,
        freeHitEnabled: true,
      },
      innings: completed.innings,
    });
    const stats = aggregateRankingsFromMatches([completed, tennis], filter);
    expect(stats.get("p1")?.runs).toBe(55);
    expect(stats.get("p1")?.fifties).toBe(1);
    expect(stats.get("walkin")?.runs).toBe(40);

    const players: Player[] = [
      {
        id: "p1",
        name: "Registered",
        location: { country: "", stateProvince: "", district: "", city: "", placeName: "" },
        stats: stats.get("p1")!,
        userId: "u1",
      },
      {
        id: "walkin",
        name: "Guest",
        location: { country: "", stateProvince: "", district: "", city: "", placeName: "" },
        stats: stats.get("walkin")!,
      },
    ];
    const ranked = rankPlayers(players, stats, "mostRuns");
    expect(ranked.map((row) => row.player.id)).toEqual(["p1"]);
    expect(ranked[0].value).toBe(55);
  });
});
