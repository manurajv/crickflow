"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { useSeriesAnnouncements } from "@/features/series/hooks";
import { usePathParam } from "@/lib/use-path-param";

export function SeriesAnnouncementsPage() {
  const seriesId = usePathParam("seriesId", 1);
  const { data, isLoading } = useSeriesAnnouncements(seriesId || "");
  if (!seriesId || isLoading) return <p>Loading…</p>;
  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <Link href={`/series/${seriesId}?tab=overview`} className="text-sm text-primary">
          ← Overview
        </Link>
        <h1 className="text-2xl font-bold">Announcements</h1>
      </div>
      {!data?.length ? (
        <EmptyState title="No announcements yet" />
      ) : (
        data.map((a) => (
          <Card key={a.id} className="space-y-2 p-4">
            <p className="font-bold">{a.title}</p>
            <p className="text-sm whitespace-pre-wrap">{a.body}</p>
            <p className="text-xs text-muted-foreground">
              {a.createdByName || "Organizer"}
              {a.createdAt ? ` · ${new Date(a.createdAt).toLocaleString()}` : ""}
            </p>
          </Card>
        ))
      )}
    </div>
  );
}
