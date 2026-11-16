export const CLUB_ADMIN_STATUS = {
  invited: "invited",
  active: "active",
  pending: "pending",
  cancelled: "cancelled",
  declined: "declined",
  removed: "removed",
} as const;

export function isEffectiveClubAdmin(status?: string | null): boolean {
  return status === CLUB_ADMIN_STATUS.active;
}

export function isOpenClubAdminInvite(status?: string | null): boolean {
  return status === CLUB_ADMIN_STATUS.invited;
}

export function canInviteClubAdmin(existingStatus?: string | null): boolean {
  if (!existingStatus) return true;
  return (
    existingStatus === CLUB_ADMIN_STATUS.cancelled ||
    existingStatus === CLUB_ADMIN_STATUS.declined ||
    existingStatus === CLUB_ADMIN_STATUS.removed
  );
}

export function clubAdminStatusLabel(status?: string | null): string {
  switch ((status || "").toLowerCase()) {
    case "invited":
    case "pending":
      return "Pending";
    case "cancelled":
      return "Cancelled";
    case "declined":
      return "Declined";
    case "removed":
      return "Removed";
    case "active":
    default:
      return "Active";
  }
}

export function isListedSquadMember(status?: string | null): boolean {
  return status === "active" || status === "pendingRemoval";
}

export function squadStatusLabel(status?: string | null): string {
  if (status === "pendingRemoval") return "Removal pending";
  if (status === "removed") return "Removed";
  if (status === "suspended") return "Suspended";
  return "Active";
}
