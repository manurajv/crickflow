"use client";

import { useCallback } from "react";
import { useQuery } from "@tanstack/react-query";
import { JsonLd, personLd } from "@/components/shared/json-ld";
import { ClientEntity } from "@/components/shared/client-entity";
import { LoadingPage } from "@/components/shared/page-shell";
import { PlayerProfileView, teamsForPlayer } from "@/features/profiles/player-profile-view";
import { useAuth } from "@/features/auth/auth-provider";
import { locationLabel } from "@/lib/cricket/format";
import { matchInvolvesPlayer } from "@/lib/cricket/events";
import { usePathParam } from "@/lib/use-path-param";
import { getPlayer, listMatches, listTeams } from "@/repositories";
import type { Player } from "@/types/models";

export function PlayerProfileClient() {
  const playerId = usePathParam("playerId", 1);
  const load = useCallback(() => getPlayer(playerId), [playerId]);
  if (!playerId) return <LoadingPage title="Loading player" />;
  return (
    <ClientEntity<Player> load={load}>
      {(player) => <PlayerView player={player} />}
    </ClientEntity>
  );
}

function PlayerView({ player }: { player: Player }) {
  const { user } = useAuth();
  const isOwner = Boolean(user?.uid && player.userId && user.uid === player.userId);
  const teamsQuery = useQuery({
    queryKey: ["player-teams", player.id],
    queryFn: () => listTeams(100),
  });
  const matchesQuery = useQuery({
    queryKey: ["player-matches", player.id],
    queryFn: () => listMatches({ take: 100 }),
  });
  const teams = teamsForPlayer(teamsQuery.data, player);
  const recent = (matchesQuery.data ?? [])
    .filter((match) => matchInvolvesPlayer(match, player.id))
    .slice(0, 8);

  return (
    <>
      <JsonLd
        data={personLd({
          name: player.name,
          path: `/players/${player.id}`,
          image: player.photoUrl,
          role: player.role,
        })}
      />
      <PlayerProfileView
        name={player.name}
        photoUrl={player.photoUrl}
        playerId={player.playerId}
        role={player.role}
        battingStyle={player.battingStyle}
        bowlingStyle={player.bowlingStyle}
        locationText={locationLabel(player.location)}
        country={player.country}
        stats={player.stats}
        teams={teams}
        recentMatches={recent}
        isOwner={isOwner}
        viewerUserId={user?.uid}
        profileUserId={player.userId}
        playerDocId={player.id}
        followId={player.userId ?? ""}
        sharePath={`/players/${player.id}`}
        loadingTeams={teamsQuery.isPending}
        loadingMatches={matchesQuery.isPending}
      />
    </>
  );
}
