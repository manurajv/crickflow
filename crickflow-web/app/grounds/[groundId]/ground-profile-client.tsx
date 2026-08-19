"use client";

import { useCallback } from "react";
import { MatchCard } from "@/components/shared/cards";
import { ClientEntity } from "@/components/shared/client-entity";
import { locationLabel } from "@/lib/cricket/format";
import { usePathParam } from "@/lib/use-path-param";
import { listDerivedGrounds, listMatches } from "@/repositories";
import type { DerivedGround, Match } from "@/types/models";

export function GroundProfileClient() {
  const groundId = usePathParam("groundId", 1);
  const load = useCallback(async () => {
    const grounds = await listDerivedGrounds();
    const ground = grounds.find((g) => g.id === groundId);
    if (!ground) return null;
    const matches = (await listMatches({ take: 80 })).filter((m) => {
      const name = (m.venue || m.location.placeName).toLowerCase();
      return name.includes(ground.name.toLowerCase().slice(0, 20));
    });
    return { ground, matches };
  }, [groundId]);
  if (!groundId) return <p>Loading…</p>;
  return (
    <ClientEntity<{ ground: DerivedGround; matches: Match[] }> load={load}>
      {({ ground, matches }) => {
        const mapsKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;
        const q = encodeURIComponent(`${ground.name} ${locationLabel(ground.location)}`);
        return (
          <div className="space-y-6">
            <h1 className="text-3xl font-bold">{ground.name}</h1>
            <p className="text-muted-foreground">{locationLabel(ground.location)}</p>
            <iframe
              title="Map"
              className="h-72 w-full rounded-2xl border border-border"
              src={
                mapsKey
                  ? `https://www.google.com/maps/embed/v1/place?key=${mapsKey}&q=${q}`
                  : `https://maps.google.com/maps?q=${q}&output=embed`
              }
            />
            <div className="grid gap-4 md:grid-cols-2">
              {matches.map((m) => (
                <MatchCard key={m.id} match={m} />
              ))}
            </div>
          </div>
        );
      }}
    </ClientEntity>
  );
}
