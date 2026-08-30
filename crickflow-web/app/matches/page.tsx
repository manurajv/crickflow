"use client";

import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { MatchCard } from "@/components/shared/cards";
import { FilterChip } from "@/components/shared/filter-chip";
import { PageHeader, LoadingGrid } from "@/components/shared/page-shell";
import { EmptyState } from "@/components/shared/states";
import { Input } from "@/components/ui/input";
import { searchHaystack } from "@/lib/utils";import { listMatches, watchLiveMatches } from "@/repositories";
import type { Match } from "@/types/models";
import type { MatchStatus } from "@/types/enums";

function MatchesList() {
  const searchParams = useSearchParams();
  const status = searchParams.get("status");
  const [matches, setMatches] = useState<Match[] | null>(null);
  const [query, setQuery] = useState("");
  const [take, setTake] = useState(40);

  useEffect(() => {
    if (status === "live") {
      return watchLiveMatches(setMatches, take);
    }
    const filter =
      status === "upcoming"
        ? (["scheduled", "tossCompleted"] as MatchStatus[])
        : status === "completed"
          ? ("completed" as MatchStatus)
          : undefined;
    listMatches({ status: filter, take }).then(setMatches).catch(() => setMatches([]));
  }, [status, take]);

  const visible = useMemo(() => {
    const list = matches ?? [];
    if (!query.trim()) return list;
    return list
      .map((match) => ({
        match,
        score: searchHaystack(query, [match.title, match.teamAName, match.teamBName, match.venue, match.roundName]),
      }))
      .filter((row) => row.score > 0)
      .sort((a, b) => b.score - a.score)
      .map((row) => row.match);
  }, [matches, query]);

  const current = status ?? "all";

  return (
    <div>
      <PageHeader
        title="Matches"
        eyebrow="Fixtures & results"
        description="Live scores, upcoming fixtures, and recent results from across CrickFlow."
      />
      <div className="flex flex-wrap gap-2">
        <FilterChip href="/matches" active={current === "all"}>
          All
        </FilterChip>
        <FilterChip href="/matches?status=live" active={current === "live"} live>
          Live
        </FilterChip>
        <FilterChip href="/matches?status=upcoming" active={current === "upcoming"}>
          Upcoming
        </FilterChip>
        <FilterChip href="/matches?status=completed" active={current === "completed"}>
          Recent
        </FilterChip>
      </div>
      <Input className="mt-4 max-w-md" placeholder="Search matches" value={query} onChange={(e) => setQuery(e.target.value)} />
      {matches === null ? (
        <LoadingGrid className="mt-8" />
      ) : visible.length === 0 ? (
        <div className="mt-8">
          <EmptyState title="No matches found" />
        </div>
      ) : (
        <div className="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {visible.map((match) => (
            <MatchCard key={match.id} match={match} />
          ))}
        </div>
      )}
      {!query.trim() && matches && matches.length >= take ? (
        <Button className="mt-6" variant="outline" onClick={() => setTake((n) => n + 40)}>
          Load more
        </Button>
      ) : null}
    </div>
  );
}

export default function MatchesPage() {
  return (
    <Suspense fallback={<LoadingGrid className="mt-8" />}>
      <MatchesList />
    </Suspense>
  );
}
