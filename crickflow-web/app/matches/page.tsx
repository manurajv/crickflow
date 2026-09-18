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
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [take, setTake] = useState(40);

  useEffect(() => {
    setError(null);
    if (status === "live") {
      return watchLiveMatches(setMatches, take);
    }
    const filter =
      status === "upcoming"
        ? (["scheduled", "tossCompleted"] as MatchStatus[])
        : status === "completed"
          ? ("completed" as MatchStatus)
          : undefined;
    listMatches({ status: filter, take })
      .then((data) => {
        setMatches(data);
        setError(null);
      })
      .catch((err) => {
        console.error("Match list error:", err);
        setError(err instanceof Error ? err.message : "Failed to load matches");
        setMatches([]);
      });
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
      ) : error ? (
        <div className="mt-8">
          <EmptyState
            title="Failed to load matches"
            description={error}
            action={
              <button
                onClick={() => window.location.reload()}
                className="rounded-lg bg-primary px-6 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90"
              >
                Retry
              </button>
            }
          />
        </div>
      ) : visible.length === 0 ? (
        <div className="mt-8">
          <EmptyState title="No matches found" description={query.trim() ? "Try a different search term" : "No matches available yet"} />
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
