"use client";

import { useEffect, useState } from "react";
import { EmptyState } from "@/components/shared/states";
import { MatchCentre } from "@/features/matches/match-centre";
import { usePathParam } from "@/lib/use-path-param";
import { getMatch, listBallEvents } from "@/repositories";
import type { BallEvent, Match } from "@/types/models";

type Tab =
  | "scorecard"
  | "commentary"
  | "stats"
  | "wagon"
  | "manhattan"
  | "partnerships"
  | "players"
  | "highlights";

export function MatchCentreLoader({
  initialTab,
  watchMode = false,
}: {
  initialTab?: Tab;
  watchMode?: boolean;
}) {
  const matchId = usePathParam("matchId", 1);
  const [match, setMatch] = useState<Match | null>(null);
  const [events, setEvents] = useState<BallEvent[]>([]);
  const [missing, setMissing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!matchId) return;
    let cancelled = false;
    Promise.all([getMatch(matchId), listBallEvents(matchId, 80)])
      .then(([nextMatch, nextEvents]) => {
        if (cancelled) return;
        if (!nextMatch) {
          setMissing(true);
          return;
        }
        setMatch(nextMatch);
        setEvents(nextEvents);
        setError(null);
      })
      .catch((err) => {
        if (!cancelled) {
          console.error("Match load error:", err);
          setError(err instanceof Error ? err.message : "Failed to load match");
          setMissing(true);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [matchId]);

  if (!matchId) return <EmptyState title="Match not found" description="Invalid match ID" />;
  if (error) {
    return (
      <EmptyState
        title="Failed to load match"
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
    );
  }
  if (missing) return <EmptyState title="Match not found" description="This match does not exist or has been removed" />;
  if (!match) return <p>Loading match…</p>;
  return (
    <MatchCentre
      initialMatch={match}
      initialEvents={events}
      initialTab={initialTab}
      watchMode={watchMode}
    />
  );
}
