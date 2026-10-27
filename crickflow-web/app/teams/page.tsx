"use client";

import { useEffect, useMemo, useState } from "react";
import { EntityCard } from "@/components/shared/cards";
import { PageHeader, LoadingGrid } from "@/components/shared/page-shell";
import { EmptyState } from "@/components/shared/states";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { locationLabel } from "@/lib/cricket/format";
import { searchScore } from "@/lib/utils";
import { listTeams } from "@/repositories";
import { CreateTeamForm } from "@/features/teams/create-team-form";
import { useAuth } from "@/features/auth/auth-provider";
import type { Team } from "@/types/models";

export default function TeamsPage() {
  const { user } = useAuth();
  const [teams, setTeams] = useState<Team[] | null>(null);
  const [query, setQuery] = useState("");
  const [take, setTake] = useState(40);
  const [showCreate, setShowCreate] = useState(false);
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
      <PageHeader
        title="Teams"
        eyebrow="Clubs & squads"
        description="Browse cricket teams, follow your favourites, and see their match records."
      />
      {user && (
        <div className="mt-4">
          {showCreate ? (
            <CreateTeamForm onClose={() => { setShowCreate(false); listTeams(take).then(setTeams).catch(() => setTeams([])); }} />
          ) : (
            <Button onClick={() => setShowCreate(true)} className="w-full sm:w-auto">
              Create a team
            </Button>
          )}
        </div>
      )}
      <Input className="mt-4 max-w-md" placeholder="Search teams" value={query} onChange={(e) => setQuery(e.target.value)} />
      {teams === null ? (
        <LoadingGrid count={8} className="mt-8 md:grid-cols-2" />
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
