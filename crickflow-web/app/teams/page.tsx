"use client";

import { useEffect, useMemo, useState } from "react";
import { EntityCard } from "@/components/shared/cards";
import { EmptyState } from "@/components/shared/states";
import { GetTheApp } from "@/components/shared/get-the-app";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { locationLabel } from "@/lib/cricket/format";
import { searchScore } from "@/lib/utils";
import { listTeams } from "@/repositories";
import type { Team } from "@/types/models";

export default function TeamsPage() {
  const [teams, setTeams] = useState<Team[] | null>(null);
  const [query, setQuery] = useState("");
  const [take, setTake] = useState(40);
  useEffect(() => {
    listTeams(take).then(setTeams).catch(() => setTeams([]));
  }, [take]);
  const visible = useMemo(() => {
    const list = teams ?? [];
    if (!query.trim()) return list;
    return [...list]
      .map((team) => ({
        team,
        score: Math.max(searchScore(team.name, query), searchScore(locationLabel(team.location), query)),
      }))
      .filter((row) => row.score > 0)
      .sort((a, b) => b.score - a.score)
      .map((row) => row.team);
  }, [teams, query]);
  return (
    <div>
      <h1 className="text-3xl font-bold">Teams</h1>
      <div className="mt-4">
        <GetTheApp title="Create a team in the CrickFlow app" />
      </div>
      <Input className="mt-4 max-w-md" placeholder="Search teams" value={query} onChange={(e) => setQuery(e.target.value)} />
      {teams === null ? (
        <p className="mt-8">Loading teams…</p>
      ) : visible.length === 0 ? (
        <div className="mt-8">
          <EmptyState title="No teams yet" />
        </div>
      ) : (
        <div className="mt-6 grid gap-3 md:grid-cols-2">
          {visible.map((t) => (
            <EntityCard
              key={t.id}
              href={`/teams/${t.id}`}
              title={t.name}
              subtitle={locationLabel(t.location)}
              image={t.logoUrl}
              meta={`${t.stats.matchesWon} wins`}
            />
          ))}
        </div>
      )}
      {!query.trim() && teams && teams.length >= take ? (
        <Button className="mt-6" variant="outline" onClick={() => setTake((n) => n + 40)}>
          Load more
        </Button>
      ) : null}
    </div>
  );
}
