"use client";

import type { ReactNode } from "react";
import { AppLink as Link } from "@/components/shared/app-link";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { PageHeader, LoadingPage } from "@/components/shared/page-shell";
import { useAuth } from "@/features/auth/auth-provider";
import { listMatches, listTeams, listTournaments } from "@/repositories";
import { cn } from "@/lib/utils";
import { loginUrl } from "@/lib/auth/guest-access";

type Tab = "matches" | "tournaments" | "teams" | "stats" | "highlights";

export default function MyCricketPage() {
  const { user, loading } = useAuth();
  const [tab, setTab] = useState<Tab>("matches");
  const matchesQ = useQuery({
    queryKey: ["my-cricket", "matches"],
    queryFn: () => listMatches({ take: 40 }),
    enabled: Boolean(user),
  });
  const tournamentsQ = useQuery({
    queryKey: ["my-cricket", "tournaments"],
    queryFn: () => listTournaments(40),
    enabled: Boolean(user),
  });
  const teamsQ = useQuery({
    queryKey: ["my-cricket", "teams"],
    queryFn: () => listTeams(40),
    enabled: Boolean(user),
  });

  const myMatches = useMemo(() => {
    // Web lists recent matches for signed-in users; ownership filtering stays lighter than app
    // until personal match indexes are exposed on web.
    return matchesQ.data ?? [];
  }, [matchesQ.data]);

  if (loading) return <LoadingPage title="Loading My Cricket" />;
  if (!user) {
    return (
      <EmptyState
        title="Sign in for My Cricket"
        description="Your matches, tournaments, teams, and stats live here — same as the app."
        action={<Link href={loginUrl("/my-cricket", "general")}>Sign in</Link>}
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
        <Section
          loading={matchesQ.isLoading}
          empty={!myMatches.length}
          emptyTitle="No matches yet"
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
      ) : null}

      {tab === "tournaments" ? (
        <Section
          loading={tournamentsQ.isLoading}
          empty={!tournamentsQ.data?.length}
          emptyTitle="No tournaments yet"
        >
          {(tournamentsQ.data ?? []).slice(0, 30).map((t) => (
            <Link key={t.id} href={`/tournaments/${t.id}`} className="block">
              <Card className="mb-2 p-4 hover:bg-muted/40">
                <p className="font-semibold">{t.name}</p>
                <p className="text-sm text-muted-foreground">{t.status}</p>
              </Card>
            </Link>
          ))}
        </Section>
      ) : null}

      {tab === "teams" ? (
        <Section
          loading={teamsQ.isLoading}
          empty={!teamsQ.data?.length}
          emptyTitle="No teams yet"
        >
          {(teamsQ.data ?? []).slice(0, 30).map((t) => (
            <Link key={t.id} href={`/teams/${t.id}`} className="block">
              <Card className="mb-2 p-4 hover:bg-muted/40">
                <p className="font-semibold">{t.name}</p>
              </Card>
            </Link>
          ))}
        </Section>
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
        <Card className="space-y-2 p-4">
          <p className="font-semibold">Highlights</p>
          <p className="text-sm text-muted-foreground">
            Clip highlights appear on match pages when published. Open a completed match
            to watch.
          </p>
          <Link href="/matches?status=completed" className="text-sm text-primary">
            Browse completed matches →
          </Link>
        </Card>
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
