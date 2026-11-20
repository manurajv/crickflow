import { describe, expect, it } from "vitest";
import {
  isActionableNotification,
  notificationActionStatusLabel,
  usesApproveRejectActions,
} from "@/lib/cricket/notification-actions";

describe("notification inbox actions", () => {
  it("uses the in-place outcome labels", () => {
    expect(notificationActionStatusLabel("accepted")).toBe("You accepted");
    expect(notificationActionStatusLabel("declined")).toBe("You declined");
    expect(notificationActionStatusLabel("approved")).toBe("Approved");
    expect(notificationActionStatusLabel("rejected")).toBe("Rejected");
    expect(notificationActionStatusLabel("cancelled")).toBe("Cancelled by sender");
    expect(notificationActionStatusLabel("expired")).toBe("Expired");
  });

  it("sends join-request reviews to the detail screen instead of inbox buttons", () => {
    expect(isActionableNotification({ type: "series_club_admin_invite" })).toBe(true);
    expect(isActionableNotification({ type: "series_approval_pending", reviewScope: "org" })).toBe(false);
    expect(usesApproveRejectActions({ type: "series_approval_pending", reviewScope: "club" })).toBe(false);
  });
});
