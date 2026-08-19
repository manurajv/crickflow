import { describe, expect, it } from "vitest";
import { chatIdFor, chatBlockId } from "@/lib/chat";
import { followCollection, followDocId, followPayload } from "@/lib/follow";
import { locationMatchesTextFilter, locationWritePayload } from "@/lib/cricket/location";

describe("follow document ids", () => {
  it("uses follower_followed for players", () => {
    expect(followDocId("player", "followedUid", "me")).toBe("me_followedUid");
    expect(followCollection("player")).toBe("playerFollows");
    expect(followPayload("player", "followedUid", "me")).toMatchObject({
      followerUserId: "me",
      followedUserId: "followedUid",
    });
  });

  it("uses target_user for teams and matches", () => {
    expect(followDocId("team", "team1", "me")).toBe("team1_me");
    expect(followPayload("team", "team1", "me")).toMatchObject({ teamId: "team1", userId: "me" });
    expect(followPayload("match", "m1", "me")).toMatchObject({ matchId: "m1", userId: "me" });
  });
});

describe("chat ids", () => {
  it("sorts participant uids", () => {
    expect(chatIdFor("b", "a")).toBe("a_b");
    expect(chatIdFor("a", "b")).toBe("a_b");
  });

  it("uses blocker_blocked for chat blocks", () => {
    expect(chatBlockId("me", "them")).toBe("me_them");
  });
});

describe("location text filter", () => {
  it("matches country and city contains", () => {
    const loc = { country: "Sri Lanka", stateProvince: "Western", city: "Colombo" };
    expect(locationMatchesTextFilter(loc, { country: "sri", city: "Col" })).toBe(true);
    expect(locationMatchesTextFilter(loc, { city: "Kandy" })).toBe(false);
    expect(locationMatchesTextFilter(loc, {})).toBe(true);
  });

  it("writes location with optional coordinates", () => {
    expect(locationWritePayload({ city: "Colombo" }, { latitude: 6.9, longitude: 79.8 })).toMatchObject({
      city: "Colombo",
      latitude: 6.9,
      longitude: 79.8,
    });
  });
});
