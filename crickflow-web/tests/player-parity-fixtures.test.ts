import { describe, expect, it } from "vitest";
import { applyAwards, classifyOver, formatExpectedRuns, parEconomy, parStrikeRate, wicketValue, buildMatchMvp, type MvpFormatContext, type MvpPlayerScore } from "@/lib/cricket/match-mvp";
import { classifyBatting, classifyBowling, computeClusters, MIN_BATTING_INNINGS, MIN_BOWLING_MATCHES, type BattingPatternStats, type BowlingPatternStats } from "@/lib/cricket/player-clusters";
import { BADGE_CATALOG, applyCareerHighestOnly, evaluateBadgeCatalog, qualifiesForSrBadge } from "@/lib/cricket/player-badges";
import { computeTrophies } from "@/lib/cricket/player-trophies";
import type { BallEvent, BatsmanInnings, BowlerInnings, Innings, InningsFielder, LocationData, Match, MatchRules } from "@/types/models";

/** Fixtures and expected values derived from the Dart services
 * (player_cluster_service.dart, match_mvp_service.dart,
 * player_badge_catalog_service.dart, player_badge_progression_service.dart,
 * test/match_mvp_service_test.dart). */

const dart20OverFormat: MvpFormatContext = {
  totalOvers: 20,
  ballsPerOver: 6,
  totalLegalBalls: 120,
  isTestMatch: false,
  parRunsPerInnings: 140,
  parStrikeRate: 115,
  parEconomy: 7,
  strikeRateWeight: 0.72,
  economyWeight: 0.85,
  runsWeight: 1,
};

function score(id: string, teamId: string, total: number, rank = 0): MvpPlayerScore {
  return {
    playerId: id,
    playerName: id,
    teamId,
    teamName: teamId,
    rank,
    battingMvp: total,
    bowlingMvp: 0,
    fieldingMvp: 0,
    clutchBonus: 0,
    partnershipBonus: 0,
    totalMvp: total,
    isPlayerOfTheMatch: false,
    isFighterOfTheMatch: false,
  };
}

const defaultRules: MatchRules = {
  cricketMatchType: "limitedOvers",
  format: "standard",
  ballType: "leather",
  totalOvers: 20,
  ballsPerOver: 6,
  freeHitEnabled: true,
  maxWickets: 10,
};

const loc: LocationData = {
  country: "",
  stateProvince: "",
  district: "",
  city: "",
  placeName: "",
  latitude: 0,
  longitude: 0,
};

function match(partial: Partial<Match> & Pick<Match, "id">): Match {
  return {
    title: "A vs B",
    matchType: "single",
    status: "completed",
    teamAId: "a",
    teamBId: "b",
    teamAName: "A",
    teamBName: "B",
    rules: defaultRules,
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

function batter(partial: Partial<BatsmanInnings> & Pick<BatsmanInnings, "playerId">): BatsmanInnings {
  return {
    playerName: "P",
    runs: 0,
    balls: 0,
    fours: 0,
    sixes: 0,
    isOut: false,
    dismissalInfo: "",
    retiredHurt: false,
    isEligibleToReturn: false,
    ...partial,
  };
}

function bowler(partial: Partial<BowlerInnings> & Pick<BowlerInnings, "playerId">): BowlerInnings {
  return {
    playerName: "P",
    oversBowledBalls: 0,
    runsConceded: 0,
    wickets: 0,
    wides: 0,
    noBalls: 0,
    ...partial,
  };
}

function fielder(partial: Partial<InningsFielder> & Pick<InningsFielder, "playerId">): InningsFielder {
  return { catches: 0, runOuts: 0, stumpings: 0, ...partial };
}

function innings(partial: Partial<Innings> & Pick<Innings, "inningsNumber">): Innings {
  return {
    battingTeamId: "a",
    bowlingTeamId: "b",
    status: "completed",
    totalRuns: 0,
    totalWickets: 0,
    legalBalls: 0,
    extras: 0,
    batsmen: [],
    bowlers: [],
    fielders: [],
    partnershipRuns: 0,
    partnershipBalls: 0,
    isFreeHitActive: false,
    partnerships: [],
    fallOfWickets: [],
    ...partial,
  };
}

function legalRun(opts: {
  id: string;
  sequence: number;
  overNumber: number;
  ballInOver: number;
  runs: number;
  strikerId?: string;
  bowlerId?: string;
  countsAsBallFaced?: boolean;
}): BallEvent {
  return {
    id: opts.id,
    matchId: "m1",
    inningsNumber: 1,
    overNumber: opts.overNumber,
    ballInOver: opts.ballInOver,
    eventType: "runs",
    runs: opts.runs,
    batsmanRuns: opts.runs,
    extraRuns: 0,
    isLegalDelivery: true,
    isWicket: false,
    isFreeHit: false,
    commentary: "",
    sequence: opts.sequence,
    strikerId: opts.strikerId ?? "a1",
    nonStrikerId: "a2",
    bowlerId: opts.bowlerId ?? "b1",
    countsInOver: true,
    countsToBowler: true,
    countsAsBallFaced: opts.countsAsBallFaced ?? true,
  };
}

describe("Dart cluster classification thresholds", () => {
  it("classifies batting in the same order as player_cluster_service.dart", () => {
    const base: BattingPatternStats = {
      balls: 100,
      runs: 0,
      strikeRate: 0,
      dotPct: 0,
      singlesPct: 0,
      doublesPct: 0,
      triplesPct: 0,
      boundaryPct: 0,
      sixPct: 0,
      inningsCount: 10,
      matchCount: 10,
    };
    expect(classifyBatting({ ...base, strikeRate: 160, boundaryPct: 18 })).toBe("destroyer");
    expect(classifyBatting({ ...base, strikeRate: 130, boundaryPct: 12 })).toBe("hardHitter");
    expect(classifyBatting({ ...base, singlesPct: 35, dotPct: 45, strikeRate: 119 })).toBe("accumulator");
    expect(classifyBatting({ ...base, doublesPct: 12, dotPct: 40, strikeRate: 110 })).toBe("classicist");
    expect(classifyBatting({ ...base, dotPct: 50, strikeRate: 99 })).toBe("steadyBatter");
    expect(classifyBatting({ ...base, strikeRate: 120, boundaryPct: 5 })).toBe("hardHitter");
    expect(classifyBatting({ ...base, strikeRate: 110, singlesPct: 30 })).toBe("accumulator");
    expect(classifyBatting({ ...base, strikeRate: 110, singlesPct: 10, doublesPct: 5 })).toBe("classicist");
  });

  it("classifies bowling in the same order as player_cluster_service.dart", () => {
    const base: BowlingPatternStats = {
      wickets: 0,
      economy: 0,
      average: 0,
      strikeRate: 0,
      dotPct: 0,
      oversBowled: 0,
      matchCount: 5,
    };
    expect(classifyBowling({ ...base, wickets: 4, oversBowled: 9 })).toBe("aspirant");
    expect(classifyBowling({ ...base, wickets: 15, economy: 7, average: 22, oversBowled: 20 })).toBe("spearhead");
    expect(classifyBowling({ ...base, wickets: 8, economy: 6.5, average: 25, oversBowled: 20 })).toBe("economist");
    expect(classifyBowling({ ...base, wickets: 10, economy: 8.1, average: 30, oversBowled: 20 })).toBe("wildcard");
    expect(classifyBowling({ ...base, wickets: 6, economy: 7, average: 30, oversBowled: 15 })).toBe("economist");
    expect(classifyBowling({ ...base, wickets: 8, economy: 7.5, average: 30, oversBowled: 15 })).toBe("wildcard");
    expect(classifyBowling({ ...base, wickets: 6, economy: 7.5, average: 30, oversBowled: 15 })).toBe("aspirant");
  });

  it("requires the Dart minimum innings and bowling matches before tagging", () => {
    const completed: Match[] = Array.from({ length: 4 }, (_, i) =>
      match({
        id: `m${i}`,
        innings: [
          innings({
            inningsNumber: 1,
            totalRuns: 80,
            totalWickets: 3,
            legalBalls: 60,
            batsmen: [batter({ playerId: "p1", runs: 20, balls: 20, fours: 1, sixes: 1, isOut: true })],
            // Only two matches have bowling, below MIN_BOWLING_MATCHES (3).
            bowlers: i < 2 ? [bowler({ playerId: "p1", oversBowledBalls: 12, runsConceded: 10, wickets: 1 })] : [],
          }),
        ],
      }),
    );
    const clusters = computeClusters("p1", completed, {});
    expect(clusters.battingPattern.inningsCount).toBe(4);
    expect(clusters.bowlingPattern.matchCount).toBe(2);
    expect(clusters.batting).toBeNull();
    expect(clusters.bowling).toBeNull();
    expect(MIN_BATTING_INNINGS).toBe(5);
    expect(MIN_BOWLING_MATCHES).toBe(3);
  });

  it("uses countsAsBallFaced (not merely legal deliveries) when events exist", () => {
    const events: BallEvent[] = [
      legalRun({ id: "1", sequence: 1, overNumber: 1, ballInOver: 1, runs: 1, countsAsBallFaced: true }),
      legalRun({ id: "2", sequence: 2, overNumber: 1, ballInOver: 2, runs: 6, countsAsBallFaced: true }),
      {
        ...legalRun({ id: "3", sequence: 3, overNumber: 1, ballInOver: 3, runs: 1 }),
        countsAsBallFaced: false,
        eventType: "legBye",
        batsmanRuns: 0,
      },
    ];
    events[1].isBoundary = true;
    events[1].boundaryType = "six";
    const m = match({
      id: "m1",
      innings: [innings({ inningsNumber: 1, totalRuns: 8, legalBalls: 3 })],
    });
    const clusters = computeClusters("a1", [m], { m1: events });
    expect(clusters.battingPattern.balls).toBe(2);
    expect(clusters.battingPattern.runs).toBe(7);
  });
});

describe("Dart MatchMvpService award fixtures (test/match_mvp_service_test.dart)", () => {
  it("Player Of The Match is the first listed winner-side player when the result is decided", () => {
    const board = applyAwards({
      players: [score("a1", "a", 6.2, 1), score("a2", "a", 5.1, 2)],
      losingTeamId: "b",
      winnerTeamId: "a",
      teamAId: "a",
      teamBId: "b",
      format: dart20OverFormat,
    });
    expect(board.players.find((p) => p.isPlayerOfTheMatch)?.playerId).toBe("a1");
  });

  it("Fighter is the highest overall rank from the losing top 3", () => {
    const board = applyAwards({
      players: [
        score("a1", "a", 6.2, 1),
        score("a2", "a", 5.6, 2),
        score("b1", "b", 4.8, 3),
        score("b2", "b", 4.1, 4),
      ],
      losingTeamId: "b",
      winnerTeamId: "a",
      teamAId: "a",
      teamBId: "b",
      format: dart20OverFormat,
    });
    const fighter = board.players.find((p) => p.isFighterOfTheMatch);
    expect(fighter?.playerId).toBe("b1");
    expect(fighter?.rank).toBe(3);
  });

  it("POTM comes from the winning team; losing top MVP is Fighter", () => {
    const board = applyAwards({
      players: [score("b1", "b", 6.2, 1), score("a1", "a", 5.6, 2)],
      losingTeamId: "b",
      winnerTeamId: "a",
      teamAId: "a",
      teamBId: "b",
      format: dart20OverFormat,
    });
    expect(board.players.find((p) => p.isPlayerOfTheMatch)?.playerId).toBe("a1");
    expect(board.players.find((p) => p.isFighterOfTheMatch)?.playerId).toBe("b1");
  });

  it("tie / no result: POTM is the top MVP from either team and there is no Fighter", () => {
    const board = applyAwards({
      players: [score("b1", "b", 6.2, 1), score("a1", "a", 5.6, 2)],
      winnerTeamId: undefined,
      teamAId: "a",
      teamBId: "b",
      format: dart20OverFormat,
    });
    expect(board.players.find((p) => p.isPlayerOfTheMatch)?.playerId).toBe("b1");
    expect(board.players.find((p) => p.isFighterOfTheMatch)).toBeUndefined();
  });

  it("30-run-style knock is worth more in a 5-over match than a 50-over match", () => {
    const events: BallEvent[] = [];
    for (let i = 0; i < 12; i++) {
      events.push(
        legalRun({
          id: `e${i}`,
          sequence: i + 1,
          overNumber: Math.floor(i / 6) + 1,
          ballInOver: (i % 6) + 1,
          runs: i < 10 ? 2 : 1,
          countsAsBallFaced: false, // Dart test did not set this; ScoringEngine would. Fallback uses legal runs.
        }),
      );
    }
    const lineup = (): Innings[] => [
      innings({
        inningsNumber: 1,
        legalBalls: 12,
        batsmen: [batter({ playerId: "a1", playerName: "Striker" }), batter({ playerId: "a2", playerName: "Non" })],
        bowlers: [bowler({ playerId: "b1", playerName: "Bowler" })],
      }),
    ];
    const shortBoard = buildMatchMvp(
      match({ id: "m1", winnerTeamId: "a", rules: { ...defaultRules, totalOvers: 5 }, innings: lineup() }),
      events,
    );
    const longBoard = buildMatchMvp(
      match({ id: "m1", winnerTeamId: "a", rules: { ...defaultRules, totalOvers: 50 }, innings: lineup() }),
      events,
    );
    const shortScore = shortBoard.players.find((p) => p.playerId === "a1")!.battingMvp;
    const longScore = longBoard.players.find((p) => p.playerId === "a1")!.battingMvp;
    expect(shortScore).toBeGreaterThan(longScore);
  });

  it("supports custom balls per over", () => {
    const events: BallEvent[] = [];
    for (let i = 0; i < 12; i++) {
      events.push(
        legalRun({
          id: `e${i}`,
          sequence: i + 1,
          overNumber: Math.floor(i / 8) + 1,
          ballInOver: (i % 8) + 1,
          runs: i < 10 ? 2 : 1,
          countsAsBallFaced: false,
        }),
      );
    }
    const board = buildMatchMvp(
      match({
        id: "m1",
        winnerTeamId: "a",
        rules: { ...defaultRules, totalOvers: 8, ballsPerOver: 8 },
        innings: [
          innings({
            inningsNumber: 1,
            legalBalls: 12,
            batsmen: [batter({ playerId: "a1", playerName: "Striker" })],
            bowlers: [bowler({ playerId: "b1", playerName: "Bowler" })],
          }),
        ],
      }),
      events,
    );
    expect(board.hasData).toBe(true);
    expect(board.formatContext?.ballsPerOver).toBe(8);
  });

  it("uses the Dart format tables and wicket-value formula", () => {
    expect(formatExpectedRuns(20, false)).toBe(20 * 7);
    expect(formatExpectedRuns(5, false)).toBe(5 * 9.5);
    expect(formatExpectedRuns(50, true)).toBe(280);
    expect(parStrikeRate(20, false)).toBe(115);
    expect(parEconomy(20, false)).toBe(7);
    expect(wicketValue(1, 10)).toBeCloseTo(1.25, 8);
    expect(wicketValue(5, 10)).toBeCloseTo((1 - 4 * 0.075) * 1.25, 8);
    expect(wicketValue(20, 10)).toBeCloseTo(0.35 * 1.25, 8);
    expect(classifyOver(1, defaultRules)).toBe("powerplay");
    expect(classifyOver(20, defaultRules)).toBe("death");
  });
});

describe("Dart PlayerBadgeCatalogService catalog and progression", () => {
  it("contains the full catalog line by line (73 definitions, exact ids)", () => {
    const ids = BADGE_CATALOG.map((d) => d.id);
    expect(ids).toEqual([
      "bat_30", "bat_50", "bat_75", "bat_100", "bat_150", "bat_200",
      "fast_50", "fast_100",
      "sr_200", "sr_250", "sr_300",
      "4s_10", "4s_15", "4s_20",
      "6s_5", "6s_10", "6s_15",
      "career_runs_100", "career_runs_500", "career_runs_1000", "career_runs_5000", "career_runs_10000",
      "career_6s_50", "career_6s_100", "career_6s_250", "career_6s_500",
      "bowl_3", "bowl_4", "bowl_5", "bowl_6",
      "maiden",
      "career_wkts_50", "career_wkts_100", "career_wkts_250", "career_wkts_500",
      "econ_4", "econ_3",
      "catch_3", "catch_5",
      "ro_direct", "ro_2", "safe_hands",
      "career_catch_50", "career_catch_100", "career_catch_250",
      "cap_wins_10", "cap_wins_25", "cap_wins_50", "cap_wins_100",
      "winning_machine", "chase_master", "defender",
      "debut", "matches_25", "matches_50", "matches_100", "matches_250", "matches_500",
      "veteran", "legend",
      "all_round_match", "potm_streak", "all_round_hero", "iron_man", "finisher", "super_over_hero",
      "first_century", "first_five_wicket", "first_hat_trick", "first_motm", "first_mvp_rank",
      "tournament_winner", "captain_champion",
    ]);
    expect(BADGE_CATALOG).toHaveLength(73);
    const century = BADGE_CATALOG.find((d) => d.id === "bat_100")!;
    expect(century.title).toBe("100 in a Match");
    expect(century.tier).toBe("gold");
    expect(century.progressionGroup).toBe("runs_in_match");
    expect(century.groupOrder).toBe(4);
    expect(BADGE_CATALOG.find((d) => d.id === "debut")?.repeatability).toBe("oneTime");
  });

  it("awards only the highest eligible match and career tiers (no cascade)", () => {
    const records = new Map();
    applyCareerHighestOnly(records, 1200, [
      ["career_runs_100", 100],
      ["career_runs_500", 500],
      ["career_runs_1000", 1000],
      ["career_runs_5000", 5000],
      ["career_runs_10000", 10000],
    ]);
    expect([...records.keys()]).toEqual(["career_runs_1000"]);

    const m = match({
      id: "m1",
      completedAt: new Date("2024-01-01T00:00:00Z"),
      innings: [
        innings({
          inningsNumber: 1,
          totalRuns: 120,
          totalWickets: 2,
          legalBalls: 60,
          batsmen: [batter({ playerId: "p1", runs: 120, balls: 70, fours: 12, sixes: 6, isOut: true })],
          bowlers: [bowler({ playerId: "p1", oversBowledBalls: 24, runsConceded: 18, wickets: 5 })],
          fielders: [fielder({ playerId: "p1", catches: 3, runOuts: 2 })],
        }),
      ],
    });
    const progress = evaluateBadgeCatalog({
      playerId: "p1",
      completedMatches: [m],
      stats: { runs: 120, wickets: 5, sixes: 6, catches: 3, matchesPlayed: 1, oversBowledBalls: 24, runsConceded: 18 },
      captainStats: { wins: 0, matchesAsCaptain: 0, winPct: 0, successfulChases: 0, lowestDefendedScore: 0 },
    });
    const unlocked = progress.filter((b) => b.unlocked).map((b) => b.definition.id).sort();
    // Highest-only: bat_100 (not bat_30/50/75), 6s_5, 4s_10, bowl_5 (not 3/4), catch_3, ro_2,
    // all_round_match (100 & 5) not all_round_hero, first_century, first_five_wicket, debut.
    expect(unlocked).toContain("bat_100");
    expect(unlocked).not.toContain("bat_30");
    expect(unlocked).not.toContain("bat_50");
    expect(unlocked).not.toContain("bat_75");
    expect(unlocked).toContain("bowl_5");
    expect(unlocked).not.toContain("bowl_3");
    expect(unlocked).toContain("all_round_match");
    expect(unlocked).not.toContain("all_round_hero");
    expect(unlocked).toContain("first_century");
    expect(unlocked).toContain("first_five_wicket");
    expect(unlocked).toContain("debut");
    expect(unlocked).toContain("6s_5");
    expect(unlocked).toContain("4s_10");
    expect(unlocked).toContain("catch_3");
    expect(unlocked).toContain("ro_2");
  });

  it("uses the Dart SR badge qualification (6+ balls or 21+ runs)", () => {
    expect(qualifiesForSrBadge(20, 5)).toBe(false);
    expect(qualifiesForSrBadge(21, 5)).toBe(true);
    expect(qualifiesForSrBadge(10, 6)).toBe(true);
  });
});

describe("PlayerTrophyService MVP vs scorecard path", () => {
  it("falls back to scorecard trophies when a match has no ball events", () => {
    const m = match({
      id: "m1",
      winnerTeamId: "a",
      playerOfMatchId: "p1",
      completedAt: new Date("2024-06-01T00:00:00Z"),
      setup: {
        teamAPlayingPlayers: [{ id: "p1", name: "P" }],
        teamBPlayingPlayers: [{ id: "p2", name: "Q" }],
      },
      innings: [
        innings({
          inningsNumber: 1,
          totalRuns: 90,
          totalWickets: 2,
          legalBalls: 60,
          batsmen: [
            batter({ playerId: "p1", runs: 70, balls: 40, fours: 6, sixes: 3, isOut: true }),
            batter({ playerId: "p2", playerName: "Q", runs: 10, balls: 12, fours: 1, isOut: true }),
          ],
          bowlers: [bowler({ playerId: "p2", playerName: "Q", oversBowledBalls: 24, runsConceded: 40, wickets: 1 })],
          fielders: [fielder({ playerId: "p2", catches: 2 })],
        }),
      ],
    });
    const trophies = computeTrophies("p1", [m], {});
    expect(trophies.map((t) => t.kind)).toContain("playerOfMatch");
    expect(trophies.map((t) => t.kind)).toContain("bestBatter");
    expect(trophies.find((t) => t.kind === "playerOfMatch")?.title).toBe("Player Of The Match");
    expect(trophies.find((t) => t.kind === "playerOfMatch")?.emoji).toBe("🏆");
    expect(trophies.find((t) => t.kind === "bestBatter")?.performance).toBe("70 (40)");
  });
});
