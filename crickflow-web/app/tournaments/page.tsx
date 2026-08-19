"use client";

import { useEffect, useMemo, useState } from "react";
import { EntityCard } from "@/components/shared/cards";
import { EmptyState } from "@/components/shared/states";
import { GetTheApp } from "@/components/shared/get-the-app";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { locationLabel } from "@/lib/cricket/format";
import { searchHaystack } from "@/lib/utils";
import { listTournaments } from "@/repositories";
import type { Tournament } from "@/types/models";

export default function TournamentsPage() {
  const [tournaments, setTournaments] = useState<Tournament[] | null>(null);
  const [query, setQuery] = useState("");
  const [take, setTake] = useState(40);
  useEffect(() => {
    listTournaments(take).then(setTournaments).catch(() => setTournaments([]));
  }, [take]);
  const visible = useMemo(() => {
    const list = tournaments ?? [];
    if (!query.trim()) return list;
    return list
      .map((item) => ({
        item,
        score: searchHaystack(query, [item.name, locationLabel(item.location), item.format, item.status]),
      }))
      .filter((row) => row.score > 0)
      .sort((a, b) => b.score - a.score)
      .map((row) => row.item);
  }, [tournaments, query]);
  return (
    <div>
      <h1 className="text-3xl font-bold">Tournaments</h1>
      <div className="mt-4">
        <GetTheApp title="Create a tournament in the CrickFlow app" />
      </div>
      <Input className="mt-4 max-w-md" placeholder="Search tournaments" value={query} onChange={(e) => setQuery(e.target.value)} />
      {tournaments === null ? (
        <p className="mt-8">Loading tournaments…</p>
      ) : visible.length === 0 ? (
        <div className="mt-8">
          <EmptyState title="No tournaments yet" />
        </div>
      ) : (
        <div className="mt-6 grid gap-4 md:grid-cols-2">
          {visible.map((t) => (
            <EntityCard
              key={t.id}
              href={`/tournaments/${t.id}`}
              title={t.name}
              subtitle={locationLabel(t.location)}
              image={t.bannerUrl}
              meta={`${t.format} · ${t.status}`}
            />
          ))}
        </div>
      )}
      {!query.trim() && tournaments && tournaments.length >= take ? (
        <Button className="mt-6" variant="outline" onClick={() => setTake((n) => n + 40)}>
          Load more
        </Button>
      ) : null}
    </div>
  );
}
