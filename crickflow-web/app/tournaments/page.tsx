"use client";

import { useEffect, useMemo, useState } from "react";
import { EntityCard } from "@/components/shared/cards";
import { PageHeader, LoadingGrid } from "@/components/shared/page-shell";
import { EmptyState } from "@/components/shared/states";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { locationLabel } from "@/lib/cricket/format";
import { searchHaystack } from "@/lib/utils";
import { listTournaments } from "@/repositories";
import { CreateTournamentForm } from "@/features/tournaments/create-tournament-form";
import { useAuth } from "@/features/auth/auth-provider";
import type { Tournament } from "@/types/models";

export default function TournamentsPage() {
  const { user } = useAuth();
  const [tournaments, setTournaments] = useState<Tournament[] | null>(null);
  const [query, setQuery] = useState("");
  const [take, setTake] = useState(40);
  const [showCreate, setShowCreate] = useState(false);
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
      <PageHeader
        title="Tournaments"
        eyebrow="Leagues & cups"
        description="Follow tournaments, fixtures, and standings across local and regional cricket."
      />
      {user && (
        <div className="mt-4">
          {showCreate ? (
            <CreateTournamentForm onClose={() => { setShowCreate(false); listTournaments(take).then(setTournaments).catch(() => setTournaments([])); }} />
          ) : (
            <Button onClick={() => setShowCreate(true)} className="w-full sm:w-auto">
              Create a tournament
            </Button>
          )}
        </div>
      )}
      <Input className="mt-4 max-w-md" placeholder="Search tournaments" value={query} onChange={(e) => setQuery(e.target.value)} />
      {tournaments === null ? (
        <LoadingGrid count={6} className="mt-8 md:grid-cols-2" />
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
