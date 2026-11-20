/** Port of Flutter `lib/domain/notifications/notification_priority.dart`. */

export type NotificationTab = "priority" | "general";

const ACTION_TYPES = new Set([
  "team_join_request",
  "team_invitation",
  "tournament_invitation",
  "tournament_join_request",
  "tournament_official_invitation",
  "series_approval_pending",
  "series_club_join_request",
  "admin_roster_report",
]);

const DECISION_TYPES = new Set([
  "team_join_accepted",
  "team_join_rejected",
  "team_invitation_accepted",
  "team_invitation_rejected",
  "tournament_invitation_accepted",
  "tournament_invitation_rejected",
  "tournament_join_approved",
  "tournament_join_rejected",
  "tournament_official_invitation_accepted",
  "tournament_official_invitation_rejected",
  "series_approval_approved",
  "series_approval_rejected",
]);

export function isPriorityType(type?: string | null): boolean {
  return Boolean(type && (ACTION_TYPES.has(type) || DECISION_TYPES.has(type)));
}

export function isPriorityNotification(n: {
  priority?: boolean | null;
  type?: string | null;
}): boolean {
  if (typeof n.priority === "boolean") return n.priority;
  return isPriorityType(n.type);
}

export function notificationTabOf(n: {
  priority?: boolean | null;
  type?: string | null;
}): NotificationTab {
  return isPriorityNotification(n) ? "priority" : "general";
}

export function filterNotificationsByTab<
  T extends { priority?: boolean | null; type?: string | null },
>(items: T[], tab: NotificationTab): T[] {
  return items.filter((n) => notificationTabOf(n) === tab);
}

export function unreadNotificationCounts<
  T extends { read: boolean; priority?: boolean | null; type?: string | null },
>(items: T[]): Record<NotificationTab, number> {
  const out: Record<NotificationTab, number> = { priority: 0, general: 0 };
  for (const n of items) {
    if (n.read) continue;
    out[notificationTabOf(n)] += 1;
  }
  return out;
}

/** Related unread ids to mark read when opening/acting on one notification. */
export function relatedNotificationIds(
  acted: {
    type?: string;
    teamId?: string;
    playerId?: string;
    requestId?: string;
    matchId?: string;
  },
  all: Array<{
    id: string;
    read: boolean;
    type?: string;
    teamId?: string;
    playerId?: string;
    requestId?: string;
    matchId?: string;
  }>,
): string[] {
  const ids: string[] = [];
  for (const n of all) {
    if (n.read) continue;
    if (acted.matchId && n.matchId === acted.matchId) {
      ids.push(n.id);
      continue;
    }
    if (
      acted.type === "series_approval_pending" &&
      n.type === "series_approval_pending" &&
      acted.requestId &&
      n.requestId === acted.requestId
    ) {
      ids.push(n.id);
      continue;
    }
    if (
      acted.type === "team_join_request" &&
      n.type === "team_join_request" &&
      acted.teamId &&
      n.teamId === acted.teamId &&
      (n.playerId === acted.playerId || n.requestId === acted.requestId)
    ) {
      ids.push(n.id);
    }
  }
  return [...new Set(ids)];
}
