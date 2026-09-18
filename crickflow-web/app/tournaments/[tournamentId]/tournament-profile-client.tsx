"use client";

import { useCallback } from "react";
import { AppLink as Link } from "@/components/shared/app-link";
import { MatchCard } from "@/components/shared/cards";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { JsonLd, sportsTeamLd } from "@/components/shared/json-ld";
import { ClientEntity } from "@/components/shared/client-entity";
import { locationLabel } from "@/lib/cricket/format";
import { slugify } from "@/lib/utils";
import { usePathParam } from "@/lib/use-path-param";
import { getTournament, listMatches } from "@/repositories";
import type { Match, Tournament } from "@/types/models";

export function TournamentProfileClient() {
  const tournamentId = usePathParam("tournamentId", 1);
  const load = useCallback(async () => {
    const tournament = await getTournament(tournamentId);
    if (!tournament) return null;
    const matches = (await listMatches({ take: 80 })).filter(
      (m) => m.tournamentId === tournament.id || tournament.matchIds.includes(m.id),
    );
    return { tournament, matches };
  }, [tournamentId]);
  if (!tournamentId) return <p>Loading…</p>;
  return (
    <ClientEntity<{ tournament: Tournament; matches: Match[] }> load={load}>
      {({ tournament, matches }) => <TournamentView tournament={tournament} matches={matches} />}
    </ClientEntity>
  );
}

function TournamentView({ tournament, matches }: { tournament: Tournament; matches: Match[] }) {
  const standings = [...tournament.pointsTable].sort(
    (a, b) => a.position - b.position || b.points - a.points,
  );
  return (
    <div className="space-y-8">
      <JsonLd
        data={sportsTeamLd({
          name: tournament.name,
          path: `/tournaments/${tournament.id}`,
          image: tournament.bannerUrl,
          location: locationLabel(tournament.location),
        })}
      />
      <header className="rounded-3xl bg-scoreboard p-8 text-white">
        <Badge>{tournament.status}</Badge>
        <h1 className="mt-3 text-4xl font-black">{tournament.name}</h1>
        <p className="mt-2 text-white/75">
          {[tournament.organizerName, locationLabel(tournament.location), tournament.format]
            .filter(Boolean)
            .join(" · ")}
        </p>
        <div className="mt-4 flex gap-2">
          <Button variant="gold" asChild>
            <Link href="/matches">Fixtures</Link>
          </Button>
        </div>
      </header>
      <section>
        <h2 className="mb-3 text-xl font-bold">Standings</h2>
        {standings.length === 0 ? (
          <EmptyState title="Standings not published" />
        ) : (
          <Card className="overflow-x-auto p-0">
            <table className="w-full text-sm">
              <thead className="bg-muted/50 text-left">
                <tr>
                  <th className="p-3">#</th>
                  <th>Team</th>
                  <th>P</th>
                  <th>W</th>
                  <th>L</th>
                  <th>Pts</th>
                  <th>NRR</th>
                </tr>
              </thead>
              <tbody>
                {standings.map((row) => (
                  <tr key={row.teamId} className="border-t border-border">
                    <td className="p-3">{row.position || "—"}</td>
                    <td>
                      <Link href={`/teams/${row.teamId}`} className="text-primary">
                        {row.teamName}
                      </Link>
                    </td>
                    <td>{row.played}</td>
                    <td>{row.won}</td>
                    <td>{row.lost}</td>
                    <td>{row.points}</td>
                    <td>{row.netRunRate.toFixed(3)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Card>
        )}
      </section>
      <section>
        <h2 className="mb-3 text-xl font-bold">Knockout bracket</h2>
        {tournament.bracketRounds.length === 0 ? (
          <EmptyState title="No bracket published" />
        ) : (
          <div className="flex gap-4 overflow-x-auto pb-2">
            {tournament.bracketRounds.map((round, i) => (
              <div key={i} className="min-w-56 space-y-3">
                <p className="text-sm font-semibold">Round {i + 1}</p>
                {round.map((slot, j) => (
                  <Card key={slot.matchId ?? `${i}-${j}`} className="p-3 text-sm">
                    <p>{slot.teamAName || "TBD"}</p>
                    <p className="text-muted-foreground">vs</p>
                    <p>{slot.teamBName || "TBD"}</p>
                    {slot.winnerTeamName ? (
                      <p className="mt-2 text-xs text-cricket">Winner: {slot.winnerTeamName}</p>
                    ) : null}
                    {slot.matchId ? (
                      <Link className="mt-2 inline-block text-xs text-primary" href={`/matches/${slot.matchId}`}>
                        Match centre
                      </Link>
                    ) : null}
                  </Card>
                ))}
              </div>
            ))}
          </div>
        )}
      </section>
      <section>
        <h2 className="mb-3 text-xl font-bold">Grounds</h2>
        {tournament.grounds.length ? (
          <div className="flex flex-wrap gap-2">
            {tournament.grounds.map((name) => (
              <Link
                key={name}
                href={`/grounds/${slugify(name)}`}
                className="rounded-full bg-muted px-3 py-1 text-sm hover:bg-primary hover:text-white"
              >
                {name}
              </Link>
            ))}
          </div>
        ) : (
          <p>{locationLabel(tournament.location) || "TBC"}</p>
        )}
      </section>
      <section>
        <h2 className="mb-3 text-xl font-bold">Matches</h2>
        <div className="grid gap-4 md:grid-cols-2">
          {matches.map((m) => (
            <MatchCard key={m.id} match={m} />
          ))}
        </div>
      </section>
    </div>
  );
}
