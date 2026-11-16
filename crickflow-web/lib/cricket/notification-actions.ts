import {
  respondSeriesClubAdminInvite,
  reviewClubJoinRequest,
  reviewSeriesApproval,
} from "@/features/series/repository";

export function notificationActionStatusLabel(status?: string | null) {
  switch (status) {
    case "accepted":
    case "joined":
      return "You accepted";
    case "declined":
      return "You declined";
    case "approved":
      return "Approved";
    case "rejected":
      return "Rejected";
    case "cancelled":
    case "canceled":
      return "Cancelled by sender";
    case "expired":
      return "Expired";
    default:
      return status || "";
  }
}

export function isActionableNotification(item: {
  type?: string;
  actionStatus?: string;
  reviewScope?: string;
}) {
  if (item.actionStatus) return false;
  if (item.type === "series_club_admin_invite") return true;
  if (
    item.type === "series_approval_pending" &&
    (item.reviewScope === "org" || item.reviewScope === "club")
  ) {
    return true;
  }
  return false;
}

export function usesApproveRejectActions(item: { type?: string; reviewScope?: string }) {
  return item.type === "series_approval_pending" &&
    (item.reviewScope === "org" || item.reviewScope === "club");
}

/** Respond to an inbox action. Team/tournament invites are still completed
 *  from those pages when no web helper exists; series actions call functions. */
export async function respondInboxNotification(
  item: {
    type?: string;
    seriesId?: string;
    clubId?: string;
    requestId?: string;
    reviewScope?: string;
  },
  accept: boolean,
  reason = "",
) {
  if (item.type === "series_club_admin_invite") {
    if (!item.seriesId || !item.clubId) throw new Error("This invitation is missing team details");
    await respondSeriesClubAdminInvite({
      seriesId: item.seriesId,
      clubId: item.clubId,
      decision: accept ? "accepted" : "declined",
    });
    return accept ? "accepted" : "declined";
  }
  if (item.type === "series_approval_pending") {
    if (!item.seriesId || !item.requestId) throw new Error("This request is missing approval details");
    if (item.reviewScope === "club") {
      await reviewClubJoinRequest({
        seriesId: item.seriesId,
        approvalId: item.requestId,
        decision: accept ? "approved" : "rejected",
        reason,
      });
    } else {
      await reviewSeriesApproval(item.seriesId, item.requestId, accept ? "approved" : "rejected", reason);
    }
    return accept ? "approved" : "rejected";
  }
  throw new Error("Open the linked page to finish this request.");
}
