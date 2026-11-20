"use client";

import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { AppLink as Link } from "@/components/shared/app-link";
import { EntityCard, MatchCard } from "@/components/shared/cards";
import { LoadingPage, PageHeader } from "@/components/shared/page-shell";
import { Button } from "@/components/ui/button";
import { battingAverage, formatOvers, strikeRate, economy } from "@/lib/cricket/format";
import {
  PROFILE_OVERS_FILTER_OPTIONS,
  cricketBallTypeLabel,
  profileMatchFilterOptions,
  profileMatchOversFilterLabel,
  profileMatchTypeFilterLabel,
  TROPHY_LABELS,
  BATTING_CLUSTER_LABELS,
  BOWLING_CLUSTER_LABELS,
  type ProfileMatchFilters,
  type BattingClusterType,
  type BowlingClusterType,
} from "@/lib/cricket/player-cricket-profile";
import type { PlayerStats } from "@/types/models";
import {
  deriveCricketProfileView,
  loadCricketProfileByPlayerId,
} from "@/features/profiles/cricket/load-cricket-profile";

const TABS = ["Matches", "Stats", "Trophies", "Badges", "Teams", "Connections"] as const;

export function CricketProfileView({
  playerId,
  backHref,
}: {
  playerId: string;
  backHref?: string;
}) {
  const [tab, setTab] = useState<(typeof TABS)[number]>("Stats");
  const [filters, setFilters] = useState<ProfileMatchFilters>({});
  const query = useQuery({
    queryKey: ["cricket-profile", playerId],
    queryFn: () => loadCricketProfileByPlayerId(playerId),
    enabled: Boolean(playerId),
  });

  if (!playerId) return <LoadingPage title="Loading cricket profile" />;
  if (query.isPending) return <LoadingPage title="Loading cricket profile" />;
  if (query.error) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-8">
        <p className="text-sm text-muted-foreground">Could not load this cricket profile.</p>
      </div>
    );
  }
  if (!query.data) {
    return (
      <div className="mx-auto max-w-5xl px-4 py-8">
        <p className="text-sm text-muted-foreground">This player could not be found.</p>
      </div>
    );
  }

  return (
    <LoadedProfile
      playerId={playerId}
      backHref={backHref}
      tab={tab}
      onTab={setTab}
      filters={filters}
      onFilters={setFilters}
      data={query.data}
    />
  );
}

function LoadedProfile({
  playerId,
  backHref,
  tab,
  onTab,
  filters,
  onFilters,
  data,
}: {
  playerId: string;
  backHref?: string;
  tab: (typeof TABS)[number];
  onTab: (tab: (typeof TABS)[number]) => void;
  filters: ProfileMatchFilters;
  onFilters: (filters: ProfileMatchFilters) => void;
  data: NonNullable<Awaited<ReturnType<typeof loadCricketProfileByPlayerId>>>;
}) {
  const derived = useMemo(() => deriveCricketProfileView(data, filters), [data, filters]);
  const options = useMemo(
    () => profileMatchFilterOptions(data.participatedMatches),
    [data.participatedMatches],
  );
  const player = data.player;
  const clusters = derived.clusters;

  return (
    <div className="mx-auto max-w-5xl px-4 py-8">
      <PageHeader
        eyebrow="Cricket profile"
        title={player.name}
        description={
          [player.role, player.battingStyle, player.bowlingStyle].filter(Boolean).join(" · ") ||
          "Match history, stats, trophies, badges, and teams."
        }
        actions={
          backHref ? (
            <Button variant="outline" asChild>
              <Link href={backHref}>Back to profile</Link>
            </Button>
          ) : (
            <Button variant="outline" asChild>
              <Link href={`/players/${playerId}`}>Player profile</Link>
            </Button>
          )
        }
      />

      {(clusters.batting || clusters.bowling) && (
        <div className="mb-6 flex flex-wrap gap-2">
          {clusters.batting ? (
            <span className="rounded-full bg-accent-soft px-3 py-1 text-sm font-semibold">
              {BATTING_CLUSTER_LABELS[clusters.batting as BattingClusterType]}
            </span>
          ) : null}
          {clusters.bowling ? (
            <span className="rounded-full bg-muted px-3 py-1 text-sm font-semibold">
              {BOWLING_CLUSTER_LABELS[clusters.bowling as BowlingClusterType]}
            </span>
          ) : null}
        </div>
      )}

      <div className="mb-6 flex flex-wrap gap-2 border-b border-border pb-3">
        {TABS.map((item) => (
          <button
            key={item}
            type="button"
            onClick={() => onTab(item)}
            className={`rounded-full px-3 py-1.5 text-sm font-semibold ${
              tab === item ? "bg-primary text-primary-foreground" : "bg-muted text-foreground"
            }`}
          >
            {item}
          </button>
        ))}
      </div>

      {tab === "Matches" && (
        <MatchesPanel matches={derived.filteredMatches} />
      )}
      {tab === "Stats" && (
        <StatsPanel
          breakdown={derived.breakdown}
          captain={derived.captainStats}
          clusters={clusters}
          filters={filters}
          options={options}
          onFilters={onFilters}
          playerId={playerId}
        />
      )}
      {tab === "Trophies" && <TrophiesPanel trophies={derived.trophies} />}
      {tab === "Badges" && <BadgesPanel badges={derived.badges} />}
      {tab === "Teams" && <TeamsPanel teams={derived.teams} />}
      {tab === "Connections" && (
        <ConnectionsPanel following={data.following} followers={data.followers} />
      )}
    </div>
  );
}

function MatchesPanel({ matches }: { matches: import("@/types/models").Match[] }) {
  if (!matches.length) {
    return <p className="text-sm text-muted-foreground">No matches to show for these filters.</p>;
  }
  return (
    <div className="grid gap-4 md:grid-cols-2">
      {matches.map((match) => (
        <MatchCard key={match.id} match={match} />
      ))}
    </div>
  );
}

function StatsPanel({
  breakdown,
  captain,
  clusters,
  filters,
  options,
  onFilters,
  playerId,
}: {
  breakdown: ReturnType<typeof deriveCricketProfileView>["breakdown"];
  captain: ReturnType<typeof deriveCricketProfileView>["captainStats"];
  clusters: ReturnType<typeof deriveCricketProfileView>["clusters"];
  filters: ProfileMatchFilters;
  options: ReturnType<typeof profileMatchFilterOptions>;
  onFilters: (filters: ProfileMatchFilters) => void;
  playerId: string;
}) {
  const [statKind, setStatKind] = useState<"Batting" | "Bowling" | "Fielding" | "Captain">("Batting");
  return (
    <div className="space-y-8">
      <FilterBar filters={filters} options={options} onFilters={onFilters} />
      <div className="flex flex-wrap gap-2">
        {(["Batting", "Bowling", "Fielding", "Captain"] as const).map((kind) => (
          <button
            key={kind}
            type="button"
            onClick={() => setStatKind(kind)}
            className={`rounded-full px-3 py-1 text-sm font-semibold ${
              statKind === kind ? "bg-foreground text-background" : "bg-muted"
            }`}
          >
            {kind}
          </button>
        ))}
      </div>

      {statKind !== "Captain" ? (
        <>
          <StatsBlock
            title="Overall"
            kind={statKind}
            stats={breakdown.overall}
            extras={
              statKind === "Bowling"
                ? {
                    dots: breakdown.overallDotBalls,
                    wides: breakdown.overallWides,
                    noBalls: breakdown.overallNoBalls,
                    ballsPerOver: breakdown.overallBallsPerOver,
                    bowlingActualOvers: breakdown.overallBowlingActualOvers,
                  }
                : undefined
            }
          />
          {breakdown.typedSections.map((section) => (
            <StatsBlock
              key={section.title}
              title={section.title}
              kind={statKind}
              stats={section.stats}
              extras={
                statKind === "Bowling"
                  ? {
                      dots: section.dotBalls,
                      wides: section.wides,
                      noBalls: section.noBalls,
                      ballsPerOver: section.ballsPerOver,
                      bowlingActualOvers: section.bowlingActualOvers,
                    }
                  : undefined
              }
            />
          ))}
        </>
      ) : (
        <CaptainBlock captain={captain} />
      )}

      <section className="rounded-2xl border border-border bg-card p-5">
        <h2 className="text-lg font-bold">Analysis</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          Shot and bowling patterns from completed matches, using the same ball-event history as the app when it is available.
        </p>
        <div className="mt-4 grid gap-4 md:grid-cols-2">
          <PatternCard
            title={clusters.batting ? `Batting · ${BATTING_CLUSTER_LABELS[clusters.batting as BattingClusterType]}` : "Batting pattern"}
            rows={[
              ["Dot %", clusters.battingPattern.dotPct],
              ["Singles %", clusters.battingPattern.singlesPct],
              ["Twos %", clusters.battingPattern.doublesPct],
              ["Boundary %", clusters.battingPattern.boundaryPct],
              ["Six %", clusters.battingPattern.sixPct],
            ]}
            footer={`${clusters.battingPattern.inningsCount} innings · ${clusters.battingPattern.runs} runs`}
          />
          <PatternCard
            title={clusters.bowling ? `Bowling · ${BOWLING_CLUSTER_LABELS[clusters.bowling as BowlingClusterType]}` : "Bowling pattern"}
            rows={[
              ["Dot %", clusters.bowlingPattern.dotPct],
              ["Economy", clusters.bowlingPattern.economy],
              ["Average", clusters.bowlingPattern.average],
              ["Strike rate", clusters.bowlingPattern.strikeRate],
            ]}
            footer={`${clusters.bowlingPattern.matchCount} matches · ${clusters.bowlingPattern.wickets} wickets · ${clusters.bowlingPattern.oversBowled.toFixed(1)} overs`}
          />
        </div>
        <p className="mt-4 text-sm">
          <Link className="font-semibold text-primary" href={`/players/${playerId}`}>
            Open player profile
          </Link>
        </p>
      </section>
    </div>
  );
}

function FilterBar({
  filters,
  options,
  onFilters,
}: {
  filters: ProfileMatchFilters;
  options: ReturnType<typeof profileMatchFilterOptions>;
  onFilters: (filters: ProfileMatchFilters) => void;
}) {
  const set = (patch: ProfileMatchFilters) => onFilters({ ...filters, ...patch });
  return (
    <div className="grid gap-3 rounded-2xl border border-border p-4 md:grid-cols-3">
      <FilterSelect
        label="Overs"
        value={filters.overs == null ? "" : String(filters.overs)}
        onChange={(v) => set({ overs: v ? Number(v) : null })}
        options={[
          { value: "", label: "All overs" },
          { value: "-1", label: "Test" },
          ...PROFILE_OVERS_FILTER_OPTIONS.map((n) => ({
            value: String(n),
            label: profileMatchOversFilterLabel(n),
          })),
        ]}
      />
      <FilterSelect
        label="Ball type"
        value={filters.ballType ?? ""}
        onChange={(v) => set({ ballType: (v || null) as ProfileMatchFilters["ballType"] })}
        options={[
          { value: "", label: "All ball types" },
          { value: "leather", label: cricketBallTypeLabel("leather") },
          { value: "tennis", label: cricketBallTypeLabel("tennis") },
          { value: "indoor", label: cricketBallTypeLabel("indoor") },
        ]}
      />
      <FilterSelect
        label="Match type"
        value={filters.matchType ?? ""}
        onChange={(v) => set({ matchType: v || null })}
        options={[
          { value: "", label: "All match types" },
          { value: "limitedOvers", label: profileMatchTypeFilterLabel("limitedOvers") },
          { value: "indoor", label: profileMatchTypeFilterLabel("indoor") },
          { value: "testMatch", label: profileMatchTypeFilterLabel("testMatch") },
        ]}
      />
      <FilterSelect
        label="Year"
        value={filters.year == null ? "" : String(filters.year)}
        onChange={(v) => set({ year: v ? Number(v) : null })}
        options={[
          { value: "", label: "All years" },
          ...options.years.map((year) => ({ value: String(year), label: String(year) })),
        ]}
      />
      <FilterSelect
        label="Team"
        value={filters.teamId ?? ""}
        onChange={(v) => set({ teamId: v || null })}
        options={[
          { value: "", label: "All teams" },
          ...Object.entries(options.teamIds).map(([id, name]) => ({ value: id, label: name })),
        ]}
      />
      <FilterSelect
        label="Tournament"
        value={filters.tournamentId ?? ""}
        onChange={(v) => set({ tournamentId: v || null })}
        options={[
          { value: "", label: "All tournaments" },
          ...Object.entries(options.tournamentIds).map(([id, name]) => ({ value: id, label: name })),
        ]}
      />
    </div>
  );
}

function FilterSelect({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: Array<{ value: string; label: string }>;
}) {
  return (
    <label className="block text-sm">
      <span className="mb-1 block text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        {label}
      </span>
      <select
        className="w-full rounded-xl border border-border bg-background px-3 py-2"
        value={value}
        onChange={(e) => onChange(e.target.value)}
      >
        {options.map((opt) => (
          <option key={opt.value || "all"} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </label>
  );
}

function StatsBlock({
  title,
  kind,
  stats,
  extras,
}: {
  title: string;
  kind: "Batting" | "Bowling" | "Fielding";
  stats: PlayerStats;
  extras?: {
    dots?: number;
    wides?: number;
    noBalls?: number;
    ballsPerOver?: number;
    bowlingActualOvers?: number;
  };
}) {
  const bpo = extras?.ballsPerOver ?? 6;
  const cells =
    kind === "Batting"
      ? [
          ["Matches", stats.matchesPlayed],
          ["Inns", stats.inningsPlayed],
          ["Runs", stats.runs],
          ["Balls", stats.ballsFaced],
          ["HS", stats.highScore],
          ["Avg", battingAverage(stats.runs, stats.dismissals)],
          ["SR", strikeRate(stats.runs, stats.ballsFaced)],
          ["30s", stats.thirties],
          ["50s", stats.fifties],
          ["100s", stats.hundreds],
          ["Ducks", stats.ducks],
          ["4s", stats.fours],
          ["6s", stats.sixes],
        ]
      : kind === "Bowling"
        ? [
            ["Matches", stats.matchesPlayed],
            ["Wickets", stats.wickets],
            ["Overs", extras?.bowlingActualOvers != null
              ? extras.bowlingActualOvers.toFixed(1)
              : formatOvers(stats.oversBowledBalls, bpo)],
            ["Runs", stats.runsConceded],
            ["Econ", economy(stats.runsConceded, stats.oversBowledBalls, bpo)],
            ["3w", stats.threeWickets],
            ["5w", stats.fiveWickets],
            ["Dots", extras?.dots ?? "—"],
            ["Wides", extras?.wides ?? 0],
            ["NB", extras?.noBalls ?? 0],
          ]
        : [
            ["Matches", stats.matchesPlayed],
            ["Catches", stats.catches],
            ["Run outs", stats.runOuts],
            ["Stumpings", stats.stumpings],
          ];
  return (
    <section>
      <h2 className="text-lg font-bold">{title}</h2>
      {stats.matchesPlayed === 0 ? (
        <p className="mt-2 text-sm text-muted-foreground">No completed matches in this view.</p>
      ) : (
        <div className="mt-3 grid grid-cols-3 gap-2 sm:grid-cols-5">
          {cells.map(([label, value]) => (
            <div key={String(label)} className="rounded-xl border border-border bg-card p-3">
              <p className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
                {label}
              </p>
              <p className="mt-1 text-lg font-bold">{value}</p>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}

function CaptainBlock({
  captain,
}: {
  captain: ReturnType<typeof deriveCricketProfileView>["captainStats"];
}) {
  if (captain.matchesAsCaptain === 0) {
    return <p className="text-sm text-muted-foreground">No completed matches as captain yet.</p>;
  }
  const cells = [
    ["Matches", captain.matchesAsCaptain],
    ["Wins", captain.wins],
    ["Losses", captain.losses],
    ["Ties", captain.ties],
    ["Tosses won", `${captain.tossesWon}/${captain.tossesTotal}`],
    ["Highest score", captain.highestTeamScore],
    ["Lowest defended", captain.lowestDefendedScore || "—"],
    ["Chases", `${captain.successfulChases}/${captain.chaseAttempts}`],
    ["Avg team score", captain.avgTeamScore ? captain.avgTeamScore.toFixed(1) : "—"],
    ["Avg conceded", captain.avgConcededScore ? captain.avgConcededScore.toFixed(1) : "—"],
  ];
  return (
    <section className="space-y-6">
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-5">
        {cells.map(([label, value]) => (
          <div key={String(label)} className="rounded-xl border border-border bg-card p-3">
            <p className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
              {label}
            </p>
            <p className="mt-1 text-lg font-bold">{value}</p>
          </div>
        ))}
      </div>
      {captain.byYear.length ? (
        <div>
          <h3 className="font-semibold">By year</h3>
          <ul className="mt-2 space-y-1 text-sm">
            {captain.byYear.map((row) => (
              <li key={row.year}>
                {row.year}: {row.wins}-{row.losses} in {row.matches}
              </li>
            ))}
          </ul>
        </div>
      ) : null}
      {captain.byFormat.length ? (
        <div>
          <h3 className="font-semibold">By format</h3>
          <ul className="mt-2 space-y-1 text-sm">
            {captain.byFormat.map((row) => (
              <li key={row.label}>
                {row.label}: {row.wins}-{row.losses} in {row.matches}
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </section>
  );
}

function PatternCard({
  title,
  rows,
  footer,
}: {
  title: string;
  rows: Array<[string, number]>;
  footer: string;
}) {
  return (
    <div className="rounded-xl border border-border p-4">
      <h3 className="font-semibold">{title}</h3>
      <ul className="mt-3 space-y-2">
        {rows.map(([label, value]) => (
          <li key={label}>
            <div className="mb-1 flex justify-between text-xs text-muted-foreground">
              <span>{label}</span>
              <span>{value.toFixed(1)}</span>
            </div>
            <div className="h-1.5 overflow-hidden rounded-full bg-muted">
              <div className="h-full bg-primary" style={{ width: `${Math.min(100, Math.max(0, value))}%` }} />
            </div>
          </li>
        ))}
      </ul>
      <p className="mt-3 text-xs text-muted-foreground">{footer}</p>
    </div>
  );
}

function TrophiesPanel({
  trophies,
}: {
  trophies: ReturnType<typeof deriveCricketProfileView>["trophies"];
}) {
  if (!trophies.length) {
    return <p className="text-sm text-muted-foreground">No trophies from completed matches yet.</p>;
  }
  return (
    <ul className="space-y-3">
      {trophies.map((trophy, index) => (
        <li key={`${trophy.matchId}-${trophy.kind}-${index}`} className="rounded-2xl border border-border bg-card p-4">
          <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            {trophy.emoji} {trophy.title || TROPHY_LABELS[trophy.kind]}
          </p>
          <p className="mt-1 font-bold">{trophy.matchTitle}</p>
          {trophy.performance ? <p className="text-sm text-muted-foreground">{trophy.performance}</p> : null}
          {trophy.teamName ? <p className="mt-1 text-xs text-muted-foreground">{trophy.teamName}</p> : null}
        </li>
      ))}
    </ul>
  );
}

function BadgesPanel({
  badges,
}: {
  badges: ReturnType<typeof deriveCricketProfileView>["badges"];
}) {
  const earned = badges.filter((b) => b.unlocked);
  const locked = badges.filter((b) => !b.unlocked);
  return (
    <div className="space-y-8">
      <section>
        <h2 className="text-lg font-bold">Earned</h2>
        {earned.length ? (
          <div className="mt-3 grid gap-3 sm:grid-cols-2">
            {earned.map((badge) => (
              <div key={badge.definition.id} className="rounded-2xl border border-border bg-card p-4">
                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  {badge.definition.tier} · {badge.definition.category}
                </p>
                <p className="mt-1 font-bold">{badge.definition.title}</p>
                <p className="mt-1 text-sm text-muted-foreground">{badge.definition.requirement}</p>
                {badge.unlockCount > 1 ? (
                  <p className="mt-2 text-xs font-semibold">Earned {badge.unlockCount} times</p>
                ) : null}
                {badge.unlockPerformanceSnapshot ? (
                  <p className="mt-1 text-xs text-muted-foreground">{badge.unlockPerformanceSnapshot}</p>
                ) : null}
                {badge.progressToNextTier ? (
                  <p className="mt-2 text-xs font-semibold">{badge.progressToNextTier}</p>
                ) : null}
              </div>
            ))}
          </div>
        ) : (
          <p className="mt-2 text-sm text-muted-foreground">No badges earned yet.</p>
        )}
      </section>
      <section>
        <h2 className="text-lg font-bold">Still locked</h2>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          {locked.map((badge) => (
            <div key={badge.definition.id} className="rounded-2xl border border-dashed border-border p-4 opacity-80">
              <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                {badge.definition.tier} · {badge.definition.category}
              </p>
              <p className="mt-1 font-bold">{badge.definition.title}</p>
              <p className="mt-1 text-sm text-muted-foreground">{badge.definition.requirement}</p>
              {badge.target > 0 ? (
                <p className="mt-2 text-xs font-semibold">
                  {badge.progress.toFixed(badge.target >= 50 && badge.progress > 20 ? 0 : 1)} / {badge.target.toFixed(badge.target >= 50 ? 0 : 1)}
                  {badge.progressToNextTier ? ` · ${badge.progressToNextTier}` : ""}
                </p>
              ) : null}
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}

function TeamsPanel({
  teams,
}: {
  teams: ReturnType<typeof deriveCricketProfileView>["teams"];
}) {
  if (!teams.length) {
    return <p className="text-sm text-muted-foreground">This player is not on any teams yet.</p>;
  }
  return (
    <div className="grid gap-3 md:grid-cols-2">
      {teams.map((team) => (
        <Link key={team.teamId} href={`/teams/${team.teamId}`} className="rounded-2xl border border-border bg-card p-4 hover:bg-muted/40">
          <p className="font-bold">{team.teamName}</p>
          <p className="text-sm text-muted-foreground">{team.teamRole}</p>
          <p className="mt-2 text-sm">
            {team.matches} matches · {team.wins} wins · {team.runs} runs · {team.wickets} wickets
          </p>
        </Link>
      ))}
    </div>
  );
}

function ConnectionsPanel({
  following,
  followers,
}: {
  following: import("@/types/models").Player[];
  followers: import("@/types/models").Player[];
}) {
  return (
    <div className="space-y-8">
      <section>
        <h2 className="text-lg font-bold">Following</h2>
        {following.length ? (
          <div className="mt-3 grid gap-3 md:grid-cols-2">
            {following.map((person) => (
              <EntityCard
                key={person.id}
                href={`/players/${person.id}/cricket`}
                title={person.name}
                image={person.photoUrl}
              />
            ))}
          </div>
        ) : (
          <p className="mt-2 text-sm text-muted-foreground">No followed players to show.</p>
        )}
      </section>
      <section>
        <h2 className="text-lg font-bold">Followers</h2>
        {followers.length ? (
          <div className="mt-3 grid gap-3 md:grid-cols-2">
            {followers.map((person) => (
              <EntityCard
                key={person.id}
                href={`/players/${person.id}/cricket`}
                title={person.name}
                image={person.photoUrl}
              />
            ))}
          </div>
        ) : (
          <p className="mt-2 text-sm text-muted-foreground">No followers to show.</p>
        )}
      </section>
    </div>
  );
}
