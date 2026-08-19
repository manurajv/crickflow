"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { MatchCard } from "@/components/shared/cards";
import { EmptyState } from "@/components/shared/states";
import { Input } from "@/components/ui/input";
import { cn, searchHaystack } from "@/lib/utils";
import { listMatches, watchLiveMatches } from "@/repositories";
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
      <h1 className="text-3xl font-bold">Matches</h1>
      <div className="mt-4 flex flex-wrap gap-2 text-sm">
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
        <p className="mt-8">Loading matches…</p>
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

function FilterChip({
  href,
  active,
  live,
  children,
}: {
  href: string;
  active: boolean;
  live?: boolean;
  children: string;
}) {
  return (
    <Link
      className={cn(
        "rounded-full px-3 py-1",
        active && live && "bg-live text-white",
        active && !live && "bg-primary text-white",
        !active && "bg-muted",
      )}
      href={href}
    >
      {children}
    </Link>
  );
}

export default function MatchesPage() {
  return (
    <Suspense fallback={<p>Loading matches…</p>}>
      <MatchesList />
    </Suspense>
  );
}
