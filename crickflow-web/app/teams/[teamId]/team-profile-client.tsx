"use client";

import { useCallback } from "react";
import { Badge } from "@/components/ui/badge";
import { FollowShare } from "@/features/profiles/follow-share";
import { TeamProfileTabs } from "@/features/teams/team-profile-tabs";
import { JsonLd, sportsTeamLd } from "@/components/shared/json-ld";
import { ClientEntity } from "@/components/shared/client-entity";
import { locationLabel } from "@/lib/cricket/format";
import { firstGrapheme } from "@/lib/utils";
import { usePathParam } from "@/lib/use-path-param";
import { getTeam, listMatches, listPlayers } from "@/repositories";
import type { Match, Player, Team } from "@/types/models";

export function TeamProfileClient() {
  const teamId = usePathParam("teamId", 1);
  const load = useCallback(async () => {
    const team = await getTeam(teamId);
    if (!team) return null;
    const [matches, players] = await Promise.all([listMatches({ take: 80 }), listPlayers(80)]);
    return {
      team,
      matches: matches.filter((m) => m.teamAId === team.id || m.teamBId === team.id),
      members: players.filter((p) => team.playerIds.includes(p.id) || p.teamId === team.id),
    };
  }, [teamId]);
  if (!teamId) return <p>Loading…</p>;
  return (
    <ClientEntity<{ team: Team; matches: Match[]; members: Player[] }> load={load}>
      {({ team, matches, members }) => (
        <div className="space-y-8">
          <JsonLd
            data={sportsTeamLd({
              name: team.name,
              path: `/teams/${team.id}`,
              image: team.logoUrl,
              location: locationLabel(team.location),
            })}
          />
          <header className="flex flex-col gap-4 rounded-3xl border border-border bg-card p-6 md:flex-row md:items-center">
            <div className="flex h-24 w-24 items-center justify-center overflow-hidden rounded-2xl bg-muted text-3xl font-bold">
              {team.logoUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={team.logoUrl} alt="" className="h-full w-full object-cover" />
              ) : (
                firstGrapheme(team.name)
              )}
            </div>
            <div className="flex-1">
              <h1 className="text-3xl font-bold">{team.name}</h1>
              <p className="text-muted-foreground">{locationLabel(team.location)}</p>
              <div className="mt-2 flex gap-2">
                <Badge>{team.stats.matchesPlayed} matches</Badge>
                <Badge variant="green">{team.stats.matchesWon} wins</Badge>
              </div>
            </div>
            <FollowShare kind="team" id={team.id} title={team.name} path={`/teams/${team.id}`} />
          </header>
          <TeamProfileTabs team={team} matches={matches} members={members} />
        </div>
      )}
    </ClientEntity>
  );
}
