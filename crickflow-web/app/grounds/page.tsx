"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { EmptyState } from "@/components/shared/states";
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
      <h1 className="text-3xl font-bold">Grounds</h1>
      <p className="mt-2 text-sm text-muted-foreground">
        Public venues derived from matches and tournaments. The admin ground registry is not publicly readable.
      </p>
      <Input className="mt-4 max-w-md" placeholder="Search grounds" value={query} onChange={(e) => setQuery(e.target.value)} />
      {grounds === null ? (
        <p className="mt-8">Loading grounds…</p>
      ) : visible.length === 0 ? (
        <div className="mt-8">
          <EmptyState title="No grounds listed yet" />
        </div>
      ) : (
        <div className="mt-6 grid gap-3 md:grid-cols-2">
          {visible.map((g) => (
            <Link key={g.id} href={`/grounds/${g.id}`} className="rounded-2xl border border-border bg-card p-5">
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
