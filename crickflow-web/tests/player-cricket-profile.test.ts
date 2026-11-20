import { describe, expect, it } from "vitest";
import type { BallEvent, LocationData, Match, Player } from "@/types/models";
import {
  aggregateOverallDetailed,
  eventCountsAsWicket,
  fieldersFromEvents,
  filterProfileMatches,
  resolvedBallType,
} from "@/lib/cricket/player-cricket-profile";

const loc: LocationData = {
  country: "",
  stateProvince: "",
  district: "",
  city: "",
  placeName: "",
  latitude: 0,
  longitude: 0,
};

function match(partial: Partial<Match> & { id: string }): Match {
  return {
    title: "Match",
    matchType: "single",
    status: "completed",
    teamAName: "A",
    teamBName: "B",
    teamAId: "tA",
    teamBId: "tB",
    rules: {
      cricketMatchType: "limitedOvers",
      format: "standard",
      ballType: "leather",
      totalOvers: 20,
      ballsPerOver: 6,
      freeHitEnabled: true,
      maxWickets: 10,
    },
    innings: [],
    currentInningsIndex: 0,
    location: loc,
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
    ...partial,
  };
}

const player: Player = {
  id: "p1",
  name: "Pat",
  location: loc,
  stats: {} as Player["stats"],
  userId: "u1",
  teamId: "tA",
  teamIds: ["tA"],
};

function event(partial: Partial<BallEvent> & { id: string }): BallEvent {
  return {
    matchId: "m1",
    inningsNumber: 1,
    overNumber: 1,
    ballInOver: 1,
    eventType: "runs",
    runs: 0,
    batsmanRuns: 0,
    extraRuns: 0,
    isLegalDelivery: true,
    isFreeHit: false,
    isWicket: false,
    commentary: "",
    sequence: 1,
    countsToBowler: true,
    ...partial,
  };
}

describe("resolvedBallType", () => {
  it("uses the stored ball type when present", () => {
    expect(resolvedBallType(match({ id: "m", rules: { ...match({ id: "x" }).rules, ballType: "tennis" } }).rules)).toBe("tennis");
  });

  it("falls back to indoor for indoor match type", () => {
    const m = match({
      id: "m",
      rules: { ...match({ id: "x" }).rules, ballType: "", cricketMatchType: "indoor" },
    });
    expect(resolvedBallType(m.rules)).toBe("indoor");
  });
});

describe("fieldersFromEvents", () => {
  it("credits catches, stumpings, and run-outs, and skips retired hurt", () => {
    const fielders = fieldersFromEvents([
      event({
        id: "c1",
        eventType: "wicket",
        isWicket: true,
        wicketType: "caught",
        fielderId: "p1",
      }),
      event({
        id: "cb",
        eventType: "wicket",
        isWicket: true,
        wicketType: "caught",
        dismissalSubType: "caughtBehind",
        fielderId: "wk",
        wicketKeeperId: "wk",
      }),
      event({
        id: "st",
        eventType: "wicket",
        isWicket: true,
        wicketType: "stumped",
        wicketKeeperId: "wk",
      }),
      event({
        id: "ro",
        eventType: "wicket",
        isWicket: true,
        wicketType: "runOut",
        fielderId: "p2",
      }),
      event({
        id: "rh",
        eventType: "wicket",
        isWicket: true,
        wicketType: "retiredHurt",
        retiredHurt: true,
        fielderId: "p1",
      }),
    ]);
    const byId = Object.fromEntries(fielders.map((f) => [f.playerId, f]));
    expect(byId.p1.catches).toBe(1);
    expect(byId.wk.catches).toBe(1);
    expect(byId.wk.stumpings).toBe(1);
    expect(byId.p2.runOuts).toBe(1);
  });

  it("does not count retired hurt as a wicket", () => {
    expect(
      eventCountsAsWicket(
        event({ id: "rh", eventType: "wicket", isWicket: true, wicketType: "retiredHurt", retiredHurt: true }),
      ),
    ).toBe(false);
  });
});

describe("aggregateOverallDetailed", () => {
  it("aggregates batting, bowling extras, dots, and fielding from events", () => {
    const completed = match({
      id: "m1",
      setup: { teamAPlayingPlayers: [{ id: "p1" }] },
      innings: [
        {
          inningsNumber: 1,
          battingTeamId: "tA",
          bowlingTeamId: "tB",
          status: "completed",
          totalRuns: 40,
          totalWickets: 2,
          legalBalls: 24,
          extras: 2,
          batsmen: [
            {
              playerId: "p1",
              playerName: "Pat",
              runs: 32,
              balls: 20,
              fours: 3,
              sixes: 1,
              isOut: true,
              dismissalInfo: "bowled",
              retiredHurt: false,
              isEligibleToReturn: false,
            },
          ],
          bowlers: [
            {
              playerId: "p1",
              playerName: "Pat",
              oversBowledBalls: 12,
              runsConceded: 18,
              wickets: 2,
              wides: 2,
              noBalls: 1,
            },
          ],
          fielders: [],
          partnershipRuns: 0,
          partnershipBalls: 0,
          isFreeHitActive: false,
          partnerships: [],
          fallOfWickets: [],
        },
      ],
    });
    const events = [
      event({ id: "d1", bowlerId: "p1", runs: 0, isLegalDelivery: true }),
      event({ id: "d2", bowlerId: "p1", runs: 0, isLegalDelivery: true }),
      event({
        id: "ct",
        eventType: "wicket",
        isWicket: true,
        wicketType: "caught",
        fielderId: "p1",
        bowlerId: "other",
      }),
    ];
    const result = aggregateOverallDetailed({
      completedMatches: [completed],
      player,
      authUid: "u1",
      ballEventsByMatchId: { m1: events },
    });
    expect(result.stats.matchesPlayed).toBe(1);
    expect(result.stats.runs).toBe(32);
    expect(result.stats.wickets).toBe(2);
    expect(result.wides).toBe(2);
    expect(result.noBalls).toBe(1);
    expect(result.dotBalls).toBe(2);
    expect(result.stats.catches).toBe(1);
  });
});

describe("filterProfileMatches", () => {
  it("filters by overs, ball type, and year", () => {
    const m20 = match({ id: "a", completedAt: new Date("2026-01-01") });
    const m10 = match({
      id: "b",
      completedAt: new Date("2025-01-01"),
      rules: { ...m20.rules, totalOvers: 10, ballType: "tennis" },
    });
    expect(filterProfileMatches([m20, m10], { overs: 20 }).map((m) => m.id)).toEqual(["a"]);
    expect(filterProfileMatches([m20, m10], { ballType: "tennis" }).map((m) => m.id)).toEqual(["b"]);
    expect(filterProfileMatches([m20, m10], { year: 2026 }).map((m) => m.id)).toEqual(["a"]);
  });
});
