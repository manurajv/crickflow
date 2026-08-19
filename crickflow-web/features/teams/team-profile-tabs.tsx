"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { MatchCard } from "@/components/shared/cards";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import type { Match, Player, Team } from "@/types/models";

const TABS = ["matches", "leaderboard", "stats", "members", "trophies", "profile"] as const;

export function TeamProfileTabs({
  team,
  matches,
  members,
}: {
  team: Team;
  matches: Match[];
  members: Player[];
}) {
  const [tab, setTab] = useState<(typeof TABS)[number]>("matches");
  const batting = useMemo(() => [...members].sort((a, b) => b.stats.runs - a.stats.runs), [members]);
  const bowling = useMemo(() => [...members].sort((a, b) => b.stats.wickets - a.stats.wickets), [members]);
  const fielding = useMemo(() => [...members].sort((a, b) => b.stats.catches - a.stats.catches), [members]);

  return (
    <div>
      <nav className="mb-4 flex flex-wrap gap-2" aria-label="Team profile">
        {TABS.map((item) => (
          <button
            key={item}
            type="button"
            className={`rounded-full px-3 py-1 text-sm capitalize ${tab === item ? "bg-primary text-white" : "bg-muted"}`}
            onClick={() => setTab(item)}
          >
            {item}
          </button>
        ))}
      </nav>
      {tab === "matches" ? (
        matches.length ? (
          <div className="grid gap-4 md:grid-cols-2">
            {matches.map((m) => (
              <MatchCard key={m.id} match={m} />
            ))}
          </div>
        ) : (
          <EmptyState title="No matches yet" />
        )
      ) : null}
      {tab === "leaderboard" ? (
        <div className="grid gap-4 md:grid-cols-3">
          <Leader title="Batting" rows={batting.map((p) => [p.id, p.name, String(p.stats.runs)])} />
          <Leader title="Bowling" rows={bowling.map((p) => [p.id, p.name, String(p.stats.wickets)])} />
          <Leader title="Fielding" rows={fielding.map((p) => [p.id, p.name, String(p.stats.catches)])} />
        </div>
      ) : null}
      {tab === "stats" ? (
        <div className="grid gap-4 md:grid-cols-3">
          <Card className="p-5">
            <p className="text-sm text-muted-foreground">Played</p>
            <p className="text-3xl font-bold">{team.stats.matchesPlayed}</p>
          </Card>
          <Card className="p-5">
            <p className="text-sm text-muted-foreground">Won / Lost / Tied</p>
            <p className="text-3xl font-bold">
              {team.stats.matchesWon}/{team.stats.matchesLost}/{team.stats.matchesTied}
            </p>
          </Card>
          <Card className="p-5">
            <p className="text-sm text-muted-foreground">NRR</p>
            <p className="text-3xl font-bold">{team.stats.netRunRate.toFixed(2)}</p>
          </Card>
        </div>
      ) : null}
      {tab === "members" ? (
        members.length ? (
          <div className="grid gap-2 md:grid-cols-2">
            {members.map((p) => (
              <Link key={p.id} href={`/players/${p.id}`} className="rounded-xl border border-border px-4 py-3">
                {p.name}
              </Link>
            ))}
          </div>
        ) : (
          <EmptyState title="No members listed" />
        )
      ) : null}
      {tab === "trophies" ? (
        <EmptyState
          title="No trophies yet"
          description="Badges earned in scored matches appear here when the mobile app writes them."
        />
      ) : null}
      {tab === "profile" ? (
        <Card className="p-5 text-sm">
          <p>Coach: {team.coachName || "—"}</p>
          <p>Captain ID: {team.captainId || "—"}</p>
          <p>Code: {team.teamCode || "—"}</p>
        </Card>
      ) : null}
    </div>
  );
}

function Leader({ title, rows }: { title: string; rows: string[][] }) {
  return (
    <Card className="p-4">
      <h3 className="font-semibold">{title}</h3>
      <ol className="mt-2 space-y-1 text-sm">
        {rows.slice(0, 8).map(([id, name, value], i) => (
          <li key={id} className="flex justify-between">
            <Link href={`/players/${id}`}>
              {i + 1}. {name}
            </Link>
            <span>{value}</span>
          </li>
        ))}
      </ol>
    </Card>
  );
}
