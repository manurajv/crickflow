"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import {
  useReviewClubJoinRequest,
  useReviewSeriesApproval,
  useSeriesDetail,
  useSeriesRegistrationIdentity,
} from "@/features/series/hooks";
import { usePathParam } from "@/lib/use-path-param";
import { loginUrl } from "@/lib/auth/guest-access";
import { markNotificationsRead, watchNotifications } from "@/repositories";
import { relatedNotificationIds } from "@/lib/cricket/notification-priority";
import type { AppNotification } from "@/types/models";

export function SeriesApprovalsPage() {
  const seriesId = usePathParam("seriesId", 1);
  const { user } = useAuth();
  const { data, isLoading } = useSeriesDetail(seriesId, user?.uid);
  const review = useReviewSeriesApproval(seriesId || "");
  const clubReview = useReviewClubJoinRequest(seriesId || "");
  const identity = useSeriesRegistrationIdentity(seriesId || "");
  const [filter, setFilter] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [notifications, setNotifications] = useState<AppNotification[]>([]);

  useEffect(() => {
    if (!user) return;
    return watchNotifications(user.uid, setNotifications);
  }, [user]);

  async function markRelatedRead(approvalId: string) {
    const ids = relatedNotificationIds(
      { type: "series_approval_pending", requestId: approvalId },
      notifications,
    );
    if (ids.length) await markNotificationsRead(ids);
  }

  const isOrgReviewer = Boolean(data?.canManage || data?.isSuperAdmin);
  const adminClubIds = data?.myAdminClubIds ?? [];
  const clubPending = useMemo(() => {
    const allowed = new Set(adminClubIds);
    return (data?.approvals ?? []).filter((a) => {
      if (a.targetType !== "playerJoin") return false;
      const clubReviewStatus = a.metadata.clubReviewStatus;
      const clubId = typeof a.clubId === "string"
        ? a.clubId
        : typeof a.metadata.clubId === "string"
          ? a.metadata.clubId
          : "";
      return (
        (clubReviewStatus === "pending" || clubReviewStatus == null) &&
        allowed.has(clubId)
      );
    });
  }, [data?.approvals, adminClubIds]);
  const items = useMemo(() => {
    const all = data?.approvals ?? [];
    // Org queue: player joins only after the team has approved.
    return all.filter((a) => {
      if (a.targetType !== "playerJoin") return true;
      return a.metadata.clubReviewStatus === "approved";
    });
  }, [data?.approvals]);
  const types = useMemo(
    () => [...new Set(items.map((i) => i.targetType))].sort(),
    [items],
  );
  const filtered = filter ? items.filter((i) => i.targetType === filter) : items;
  const typeLabel = (t: string) =>
    ({
      playerJoin: "Player registration",
      playerAdd: "Add player",
      playerRegistration: "Player registration",
    } as Record<string, string>)[t] || t;

  function registrationIdOf(a: (typeof items)[number]) {
    const fromMeta = a.metadata.registrationId;
    if (typeof fromMeta === "string" && fromMeta) return fromMeta;
    if (a.targetType === "playerRegistration") return a.targetId;
    return "";
  }

  async function onViewDocs(a: (typeof items)[number]) {
    const registrationId = registrationIdOf(a);
    if (!registrationId) {
      window.alert("No registration is linked to this request.");
      return;
    }
    try {
      const result = await identity.mutateAsync(registrationId);
      const identityMap = (result as { identity?: Record<string, unknown>; public?: Record<string, unknown> }).identity || {};
      const pub = (result as { public?: Record<string, unknown> }).public || {};
      const lines = [
        ...Object.entries(pub),
        ...Object.entries(identityMap),
      ]
        .filter(([, v]) => v != null && String(v).trim())
        .map(([k, v]) => `${k}: ${v}`)
        .join("\n");
      window.alert(lines || "No private details on file.");
    } catch {
      window.alert("Could not load registration details.");
    }
  }

  if (!seriesId || isLoading) return <p>Loading…</p>;
  if (!user) {
    return (
      <EmptyState
        title="Sign in required"
        action={<Link href={loginUrl(`/series/${seriesId}/approvals`, "org_manage")}>Sign in</Link>}
      />
    );
  }
  if (!data?.canViewStaff) {
    return (
      <div className="flex min-h-[50vh] items-center justify-center">
        <EmptyState
          title="Admin access required"
          description="Only org owners and admins can review pending requests."
        />
      </div>
    );
  }

  async function onApprove(id: string) {
    if (!window.confirm("Approve this request?")) return;
    setBusyId(id);
    try {
      await review.mutateAsync({ approvalId: id, decision: "approved" });
      await markRelatedRead(id);
    } finally {
      setBusyId(null);
    }
  }

  async function onReject(id: string) {
    const reason = window.prompt("Reason for rejection (required)") || "";
    if (!reason.trim()) return;
    setBusyId(id);
    try {
      await review.mutateAsync({
        approvalId: id,
        decision: "rejected",
        reason: reason.trim(),
      });
      await markRelatedRead(id);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <Link href={`/series/${seriesId}?tab=overview`} className="text-sm text-primary">
          ← Overview
        </Link>
        <h1 className="text-2xl font-bold">Pending approvals</h1>
      </div>
      {clubPending.length > 0 ? (
        <div className="space-y-3">
          <h2 className="font-semibold">Team review — player registrations</h2>
          <p className="text-sm text-muted-foreground">
            Approve or reject with a reason. Approved requests go to organization admins for a final decision.
          </p>
          {clubPending.map((a) => {
            const name =
              (typeof a.metadata.displayName === "string" && a.metadata.displayName) ||
              a.requestedBy ||
              "Someone";
            const busy = busyId === a.id;
            return (
              <Card key={`club-${a.id}`} className="space-y-3 p-4">
                <p className="font-bold">{name}</p>
                <div className="flex flex-wrap gap-2">
                  {registrationIdOf(a) ? (
                    <Button variant="outline" disabled={identity.isPending} onClick={() => onViewDocs(a)}>
                      View documents
                    </Button>
                  ) : null}
                  <Button
                    disabled={busy}
                    onClick={async () => {
                      if (!window.confirm("Approve this registration for organization review?")) return;
                      setBusyId(a.id);
                      try {
                        await clubReview.mutateAsync({ approvalId: a.id, decision: "approved" });
                      } finally {
                        setBusyId(null);
                      }
                    }}
                  >
                    {busy ? "…" : "Approve for org review"}
                  </Button>
                  <Button
                    variant="outline"
                    disabled={busy}
                    onClick={async () => {
                      const reason = window.prompt("Reason for rejection (required)") || "";
                      if (!reason.trim()) return;
                      setBusyId(a.id);
                      try {
                        await clubReview.mutateAsync({
                          approvalId: a.id,
                          decision: "rejected",
                          reason: reason.trim(),
                        });
                      } finally {
                        setBusyId(null);
                      }
                    }}
                  >
                    Reject
                  </Button>
                </div>
              </Card>
            );
          })}
        </div>
      ) : null}
      {isOrgReviewer && types.length > 0 ? (
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => setFilter(null)}
            className={`rounded-full border px-3 py-1 text-sm ${filter == null ? "border-primary bg-[color:var(--accent-soft)]" : "border-border"}`}
          >
            All ({items.length})
          </button>
          {types.map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setFilter(t)}
              className={`rounded-full border px-3 py-1 text-sm ${filter === t ? "border-primary bg-[color:var(--accent-soft)]" : "border-border"}`}
            >
              {typeLabel(t)} ({items.filter((i) => i.targetType === t).length})
            </button>
          ))}
        </div>
      ) : null}
      {isOrgReviewer && items.length === 0 && clubPending.length === 0 ? (
        <div className="flex min-h-[40vh] items-center justify-center">
          <EmptyState title="All caught up" description="There are no pending approvals." />
        </div>
      ) : filtered.length === 0 ? (
        <div className="flex min-h-[40vh] items-center justify-center">
          <EmptyState title="No requests in this filter" description="Try another type." />
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((a) => {
            const name =
              (typeof a.metadata.displayName === "string" && a.metadata.displayName) ||
              (typeof a.metadata.name === "string" && a.metadata.name) ||
              a.requestedBy ||
              "Someone";
            const teamA = typeof a.metadata.clubAName === "string" ? a.metadata.clubAName : "";
            const teamB = typeof a.metadata.clubBName === "string" ? a.metadata.clubBName : "";
            const when =
              typeof a.metadata.requestedAt === "string"
                ? a.metadata.requestedAt
                : "";
            const busy = busyId === a.id;
            return (
              <Card key={a.id} className="space-y-3 p-4">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="rounded-full bg-[color:var(--accent-soft)] px-2 py-0.5 text-xs font-semibold">
                    {typeLabel(a.targetType)}
                  </span>
                  <p className="font-bold">{name}</p>
                </div>
                {(teamA || teamB) && (
                  <p className="text-sm text-muted-foreground">
                    {[teamA, teamB].filter(Boolean).join(" vs ")}
                  </p>
                )}
                {when ? (
                  <p className="text-xs text-muted-foreground">{when}</p>
                ) : null}
                <div className="flex flex-wrap gap-2">
                  {registrationIdOf(a) ? (
                    <Button variant="outline" disabled={identity.isPending} onClick={() => onViewDocs(a)}>
                      View documents
                    </Button>
                  ) : null}
                  {isOrgReviewer ? (
                    <>
                      <Button disabled={busy} onClick={() => onApprove(a.id)}>
                        {busy ? "…" : "Approve"}
                      </Button>
                      <Button
                        variant="outline"
                        disabled={busy}
                        onClick={() => onReject(a.id)}
                      >
                        Reject
                      </Button>
                    </>
                  ) : null}
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
