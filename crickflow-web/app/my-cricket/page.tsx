"use client";

import type { ReactNode } from "react";
import { AppLink as Link } from "@/components/shared/app-link";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { GetTheApp } from "@/components/shared/get-the-app";
import { PageHeader, LoadingPage } from "@/components/shared/page-shell";
import { useAuth } from "@/features/auth/auth-provider";
import {
  getPlayerByUserId,
  listFollowedPlayers,
  listMatches,
  listMatchesCreatedBy,
  listTeams,
  listTournaments,
} from "@/repositories";
import { cn } from "@/lib/utils";
import { loginUrl } from "@/lib/auth/guest-access";
import {
  filterMatchByScope,
  filterTeamByScope,
  filterTournamentByScope,
  followedPlayerRefsFromPlayers,
  highlightMatchesForUser,
  memberTeamIds,
  opponentTeamIds,
  sortMyCricketMatches,
  sortMyCricketTournaments,
  type MyCricketListScope,
  type MyCricketSort,
  type TeamListScope,
} from "@/lib/cricket/my-cricket-filters";

type Tab = "matches" | "tournaments" | "teams" | "stats" | "highlights";

const MATCH_SCOPES: { id: MyCricketListScope; label: string }[] = [
  { id: "yours", label: "Yours" },
  { id: "played", label: "Played" },
  { id: "network", label: "Network" },
  { id: "all", label: "All" },
];

const TEAM_SCOPES: { id: TeamListScope; label: string }[] = [
  { id: "yours", label: "Yours" },
  { id: "opponents", label: "Opponents" },
  { id: "all", label: "All" },
];

const SORTS: { id: MyCricketSort; label: string }[] = [
  { id: "newest", label: "Newest" },
  { id: "oldest", label: "Oldest" },
  { id: "name", label: "Name A–Z" },
];

export default function MyCricketPage() {
  const { user, loading } = useAuth();
  const [tab, setTab] = useState<Tab>("matches");
  const [matchScope, setMatchScope] = useState<MyCricketListScope>("yours");
  const [tournamentScope, setTournamentScope] = useState<MyCricketListScope>("yours");
  const [teamScope, setTeamScope] = useState<TeamListScope>("yours");
  const [sort, setSort] = useState<MyCricketSort>("newest");

  const matchesQ = useQuery({
    queryKey: ["my-cricket", "matches", user?.uid],
    queryFn: async () => {
      const [recent, created] = await Promise.all([
        listMatches({ take: 80 }),
        user ? listMatchesCreatedBy(user.uid, 80) : Promise.resolve([]),
      ]);
      const byId = new Map(recent.map((m) => [m.id, m]));
      for (const m of created) byId.set(m.id, m);
      return [...byId.values()];
    },
    enabled: Boolean(user),
  });
  const tournamentsQ = useQuery({
    queryKey: ["my-cricket", "tournaments"],
    queryFn: () => listTournaments(80),
    enabled: Boolean(user),
  });
  const teamsQ = useQuery({
    queryKey: ["my-cricket", "teams"],
    queryFn: () => listTeams(80),
    enabled: Boolean(user),
  });
  const playerQ = useQuery({
    queryKey: ["my-cricket", "player", user?.uid],
    queryFn: () => getPlayerByUserId(user!.uid),
    enabled: Boolean(user),
  });
  const followingQ = useQuery({
    queryKey: ["my-cricket", "following", user?.uid],
    queryFn: () => listFollowedPlayers(user!.uid),
    enabled: Boolean(user),
  });

  const player = playerQ.data ?? null;
  const userTeamIds = useMemo(
    () => memberTeamIds({ teams: teamsQ.data ?? [], uid: user?.uid, player }),
    [teamsQ.data, user?.uid, player],
  );
  const oppIds = useMemo(
    () => opponentTeamIds({ matches: matchesQ.data ?? [], memberTeamIds: userTeamIds }),
    [matchesQ.data, userTeamIds],
  );
  const followed = useMemo(
    () => followedPlayerRefsFromPlayers(followingQ.data ?? []),
    [followingQ.data],
  );
  const filterOpts = useMemo(
    () => ({ uid: user?.uid, player, userTeamIds, followedPlayers: followed }),
    [user?.uid, player, userTeamIds, followed],
  );

  const myMatches = useMemo(
    () =>
      sortMyCricketMatches(
        (matchesQ.data ?? []).filter((m) => filterMatchByScope(m, matchScope, filterOpts)),
        sort,
      ),
    [matchesQ.data, matchScope, sort, filterOpts],
  );
  const myTournaments = useMemo(
    () =>
      sortMyCricketTournaments(
        (tournamentsQ.data ?? []).filter((t) =>
          filterTournamentByScope(t, tournamentScope, filterOpts),
        ),
        sort,
      ),
    [tournamentsQ.data, tournamentScope, sort, filterOpts],
  );
  const myTeams = useMemo(() => {
    const list = (teamsQ.data ?? []).filter((t) =>
      filterTeamByScope(t, teamScope, { memberTeamIds: userTeamIds, opponentTeamIds: oppIds }),
    );
    return [...list].sort((a, b) => a.name.localeCompare(b.name));
  }, [teamsQ.data, teamScope, userTeamIds, oppIds]);
  const highlightMatches = useMemo(
    () => highlightMatchesForUser(matchesQ.data ?? [], { uid: user?.uid, player, userTeamIds }),
    [matchesQ.data, user?.uid, player, userTeamIds],
  );

  if (loading) return <LoadingPage title="Loading My Cricket" />;
  if (!user) {
    return (
      <EmptyState
        title="Sign in for My Cricket"
        description="Your matches, tournaments, teams, and stats live here — same as the app."
        action={<Link href={loginUrl("/my-cricket", "my_cricket")}>Sign in</Link>}
      />
    );
  }

  const tabs: { id: Tab; label: string }[] = [
    { id: "matches", label: "Matches" },
    { id: "tournaments", label: "Tournaments" },
    { id: "teams", label: "Teams" },
    { id: "stats", label: "Stats" },
    { id: "highlights", label: "Highlights" },
  ];

  return (
    <div className="space-y-4">
      <PageHeader
        title="My Cricket"
        eyebrow="You"
        description="Matches · Tournaments · Teams · Stats — the same hub as the mobile app."
        actions={
          <ButtonLink href="/my-cricket-profile">Profile</ButtonLink>
        }
      />
      <GetTheApp
        title="Scoring and streaming stay on the mobile app"
        description="Start, score, and broadcast matches in the CrickFlow Android app. This page lists your matches and highlights so you can watch and review them on the web."
      />
      <nav className="flex gap-1 overflow-x-auto border-b border-border">
        {tabs.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setTab(t.id)}
            className={cn(
              "shrink-0 border-b-2 px-3 py-2 text-sm font-medium",
              tab === t.id
                ? "border-[color:var(--nav-selected)] text-[color:var(--nav-selected)]"
                : "border-transparent text-muted-foreground",
            )}
          >
            {t.label}
          </button>
        ))}
      </nav>

      {tab === "matches" ? (
        <>
          <FilterRow
            scopes={MATCH_SCOPES}
            scope={matchScope}
            onScope={setMatchScope}
            sort={sort}
            onSort={setSort}
          />
          <Section
            loading={matchesQ.isLoading}
            empty={!myMatches.length}
            emptyTitle="No matches in this filter"
          >
            {myMatches.slice(0, 30).map((m) => (
              <Link key={m.id} href={`/matches/${m.id}`} className="block">
                <Card className="mb-2 p-4 hover:bg-muted/40">
                  <p className="font-semibold">
                    {m.teamAName || "Team A"} vs {m.teamBName || "Team B"}
                  </p>
                  <p className="text-sm text-muted-foreground">{m.status}</p>
                </Card>
              </Link>
            ))}
          </Section>
        </>
      ) : null}

      {tab === "tournaments" ? (
        <>
          <FilterRow
            scopes={MATCH_SCOPES}
            scope={tournamentScope}
            onScope={setTournamentScope}
            sort={sort}
            onSort={setSort}
          />
          <Section
            loading={tournamentsQ.isLoading}
            empty={!myTournaments.length}
            emptyTitle="No tournaments in this filter"
          >
            {myTournaments.slice(0, 30).map((t) => (
              <Link key={t.id} href={`/tournaments/${t.id}`} className="block">
                <Card className="mb-2 p-4 hover:bg-muted/40">
                  <p className="font-semibold">{t.name}</p>
                  <p className="text-sm text-muted-foreground">{t.status}</p>
                </Card>
              </Link>
            ))}
          </Section>
        </>
      ) : null}

      {tab === "teams" ? (
        <>
          <div className="flex flex-wrap gap-2">
            {TEAM_SCOPES.map((s) => (
              <Chip key={s.id} active={teamScope === s.id} onClick={() => setTeamScope(s.id)}>
                {s.label}
              </Chip>
            ))}
          </div>
          <Section
            loading={teamsQ.isLoading}
            empty={!myTeams.length}
            emptyTitle="No teams in this filter"
          >
            {myTeams.slice(0, 30).map((t) => (
              <Link key={t.id} href={`/teams/${t.id}`} className="block">
                <Card className="mb-2 p-4 hover:bg-muted/40">
                  <p className="font-semibold">{t.name}</p>
                </Card>
              </Link>
            ))}
          </Section>
        </>
      ) : null}

      {tab === "stats" ? (
        <Card className="space-y-2 p-4">
          <p className="font-semibold">Your cricket stats</p>
          <p className="text-sm text-muted-foreground">
            Detailed batting and bowling stats stay on your player profile.
          </p>
          <Link href="/profile" className="text-sm text-primary">
            Open profile →
          </Link>
          <Link href="/statistics" className="block text-sm text-primary">
            Public statistics →
          </Link>
        </Card>
      ) : null}

      {tab === "highlights" ? (
        <Section
          loading={matchesQ.isLoading}
          empty={!highlightMatches.length}
          emptyTitle="Complete a match to see highlights here"
        >
          <p className="mb-3 text-sm text-muted-foreground">
            Boundaries and wickets from your completed matches. Open a match to watch the Highlights tab.
          </p>
          {highlightMatches.map((m) => (
            <Link key={m.id} href={`/matches/${m.id}/highlights`} className="block">
              <Card className="mb-2 p-4 hover:bg-muted/40">
                <p className="font-semibold">
                  {m.teamAName || "Team A"} vs {m.teamBName || "Team B"}
                </p>
                <p className="text-sm text-muted-foreground">{m.resultSummary || m.status}</p>
              </Card>
            </Link>
          ))}
        </Section>
      ) : null}
    </div>
  );
}

function ButtonLink({ href, children }: { href: string; children: ReactNode }) {
  return (
    <Link
      href={href}
      className="inline-flex h-9 items-center rounded-md border border-border px-3 text-sm font-medium hover:bg-muted"
    >
      {children}
    </Link>
  );
}

function Chip({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "rounded-full border px-3 py-1 text-sm",
        active ? "border-primary bg-primary/10 text-primary" : "border-border text-muted-foreground",
      )}
    >
      {children}
    </button>
  );
}

function FilterRow<T extends string>({
  scopes,
  scope,
  onScope,
  sort,
  onSort,
}: {
  scopes: { id: T; label: string }[];
  scope: T;
  onScope: (id: T) => void;
  sort: MyCricketSort;
  onSort: (id: MyCricketSort) => void;
}) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      {scopes.map((s) => (
        <Chip key={s.id} active={scope === s.id} onClick={() => onScope(s.id)}>
          {s.label}
        </Chip>
      ))}
      <span className="mx-1 text-xs text-muted-foreground">Sort</span>
      {SORTS.map((s) => (
        <Chip key={s.id} active={sort === s.id} onClick={() => onSort(s.id)}>
          {s.label}
        </Chip>
      ))}
    </div>
  );
}

function Section({
  loading,
  empty,
  emptyTitle,
  children,
}: {
  loading: boolean;
  empty: boolean;
  emptyTitle: string;
  children: ReactNode;
}) {
  if (loading) return <p className="text-sm text-muted-foreground">Loading…</p>;
  if (empty) return <EmptyState title={emptyTitle} />;
  return <div>{children}</div>;
}
