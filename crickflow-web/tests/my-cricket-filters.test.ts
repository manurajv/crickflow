import { describe, expect, it } from "vitest";
import {
  filterMatchByScope,
  filterTeamByScope,
  filterTournamentByScope,
  followedPlayerRefsFromPlayers,
  highlightMatchesForUser,
  memberTeamIds,
  sortMyCricketMatches,
  userOwnsOrScoresMatch,
} from "@/lib/cricket/my-cricket-filters";
import type { LocationData, Match, Player, Team, Tournament } from "@/types/models";

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
    status: "upcoming",
    teamAName: "A",
    teamBName: "B",
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

describe("My Cricket ownership filters", () => {
  const yours = match({ id: "m1", teamAId: "tA", teamBId: "tB", createdBy: "other" });
  const scored = match({
    id: "m2",
    teamAId: "tX",
    teamBId: "tY",
    createdBy: "u1",
    status: "completed",
  });
  const network = match({
    id: "m3",
    teamAId: "tQ",
    teamBId: "tR",
    createdBy: "friend",
    status: "upcoming",
  });
  const publicMatch = match({ id: "m4", teamAId: "tZ", teamBId: "tW", createdBy: "stranger" });
  const userTeamIds = new Set(["tA"]);
  const followed = followedPlayerRefsFromPlayers([{ userId: "friend", id: "pf" }]);

  it("Yours is team participation, not the public list", () => {
    expect(filterMatchByScope(yours, "yours", { uid: "u1", player, userTeamIds })).toBe(true);
    expect(filterMatchByScope(scored, "yours", { uid: "u1", player, userTeamIds })).toBe(false);
    expect(filterMatchByScope(publicMatch, "yours", { uid: "u1", player, userTeamIds })).toBe(false);
  });

  it("Played includes completed matches the user created or scored", () => {
    expect(userOwnsOrScoresMatch(scored, "u1")).toBe(true);
    expect(filterMatchByScope(scored, "played", { uid: "u1", player, userTeamIds })).toBe(true);
    expect(filterMatchByScope(yours, "played", { uid: "u1", player, userTeamIds })).toBe(false);
  });

  it("Network is followed people, excluding your own matches", () => {
    expect(filterMatchByScope(network, "network", { uid: "u1", player, userTeamIds, followedPlayers: followed })).toBe(true);
    expect(filterMatchByScope(yours, "network", { uid: "u1", player, userTeamIds, followedPlayers: followed })).toBe(false);
    expect(filterMatchByScope(publicMatch, "network", { uid: "u1", player, userTeamIds, followedPlayers: followed })).toBe(false);
  });

  it("Highlights lists only the user's completed matches", () => {
    const list = highlightMatchesForUser([yours, scored, network, { ...yours, id: "m5", status: "completed" }], {
      uid: "u1",
      player,
      userTeamIds,
    });
    expect(list.map((m) => m.id).sort()).toEqual(["m2", "m5"]);
  });

  it("sorts newest first by completed/scheduled date", () => {
    const a = match({ id: "a", createdAt: new Date("2024-01-01") });
    const b = match({ id: "b", createdAt: new Date("2025-01-01") });
    expect(sortMyCricketMatches([a, b], "newest").map((m) => m.id)).toEqual(["b", "a"]);
  });

  it("filters tournaments and teams by ownership", () => {
    const hosted: Tournament = {
      id: "tn1",
      name: "Cup",
      format: "league",
      status: "upcoming",
      teamIds: ["tA"],
      matchIds: [],
      pointsTable: [],
      bracketRounds: [],
      location: loc,
      grounds: [],
      createdBy: "u1",
      organizerId: "u1",
    };
    const other: Tournament = { ...hosted, id: "tn2", createdBy: "x", organizerId: "x", teamIds: ["tZ"] };
    expect(filterTournamentByScope(hosted, "yours", { uid: "u1", userTeamIds })).toBe(true);
    expect(filterTournamentByScope(other, "yours", { uid: "u1", userTeamIds })).toBe(false);

    const teamA: Team = {
      id: "tA",
      name: "Alpha",
      playerIds: ["p1"],
      memberCount: 1,
      location: loc,
      stats: {
        matchesPlayed: 0,
        matchesWon: 0,
        matchesLost: 0,
        matchesTied: 0,
        points: 0,
        netRunRate: 0,
        totalRunsScored: 0,
        totalWicketsTaken: 0,
        totalWicketsLost: 0,
      },
    };
    const teamZ: Team = { ...teamA, id: "tZ", name: "Zulu", playerIds: [] };
    const members = memberTeamIds({ teams: [teamA, teamZ], uid: "u1", player });
    expect(filterTeamByScope(teamA, "yours", { memberTeamIds: members, opponentTeamIds: new Set() })).toBe(true);
    expect(filterTeamByScope(teamZ, "yours", { memberTeamIds: members, opponentTeamIds: new Set() })).toBe(false);
  });
});
