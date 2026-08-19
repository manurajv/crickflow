import { describe, expect, it } from "vitest";
import { economy, formatOvers, formatRelativeTime, strikeRate } from "@/lib/cricket/format";
import { haversineKm, firstGrapheme, searchHaystack, searchScore, slugify, youtubeEmbedId } from "@/lib/utils";

describe("cricket formatters", () => {
  it("formats overs from legal balls", () => {
    expect(formatOvers(0)).toBe("0.0");
    expect(formatOvers(7, 6)).toBe("1.1");
    expect(formatOvers(20, 6)).toBe("3.2");
  });

  it("computes strike rate", () => {
    expect(strikeRate(50, 25)).toBe("200.0");
    expect(strikeRate(10, 0)).toBe("—");
  });

  it("computes economy from legal balls", () => {
    expect(economy(30, 12)).toBe("15.00");
    expect(economy(10, 0)).toBe("—");
  });

  it("formats relative timestamps", () => {
    expect(formatRelativeTime(undefined)).toBe("");
    expect(formatRelativeTime(new Date())).toMatch(/ago|in /i);
  });
});

describe("media and geo helpers", () => {
  it("extracts YouTube ids", () => {
    expect(youtubeEmbedId("https://youtu.be/abcdefghijk")).toBe("abcdefghijk");
    expect(youtubeEmbedId("https://www.youtube.com/watch?v=abcdefghijk")).toBe("abcdefghijk");
    expect(youtubeEmbedId(undefined)).toBeNull();
  });

  it("computes nearby distance", () => {
    const km = haversineKm(6.9271, 79.8612, 6.9271, 79.8612);
    expect(km).toBeCloseTo(0, 5);
  });
});

describe("search", () => {
  it("scores exact matches highest", () => {
    expect(searchScore("Colombo Kings", "Colombo Kings")).toBeGreaterThan(
      searchScore("Colombo Kings", "Colombo"),
    );
  });

  it("searches across haystack parts", () => {
    expect(searchHaystack("kings", ["Colombo Kings", "SSC"])).toBeGreaterThan(0);
    expect(searchHaystack("xyz", ["Colombo Kings"])).toBe(0);
    expect(searchHaystack("", ["Colombo Kings"])).toBe(1);
  });

  it("slugifies ground names", () => {
    expect(slugify("SSC Grounds, Colombo")).toBe("ssc-grounds-colombo");
  });

  it("keeps emoji initials intact", () => {
    expect(firstGrapheme("🐅 Bundiora Cricket Club")).toBe("🐅");
    expect(firstGrapheme("Colombo Kings")).toBe("C");
  });
});
