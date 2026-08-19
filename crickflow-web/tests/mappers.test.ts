import { describe, expect, it } from "vitest";
import { mapFantasyLeague, mapHighlight, mapLocation, mapMatch } from "@/lib/firebase/mappers";

describe("mapLocation", () => {
  it("accepts venue aliases and lat/lng", () => {
    expect(mapLocation({ venue: "SSC Grounds", lat: 6.9, lng: 79.8 })).toMatchObject({
      placeName: "SSC Grounds",
      latitude: 6.9,
      longitude: 79.8,
    });
  });
});

describe("mapHighlight", () => {
  it("falls back to tag as title", () => {
    const highlight = mapHighlight("h1", { tag: "six", url: "https://example.com/clip.mp4" });
    expect(highlight.title).toBe("six");
    expect(highlight.mediaUrl).toBe("https://example.com/clip.mp4");
  });
});

describe("mapFantasyLeague", () => {
  it("defaults status and squad size", () => {
    expect(mapFantasyLeague("f1", { name: "Office cup", matchId: "m1" })).toMatchObject({
      name: "Office cup",
      matchId: "m1",
      status: "open",
      squadSize: 11,
    });
  });
});

describe("mapMatch", () => {
  it("never copies stream ingest secrets onto the client model", () => {
    const match = mapMatch("m1", {
      title: "Kings vs Lions",
      teamAName: "Kings",
      teamBName: "Lions",
      stream: {
        status: "live",
        youtubeWatchUrl: "https://youtu.be/abcdefghijk",
        streamKey: "SECRET_STREAM_KEY",
        rtmpUrl: "rtmp://ingest.example/live",
      },
    });
    const serialized = JSON.stringify(match);
    expect(serialized).not.toContain("SECRET_STREAM_KEY");
    expect(serialized).not.toContain("rtmp://");
    expect(match.stream.youtubeWatchUrl).toBe("https://youtu.be/abcdefghijk");
    expect(match.stream.status).toBe("live");
  });

  it("applies batting rule defaults", () => {
    const match = mapMatch("m2", {});
    expect(match.rules.totalOvers).toBe(20);
    expect(match.rules.ballsPerOver).toBe(6);
    expect(match.rules.freeHitEnabled).toBe(true);
  });
});
