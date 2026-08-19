"use client";

import { useEffect, useMemo, useState } from "react";
import { EntityCard } from "@/components/shared/cards";
import { EmptyState } from "@/components/shared/states";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { locationLabel } from "@/lib/cricket/format";
import { searchScore } from "@/lib/utils";
import { listPlayers } from "@/repositories";
import type { Player } from "@/types/models";

export default function PlayersPage() {
  const [players, setPlayers] = useState<Player[] | null>(null);
  const [query, setQuery] = useState("");
  const [take, setTake] = useState(60);
  useEffect(() => {
    listPlayers(take).then(setPlayers).catch(() => setPlayers([]));
  }, [take]);
  const visible = useMemo(() => {
    const list = players ?? [];
    if (!query.trim()) return list;
    return [...list]
      .map((player) => ({
        player,
        score: Math.max(
          searchScore(player.name, query),
          searchScore(player.playerId ?? "", query),
          searchScore(locationLabel(player.location), query),
        ),
      }))
      .filter((row) => row.score > 0)
      .sort((a, b) => b.score - a.score)
      .map((row) => row.player);
  }, [players, query]);
  return (
    <div>
      <h1 className="text-3xl font-bold">Players</h1>
      <Input className="mt-4 max-w-md" placeholder="Search players" value={query} onChange={(e) => setQuery(e.target.value)} />
      {players === null ? (
        <p className="mt-8">Loading players…</p>
      ) : visible.length === 0 ? (
        <div className="mt-8">
          <EmptyState title="No players yet" />
        </div>
      ) : (
        <div className="mt-6 grid gap-3 md:grid-cols-2">
          {visible.map((p) => (
            <EntityCard
              key={p.id}
              href={`/players/${p.id}`}
              title={p.name}
              subtitle={p.playerId || p.role}
              image={p.photoUrl}
              meta={locationLabel(p.location)}
            />
          ))}
        </div>
      )}
      {!query.trim() && players && players.length >= take ? (
        <Button className="mt-6" variant="outline" onClick={() => setTake((n) => n + 40)}>
          Load more
        </Button>
      ) : null}
    </div>
  );
}
