"use client";

import { useCallback } from "react";
import { useQuery } from "@tanstack/react-query";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { toast } from "sonner";
import { battingAverage, locationLabel, strikeRate } from "@/lib/cricket/format";
import { matchInvolvesPlayer } from "@/lib/cricket/events";
import { getPlayer, listMatches } from "@/repositories";
import { FollowShare } from "@/features/profiles/follow-share";
import { StartChatButton } from "@/features/chat/start-chat";
import { JsonLd, personLd } from "@/components/shared/json-ld";
import { ClientEntity } from "@/components/shared/client-entity";
import { MatchCard } from "@/components/shared/cards";
import { siteConfig } from "@/config/site";
import { usePathParam } from "@/lib/use-path-param";
import type { Player } from "@/types/models";

export function PlayerProfileClient() {
  const playerId = usePathParam("playerId", 1);
  const load = useCallback(() => getPlayer(playerId), [playerId]);
  if (!playerId) return <p>Loading…</p>;
  return (
    <ClientEntity<Player> load={load}>
      {(player) => <PlayerView player={player} />}
    </ClientEntity>
  );
}

function PlayerView({ player }: { player: Player }) {
  const s = player.stats;
  const matches = useQuery({
    queryKey: ["player-matches", player.id],
    queryFn: () => listMatches({ take: 80 }),
  });
  const recent = (matches.data ?? []).filter((match) => matchInvolvesPlayer(match, player.id)).slice(0, 8);
  return (
    <div className="space-y-8">
      <JsonLd
        data={personLd({
          name: player.name,
          path: `/players/${player.id}`,
          image: player.photoUrl,
          role: player.role,
        })}
      />
      <header className="flex flex-col gap-4 rounded-3xl border border-border bg-card p-6 md:flex-row">
        <div className="h-28 w-28 overflow-hidden rounded-2xl bg-muted">
          {player.photoUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={player.photoUrl} alt="" className="h-full w-full object-cover" />
          ) : null}
        </div>
        <div className="flex-1">
          <p className="text-sm text-muted-foreground">
            {player.playerId || "Cricket ID pending"}
            {player.playerId ? (
              <Button
                className="ml-2 h-7 px-2 text-xs"
                size="sm"
                variant="outline"
                onClick={async () => {
                  await navigator.clipboard.writeText(player.playerId!);
                  toast.success("Cricket ID copied");
                }}
              >
                Copy ID
              </Button>
            ) : null}
          </p>
          <h1 className="text-3xl font-bold">{player.name}</h1>
          <p className="text-muted-foreground">
            {[player.role, player.country, locationLabel(player.location)].filter(Boolean).join(" · ")}
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            {player.battingStyle ? <Badge variant="outline">{player.battingStyle}</Badge> : null}
            {player.bowlingStyle ? <Badge variant="outline">{player.bowlingStyle}</Badge> : null}
          </div>
        </div>
        <div className="flex flex-col items-start gap-2">
          <FollowShare
            kind="player"
            id={player.userId ?? ""}
            title={player.name}
            path={`/players/${player.id}`}
            followedPlayerId={player.playerId || player.id}
          />
          <StartChatButton
            otherId={player.userId}
            otherName={player.name}
            otherPhotoUrl={player.photoUrl}
            otherPlayerId={player.playerId}
          />
        </div>
      </header>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        alt={`QR for ${player.name}`}
        className="h-40 w-40 rounded-2xl border border-border bg-white p-2"
        src={`https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${encodeURIComponent(`${siteConfig.url}/players/${player.id}`)}`}
      />
      <section className="grid gap-4 md:grid-cols-4">
        <Stat label="Matches" value={s.matchesPlayed} />
        <Stat label="Runs" value={s.runs} />
        <Stat label="Wickets" value={s.wickets} />
        <Stat label="Catches" value={s.catches} />
      </section>
      <section className="grid gap-4 md:grid-cols-3">
        <Card className="p-5">
          <h2 className="font-semibold">Batting</h2>
          <ul className="mt-2 space-y-1 text-sm">
            <li>High score {s.highScore}</li>
            <li>Fifties {s.fifties}</li>
            <li>Hundreds {s.hundreds}</li>
            <li>SR {strikeRate(s.runs, s.ballsFaced)}</li>
            <li>Average {battingAverage(s.runs, s.dismissals)}</li>
          </ul>
        </Card>
        <Card className="p-5">
          <h2 className="font-semibold">Bowling</h2>
          <ul className="mt-2 space-y-1 text-sm">
            <li>Wickets {s.wickets}</li>
            <li>Runs conceded {s.runsConceded}</li>
            <li>3-fors {s.threeWickets}</li>
            <li>5-fors {s.fiveWickets}</li>
          </ul>
        </Card>
        <Card className="p-5">
          <h2 className="font-semibold">Fielding</h2>
          <ul className="mt-2 space-y-1 text-sm">
            <li>Catches {s.catches}</li>
            <li>Run outs {s.runOuts}</li>
            <li>Stumpings {s.stumpings}</li>
          </ul>
        </Card>
      </section>
      {recent.length > 0 ? (
        <section>
          <h2 className="mb-3 text-xl font-bold">Recent matches</h2>
          <div className="grid gap-4 md:grid-cols-2">
            {recent.map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <Card className="p-5">
      <p className="text-sm text-muted-foreground">{label}</p>
      <p className="text-3xl font-bold">{value}</p>
    </Card>
  );
}
