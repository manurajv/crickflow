import { describe, expect, it } from "vitest";
import {
  filterNotificationsByTab,
  isPriorityNotification,
  unreadNotificationCounts,
} from "@/lib/cricket/notification-priority";

describe("notification priority (app parity)", () => {
  it("uses server flag when present", () => {
    expect(isPriorityNotification({ priority: true, type: "wicket" })).toBe(true);
    expect(isPriorityNotification({ priority: false, type: "team_join_request" })).toBe(
      false,
    );
  });

  it("falls back to action/decision types", () => {
    expect(isPriorityNotification({ type: "team_join_request" })).toBe(true);
    expect(isPriorityNotification({ type: "series_approval_pending" })).toBe(true);
    expect(isPriorityNotification({ type: "match_started" })).toBe(false);
  });

  it("splits tabs and unread counts", () => {
    const items = [
      { id: "1", read: false, type: "team_join_request" },
      { id: "2", read: false, type: "wicket" },
      { id: "3", read: true, type: "series_approval_pending" },
    ];
    expect(filterNotificationsByTab(items, "priority")).toHaveLength(2);
    expect(filterNotificationsByTab(items, "general")).toHaveLength(1);
    expect(unreadNotificationCounts(items)).toEqual({ priority: 1, general: 1 });
  });
});
