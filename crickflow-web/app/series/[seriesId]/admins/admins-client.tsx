"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { FormEvent, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import {
  useAddSeriesAdmin,
  useSeriesAdmins,
  useSeriesAuditLogs,
  useSeriesDetail,
  useUpdateSeriesAdminRole,
} from "@/features/series/hooks";
import { seriesAdminTierLabel, type SeriesAdminTier } from "@/lib/cricket/series-admin-tier";
import { seriesAuditActionLabel } from "@/features/series/repository";
import { usePathParam } from "@/lib/use-path-param";
import { loginUrl } from "@/lib/auth/guest-access";

export function SeriesAdminsPage() {
  const seriesId = usePathParam("seriesId", 1);
  const { user } = useAuth();
  const { data, isLoading } = useSeriesDetail(seriesId, user?.uid);
  const admins = useSeriesAdmins(seriesId || "");
  const audit = useSeriesAuditLogs(seriesId || "", Boolean(data?.canViewStaff));
  const addAdmin = useAddSeriesAdmin(seriesId || "");
  const [adminUserId, setAdminUserId] = useState("");
  const [adminRole, setAdminRole] = useState<SeriesAdminTier>("admin");
  const updateRole = useUpdateSeriesAdminRole(seriesId || "");

  if (!seriesId || isLoading) return <p>Loading…</p>;
  if (!user) {
    return (
      <EmptyState
        title="Sign in required"
        action={<Link href={loginUrl(`/series/${seriesId}/admins`, "org_manage")}>Sign in</Link>}
      />
    );
  }
  if (!data?.canViewStaff) return <EmptyState title="Admin access required" />;

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Link href={`/series/${seriesId}?tab=overview`} className="text-sm text-primary">
          ← Overview
        </Link>
        <h1 className="text-2xl font-bold">Admins</h1>
      </div>
      <div className="space-y-2">
        {(admins.data ?? data.admins).map((a) => (
          <Card key={a.id} className="p-4 text-sm">
            <p className="font-semibold">{a.displayName || a.userId}</p>
            <p className="text-muted-foreground">{seriesAdminTierLabel(a.role)}</p>
            {data.isSuperAdmin && a.userId !== data.series.superAdminUserId ? (
              <select
                className="mt-2 rounded-md border border-border bg-background px-2 py-1 text-sm"
                value={a.role === "scorer" || a.role === "viewer" ? a.role : "admin"}
                onChange={(e) =>
                  updateRole.mutate({ userId: a.userId, role: e.target.value as SeriesAdminTier })
                }
              >
                <option value="admin">Admin</option>
                <option value="scorer">Scorer</option>
                <option value="viewer">Viewer</option>
              </select>
            ) : null}
          </Card>
        ))}
      </div>
      {data.isSuperAdmin ? (
        <form
          className="flex flex-wrap gap-2"
          onSubmit={async (e: FormEvent) => {
            e.preventDefault();
            await addAdmin.mutateAsync({ userId: adminUserId.trim(), role: adminRole });
            setAdminUserId("");
          }}
        >
          <input
            className="min-w-[220px] flex-1 rounded-md border border-border bg-background px-3 py-2"
            placeholder="User ID"
            value={adminUserId}
            onChange={(e) => setAdminUserId(e.target.value)}
            required
          />
          <select
            className="rounded-md border border-border bg-background px-3 py-2"
            value={adminRole}
            onChange={(e) => setAdminRole(e.target.value as SeriesAdminTier)}
          >
            <option value="admin">Admin</option>
            <option value="scorer">Scorer</option>
            <option value="viewer">Viewer</option>
          </select>
          <Button type="submit" disabled={addAdmin.isPending}>
            Add admin
          </Button>
        </form>
      ) : null}
      <section>
        <h2 className="mb-2 text-lg font-bold">Audit log</h2>
        {!audit.data?.length ? (
          <p className="text-sm text-muted-foreground">No activity yet</p>
        ) : (
          <ul className="space-y-2 text-sm">
            {audit.data.map((log) => (
              <li key={log.id}>
                {seriesAuditActionLabel(log.action)}
                {log.timestamp ? ` · ${new Date(log.timestamp).toLocaleString()}` : ""}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
