"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { FilterChip } from "@/components/shared/filter-chip";
import { PageHeader } from "@/components/shared/page-shell";
import { queryLimits } from "@/config/site";
import { OVERS_LABELS, RANKING_YEAR_OPTIONS, aggregateRankingsFromMatches, rankPlayers } from "@/lib/cricket/rankings";
import { locationMatchesTextFilter } from "@/lib/cricket/location";
import { listMatches, listPlayers } from "@/repositories";
import { Input } from "@/components/ui/input";
import type { CricketBallType, OversFilter, RankingsCategory, RankingsSection } from "@/types/enums";
import { RANKING_CATEGORY_LABELS } from "@/types/enums";

const SECTIONS: RankingsSection[] = ["batting", "bowling", "fielding"];
const BALLS: CricketBallType[] = ["leather", "tennis", "indoor"];
const OVERS: OversFilter[] = ["all", "overs1to12", "overs13to20", "overs21to99", "testMatch"];

function categoriesFor(section: RankingsSection): RankingsCategory[] {
  if (section === "batting") return ["mostRuns", "highestScore", "mostFifties", "mostHundreds"];
  if (section === "bowling") return ["mostWickets", "bestBowlingFigures"];
  return ["mostCatches", "mostRunOuts", "mostStumpings"];
}

export default function RankingsPage() {
  const [ball, setBall] = useState<CricketBallType>("leather");
  const [indoorMaterial, setIndoorMaterial] = useState<CricketBallType | null>(null);
  const [section, setSection] = useState<RankingsSection>("batting");
  const [category, setCategory] = useState<RankingsCategory>("mostRuns");
  const [year, setYear] = useState<number | null>(null);
  const [overs, setOvers] = useState<OversFilter>("all");
  const [country, setCountry] = useState("");
  const [city, setCity] = useState("");

  const players = useQuery({
    queryKey: ["rankings-players"],
    queryFn: () => listPlayers(queryLimits.rankingsPool),
  });
  const matches = useQuery({
    queryKey: ["rankings-matches"],
    queryFn: () => listMatches({ status: "completed", take: queryLimits.rankingsPool }),
  });

  const ranked = useMemo(() => {
    const stats = aggregateRankingsFromMatches(matches.data ?? [], {
      ballType: ball,
      indoorBallMaterial: ball === "indoor" ? indoorMaterial : null,
      category,
      year,
      overs,
    });
    const pool = (players.data ?? []).filter((player) =>
      locationMatchesTextFilter(player.location, { country, city }),
    );
    return rankPlayers(pool, stats, category);
  }, [matches.data, players.data, ball, indoorMaterial, category, year, overs, country, city]);

  const loading = players.isLoading || matches.isLoading;
  const fieldingEmpty = section === "fielding" && ranked.length === 0 && !loading;
  const replayEmpty = category === "bestBowlingFigures";

  return (
    <div>
      <PageHeader
        title="Player Rankings"
        eyebrow="Leaderboards"
        description="Ranked from completed matches with the same ball, year, and overs filters as the mobile app."
      />
      <div className="flex flex-wrap gap-2">
        {BALLS.map((b) => (
          <FilterChip key={b} active={ball === b} onClick={() => { setBall(b); if (b !== "indoor") setIndoorMaterial(null); }}>
            {b}
          </FilterChip>
        ))}
      </div>
      {ball === "indoor" ? (
        <div className="mt-2 flex flex-wrap gap-2">
          {([null, "leather", "tennis"] as const).map((material) => (
            <button
              key={material ?? "all"}
              className={`rounded-full px-3 py-1 text-xs ${indoorMaterial === material ? "bg-primary text-white" : "bg-muted"}`}
              onClick={() => setIndoorMaterial(material)}
            >
              {material ? `Indoor · ${material}` : "All indoor"}
            </button>
          ))}
        </div>
      ) : null}
      <div className="mt-2 flex flex-wrap gap-2">
        {SECTIONS.map((s) => (
          <button
            key={s}
            className={`rounded-full px-3 py-1 text-xs capitalize ${section === s ? "bg-primary text-white" : "bg-muted"}`}
            onClick={() => {
              setSection(s);
              setCategory(categoriesFor(s)[0]);
            }}
          >
            {s}
          </button>
        ))}
      </div>
      <div className="mt-2 flex flex-wrap gap-2">
        {categoriesFor(section).map((c) => (
          <button
            key={c}
            className={`rounded-full px-3 py-1 text-xs ${category === c ? "bg-cricket text-white" : "bg-muted"}`}
            onClick={() => setCategory(c)}
          >
            {RANKING_CATEGORY_LABELS[c]}
          </button>
        ))}
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-2 text-xs">
        <label>
          Year{" "}
          <select
            className="rounded-lg border border-border bg-background px-2 py-1"
            value={year ?? "all"}
            onChange={(e) => setYear(e.target.value === "all" ? null : Number(e.target.value))}
          >
            <option value="all">All time</option>
            {RANKING_YEAR_OPTIONS.map((y) => (
              <option key={y} value={y}>
                {y}
              </option>
            ))}
          </select>
        </label>
        {OVERS.map((o) => (
          <button
            key={o}
            className={`rounded-full px-3 py-1 ${overs === o ? "bg-muted text-foreground" : "bg-muted/50 text-muted-foreground"}`}
            onClick={() => setOvers(o)}
          >
            {OVERS_LABELS[o]}
          </button>
        ))}
        <Input
          className="h-8 w-28 text-xs"
          placeholder="Country"
          value={country}
          onChange={(e) => setCountry(e.target.value)}
        />
        <Input
          className="h-8 w-28 text-xs"
          placeholder="City"
          value={city}
          onChange={(e) => setCity(e.target.value)}
        />
      </div>
      <Card className="mt-6 overflow-x-auto p-0">
        {loading ? (
          <EmptyState title="Loading rankings…" />
        ) : replayEmpty ? (
          <EmptyState title="Needs ball-event replay" description="Best bowling figures stay on mobile until web replay is added." />
        ) : ranked.length === 0 ? (
          <EmptyState
            title="No ranking data yet"
            description={
              fieldingEmpty
                ? "Fielding ranks need catches / run-outs stored on innings. Most matches only persist this after ball-event replay."
                : "No completed matches match these filters yet."
            }
          />
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-muted/50 text-left">
              <tr>
                <th className="p-3">#</th>
                <th>Player</th>
                <th>{RANKING_CATEGORY_LABELS[category]}</th>
              </tr>
            </thead>
            <tbody>
              {ranked.map((row, i) => (
                <tr key={row.player.id} className="border-t border-border">
                  <td className="p-3">{i + 1}</td>
                  <td>
                    <Link href={`/players/${row.player.id}`} className="text-primary">
                      {row.player.name}
                    </Link>
                  </td>
                  <td>{row.value}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  );
}
