import { describe, expect, it } from "vitest";
import { extrasFromEvents, eventTypeLabel, matchInvolvesPlayer, notificationCategoryLabel, notificationHref } from "@/lib/cricket/events";
import type { BallEvent } from "@/types/models";

function event(partial: Partial<BallEvent>): BallEvent {
  return {
    id: "1",
    matchId: "m",
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
    ...partial,
  };
}

describe("ball event labels", () => {
  it("labels extras and dismissals", () => {
    expect(eventTypeLabel("wide")).toBe("Wide");
    expect(eventTypeLabel("noBall")).toBe("No Ball");
    expect(eventTypeLabel("retiredHurt")).toBe("Retired Hurt");
  });

  it("aggregates extras", () => {
    const extras = extrasFromEvents([
      event({ eventType: "wide", extraRuns: 1, runs: 1 }),
      event({ eventType: "legBye", extraRuns: 2, runs: 2 }),
      event({ eventType: "noBall", extraRuns: 1 }),
    ]);
    expect(extras.wides).toBe(1);
    expect(extras.legByes).toBe(2);
    expect(extras.noBalls).toBe(1);
  });
});

describe("notification deep links", () => {
  it("prefers match over other ids", () => {
    expect(
      notificationHref({ matchId: "abc", tournamentId: "t1" }),
    ).toBe("/matches/abc");
  });

  it("returns null when no entity", () => {
    expect(notificationHref({})).toBeNull();
  });

  it("routes community and live match types", () => {
    expect(notificationHref({ type: "community_like", requestId: "p1" })).toBe("/community/p1");
    expect(notificationHref({ type: "stream_started", matchId: "m1" })).toBe("/matches/m1/watch");
    expect(notificationHref({ type: "wicket", matchId: "m1" })).toBe("/matches/m1/live");
  });

  it("labels notification categories", () => {
    expect(notificationCategoryLabel("community", "community_like")).toBe("Community");
    expect(notificationCategoryLabel(undefined, "wicket")).toBe("Wicket");
  });
});

describe("player match membership", () => {
  it("detects a batter id in innings", () => {
    expect(
      matchInvolvesPlayer(
        { innings: [{ batsmen: [{ playerId: "p1" }], bowlers: [] }] },
        "p1",
      ),
    ).toBe(true);
    expect(
      matchInvolvesPlayer(
        { innings: [{ batsmen: [{ playerId: "p1" }], bowlers: [] }] },
        "p2",
      ),
    ).toBe(false);
  });
});
