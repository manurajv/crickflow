"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/shared/states";
import { FilterChip } from "@/components/shared/filter-chip";
import {
  ORG_BALL_LABELS,
  ORG_CATEGORY_TITLES,
  ORG_RANKING_SECTIONS,
  ORG_SECTION_CATEGORIES,
  ORG_SECTION_LABELS,
  ORG_STANDALONE_FILTER,
  aggregateOrgPlayerStats,
  ballTypesPresent,
  buildOrgPointsTable,
  defaultBall,
  matchesMissingDigest,
  orgRankingMatches,
  playerIdsInStats,
  rankOrgPlayers,
  type OrgRankingCategory,
  type OrgRankingSection,
} from "@/lib/cricket/org-leaderboard";
import { useOrgLeaderboard, useRebuildSeriesStandings } from "./hooks";
import { loadOrgPlayers } from "./leaderboard-repository";
import type { SeriesClub, SeriesSettings } from "./types";
import type { CricketBallType } from "@/types/enums";

type View = "table" | "players";

/**
 * Org leaderboard: the same points table (P W L T NR Pts NRR) and player
 * rankings (batting, bowling, fielding) as the CrickFlow app, computed from the
 * org's official matches only with the app's own rules (see
 * lib/cricket/org-leaderboard.ts).
 */
export function OrgLeaderboard({
  seriesId,
  clubs,
  rules,
  canManage,
}: {
  seriesId: string;
  clubs: SeriesClub[];
  rules?: SeriesSettings["rankingRules"];
  canManage: boolean;
}) {
  const board = useOrgLeaderboard(seriesId);
  const rebuild = useRebuildSeriesStandings(seriesId);
  const [view, setView] = useState<View>("table");
  const [competition, setCompetition] = useState<string>("");
  const [ballChoice, setBallChoice] = useState<CricketBallType | null>(null);
  const [section, setSection] = useState<OrgRankingSection>("batting");
  const [category, setCategory] = useState<OrgRankingCategory>("mostRuns");

  const matches = useMemo(() => board.data?.matches ?? [], [board.data]);
  const digests = useMemo(() => board.data?.digests ?? {}, [board.data]);
  const tournaments = useMemo(() => board.data?.tournaments ?? [], [board.data]);
  // A tournament that left the org must not leave a dead filter behind.
  const filter =
    competition === "" || competition === ORG_STANDALONE_FILTER || tournaments.some((t) => t.id === competition)
      ? competition || null
      : null;

  const teams = useMemo(
    () =>
      clubs.map((c) => ({ id: c.id, name: c.name, status: c.status, linkedTeamId: c.linkedTeamId })),
    [clubs],
  );

  const table = useMemo(() => {
    const seed = tournaments.find((t) => t.id === filter)?.teamIds;
    return buildOrgPointsTable({ teams, matches, rules, tournamentFilter: filter, seedTeamIds: seed });
  }, [teams, matches, rules, filter, tournaments]);

  const scoped = useMemo(() => orgRankingMatches(matches, filter), [matches, filter]);
  const present = useMemo(() => ballTypesPresent(scoped), [scoped]);
  const ball: CricketBallType =
    ballChoice && present.includes(ballChoice) ? ballChoice : present.length ? defaultBall(scoped) : "leather";
  const stats = useMemo(() => aggregateOrgPlayerStats(scoped, ball, digests), [scoped, ball, digests]);
  const ids = useMemo(() => playerIdsInStats(stats).sort(), [stats]);
  const players = useQuery({
    queryKey: ["series", seriesId, "leaderboard-players", ids.join(",")],
    queryFn: () => loadOrgPlayers(ids),
    enabled: view === "players" && ids.length > 0,
  });
  const ranked = useMemo(
    () => rankOrgPlayers(players.data ?? [], stats, category),
    [players.data, stats, category],
  );
  const missing = useMemo(() => matchesMissingDigest(matches, digests), [matches, digests]);

  if (board.isLoading) return <p className="text-sm text-muted-foreground">Loading leaderboard…</p>;
  if (board.error) return <EmptyState title="Could not load the leaderboard" />;

  const rulesLine = rules
    ? `Points: Win ${rules.winPoints} · Tie ${rules.tiePoints} · No result ${rules.noResultPoints} · Loss ${rules.lossPoints}${
        rules.useNetRunRate ? " · ties broken by NRR" : ""
      }. Counts approved, finished org matches between org teams.`
    : "";

  return (
    <section className="space-y-4" data-testid="org-leaderboard">
      <div className="flex flex-wrap items-center gap-2">
        <h2 className="mr-2 text-xl font-bold">Leaderboard</h2>
        <FilterChip active={view === "table"} onClick={() => setView("table")}>
          Points table
        </FilterChip>
        <FilterChip active={view === "players"} onClick={() => setView("players")}>
          Player rankings
        </FilterChip>
        <select
          aria-label="Competition"
          className="rounded-lg border border-border bg-background px-3 py-1.5 text-sm"
          value={filter ?? ""}
          onChange={(e) => setCompetition(e.target.value)}
        >
          <option value="">All competitions</option>
          <option value={ORG_STANDALONE_FILTER}>Standalone matches</option>
          {tournaments.map((t) => (
            <option key={t.id} value={t.id}>
              {t.name}
            </option>
          ))}
        </select>
      </div>

      {view === "table" ? (
        !table.length ? (
          <EmptyState title="No standings yet" />
        ) : (
          <>
            <Card className="overflow-x-auto p-0">
              <table className="w-full text-sm" data-testid="org-points-table">
                <thead className="bg-muted/50 text-left">
                  <tr>
                    <th className="p-3">#</th>
                    <th>Team</th>
                    <th>P</th>
                    <th>W</th>
                    <th>L</th>
                    <th>T</th>
                    <th>NR</th>
                    <th>Pts</th>
                    <th className="pr-3">NRR</th>
                  </tr>
                </thead>
                <tbody>
                  {table.map((row) => (
                    <tr key={row.teamId} className="border-t border-border">
                      <td className="p-3">{row.position}</td>
                      <td>{row.teamName}</td>
                      <td>{row.played}</td>
                      <td>{row.won}</td>
                      <td>{row.lost}</td>
                      <td>{row.tied}</td>
                      <td>{row.noResult}</td>
                      <td className="font-bold">{row.points}</td>
                      <td className="pr-3">{row.netRunRate.toFixed(3)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Card>
            {rulesLine ? <p className="text-xs text-muted-foreground">{rulesLine}</p> : null}
          </>
        )
      ) : (
        <div className="space-y-3">
          {present.length > 1 ? (
            <div className="flex flex-wrap gap-2">
              {present.map((b) => (
                <FilterChip key={b} active={ball === b} onClick={() => setBallChoice(b)}>
                  {ORG_BALL_LABELS[b]}
                </FilterChip>
              ))}
            </div>
          ) : null}
          <div className="flex flex-wrap gap-2">
            {ORG_RANKING_SECTIONS.map((s) => (
              <FilterChip
                key={s}
                active={section === s}
                onClick={() => {
                  setSection(s);
                  setCategory(ORG_SECTION_CATEGORIES[s][0]);
                }}
              >
                {ORG_SECTION_LABELS[s]}
              </FilterChip>
            ))}
          </div>
          <label className="block text-sm">
            <span className="mb-1 block text-muted-foreground">Performance</span>
            <select
              className="w-full max-w-xs rounded-lg border border-border bg-background px-3 py-2"
              value={category}
              onChange={(e) => setCategory(e.target.value as OrgRankingCategory)}
            >
              {ORG_SECTION_CATEGORIES[section].map((c) => (
                <option key={c} value={c}>
                  {ORG_CATEGORY_TITLES[c]}
                </option>
              ))}
            </select>
          </label>
          <p className="text-xs text-muted-foreground">
            {ORG_CATEGORY_TITLES[category]} · {ORG_BALL_LABELS[ball]} · org matches only · players with a CrickFlow
            account
          </p>

          {players.isLoading ? (
            <p className="text-sm text-muted-foreground">Loading rankings…</p>
          ) : !ranked.length ? (
            <EmptyState
              title="No rankings yet"
              description={
                scoped.length
                  ? `No player has a ${ORG_CATEGORY_TITLES[category].toLowerCase()} entry yet. Try another category.`
                  : "Player rankings appear after official org matches finish."
              }
            />
          ) : (
            <div className="space-y-2" data-testid="org-player-rankings">
              {ranked.slice(0, 100).map((entry) => (
                <Card key={entry.playerId} className="flex flex-wrap items-center justify-between gap-3 p-4">
                  <div className="flex items-center gap-3">
                    <span className="w-8 text-gold">#{entry.rank}</span>
                    <div>
                      <Link href={`/players/${entry.playerId}`} className="font-bold text-primary">
                        {entry.playerName}
                      </Link>
                      <p className="text-xs text-muted-foreground">
                        {[entry.teamName, entry.role].filter(Boolean).join(" · ")}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-lg font-black">{entry.valueLabel}</p>
                    <p className="text-xs text-muted-foreground">
                      {entry.detail.map(([label, value]) => `${label} ${value}`).join(" · ")}
                    </p>
                  </div>
                </Card>
              ))}
            </div>
          )}
          <p className="text-xs text-muted-foreground">
            Walk-in guests are not ranked: only players with a CrickFlow account appear here, the same as in the app.
          </p>
        </div>
      )}

      {canManage && missing.length > 0 ? (
        <Card className="flex flex-wrap items-center justify-between gap-3 p-4 text-sm">
          <span>
            {missing.length} finished {missing.length === 1 ? "match has" : "matches have"} no fielding / maiden /
            fastest-50 stats yet.
          </span>
          <Button type="button" size="sm" disabled={rebuild.isPending} onClick={() => rebuild.mutate()}>
            {rebuild.isPending ? "Refreshing…" : "Refresh stats"}
          </Button>
        </Card>
      ) : null}
    </section>
  );
}
