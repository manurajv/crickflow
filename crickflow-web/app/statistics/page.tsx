"use client";

import { useEffect, useMemo, useState } from "react";
import { AppLink as Link } from "@/components/shared/app-link";
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Card } from "@/components/ui/card";
import { PageHeader, LoadingPage } from "@/components/shared/page-shell";
import { listMatches, listPlayers, listTeams } from "@/repositories";
import type { Player } from "@/types/models";

export default function StatisticsPage() {
  const [players, setPlayers] = useState<Player[] | null>(null);
  const [totals, setTotals] = useState<{
    teams: number;
    matches: number;
  } | null>(null);

  useEffect(() => {
    Promise.all([listPlayers(200), listTeams(80), listMatches({ take: 80 })])
      .then(([nextPlayers, teams, matches]) => {
        setPlayers(nextPlayers);
        setTotals({ teams: teams.length, matches: matches.length });
      })
      .catch(() => {
        setPlayers([]);
        setTotals({ teams: 0, matches: 0 });
      });
  }, []);

  const batting = useMemo(
    () =>
      [...(players ?? [])]
        .sort((a, b) => b.stats.runs - a.stats.runs)
        .slice(0, 8)
        .map((player) => ({ name: player.name.split(" ")[0] || player.name, runs: player.stats.runs })),
    [players],
  );
  const bowling = useMemo(
    () =>
      [...(players ?? [])]
        .sort((a, b) => b.stats.wickets - a.stats.wickets)
        .slice(0, 8)
        .map((player) => ({ name: player.name.split(" ")[0] || player.name, wickets: player.stats.wickets })),
    [players],
  );

  return (
    <div>
      <PageHeader
        title="Statistics"
        eyebrow="Performance data"
        description={
          <>
            Snapshot of public player and match docs. Full leaderboards live on{" "}
            <Link className="font-semibold text-primary hover:underline" href="/rankings">
              Rankings
            </Link>
            .
          </>
        }
      />
      {players === null || totals === null ? (
        <LoadingPage title="Loading statistics" />
      ) : (
        <>
          <div className="mt-6 grid gap-4 md:grid-cols-4">
            <Card className="border-l-4 border-l-primary p-5 shadow-sm">
              <p className="text-sm text-muted-foreground">Players</p>
              <p className="text-3xl font-bold">{players.length}</p>
            </Card>
            <Card className="border-l-4 border-l-primary p-5 shadow-sm">
              <p className="text-sm text-muted-foreground">Teams</p>
              <p className="text-3xl font-bold">{totals.teams}</p>
            </Card>
            <Card className="border-l-4 border-l-primary p-5 shadow-sm">
              <p className="text-sm text-muted-foreground">Runs (sample)</p>
              <p className="text-3xl font-bold">{players.reduce((sum, p) => sum + p.stats.runs, 0)}</p>
            </Card>
            <Card className="border-l-4 border-l-primary p-5 shadow-sm">
              <p className="text-sm text-muted-foreground">Wickets (sample)</p>
              <p className="text-3xl font-bold">{players.reduce((sum, p) => sum + p.stats.wickets, 0)}</p>
            </Card>
          </div>
          <div className="mt-8 grid gap-6 lg:grid-cols-2">
            <Card className="border-l-4 border-l-primary p-5 shadow-sm">
              <h2 className="mb-4 font-semibold">Top run-scorers</h2>
              <div className="h-72">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={batting}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="runs" fill="#1E88E5" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </Card>
            <Card className="border-l-4 border-l-primary p-5 shadow-sm">
              <h2 className="mb-4 font-semibold">Top wicket-takers</h2>
              <div className="h-72">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={bowling}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="wickets" fill="#43A047" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </Card>
          </div>
          <p className="mt-6 text-sm text-muted-foreground">{totals.matches} recent matches in this snapshot.</p>
        </>
      )}
    </div>
  );
}
