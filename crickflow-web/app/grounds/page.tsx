"use client";

import { useEffect, useMemo, useState } from "react";
import { AppLink as Link } from "@/components/shared/app-link";
import { EmptyState } from "@/components/shared/states";
import { PageHeader, LoadingGrid } from "@/components/shared/page-shell";
import { Input } from "@/components/ui/input";
import { locationLabel } from "@/lib/cricket/format";
import { searchHaystack } from "@/lib/utils";
import { listDerivedGrounds } from "@/repositories";
import type { DerivedGround } from "@/types/models";

export default function GroundsPage() {
  const [grounds, setGrounds] = useState<DerivedGround[] | null>(null);
  const [query, setQuery] = useState("");
  useEffect(() => {
    listDerivedGrounds().then(setGrounds).catch(() => setGrounds([]));
  }, []);
  const visible = useMemo(() => {
    const list = grounds ?? [];
    if (!query.trim()) return list;
    return list
      .map((item) => ({
        item,
        score: searchHaystack(query, [item.name, locationLabel(item.location)]),
      }))
      .filter((row) => row.score > 0)
      .sort((a, b) => b.score - a.score)
      .map((row) => row.item);
  }, [grounds, query]);
  return (
    <div>
      <PageHeader
        title="Grounds"
        eyebrow="Venues"
        description="Public venues derived from matches and tournaments across the CrickFlow network."
      />
      <Input className="mt-4 max-w-md" placeholder="Search grounds" value={query} onChange={(e) => setQuery(e.target.value)} />
      {grounds === null ? (
        <LoadingGrid count={6} className="mt-8 md:grid-cols-2" />
      ) : visible.length === 0 ? (
        <div className="mt-8">
          <EmptyState title="No grounds listed yet" />
        </div>
      ) : (
        <div className="mt-6 grid gap-3 md:grid-cols-2">
          {visible.map((g) => (
            <Link key={g.id} href={`/grounds/${g.id}`} className="rounded-2xl border border-border bg-card p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-md">
              <h2 className="font-semibold">{g.name}</h2>
              <p className="text-sm text-muted-foreground">{locationLabel(g.location)}</p>
              <p className="mt-2 text-xs">
                {g.matchCount} matches · {g.tournamentCount} tournaments
              </p>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
