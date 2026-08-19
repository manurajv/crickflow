"use client";

import type { ReactNode } from "react";
import { useEffect, useState } from "react";
import Link from "next/link";
import { MatchCard, EntityCard } from "@/components/shared/cards";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import { locationLabel } from "@/lib/cricket/format";
import { isFirebaseConfigured } from "@/lib/firebase/client";
import { siteConfig } from "@/config/site";
import {
  listCommunityPosts,
  listFollowedPlayers,
  listFollowedTeams,
  listMatches,
  listPlayers,
  listPromotions,
  listTeams,
  listTournaments,
  watchLiveMatches,
} from "@/repositories";
import type { CommunityPost, HomePromotion, Match, Player, Team, Tournament } from "@/types/models";

export function HomeFeed() {
  const { user } = useAuth();
  const [ready, setReady] = useState(() => !isFirebaseConfigured());
  const [live, setLive] = useState<Match[]>([]);
  const [upcoming, setUpcoming] = useState<Match[]>([]);
  const [recent, setRecent] = useState<Match[]>([]);
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [teams, setTeams] = useState<Team[]>([]);
  const [players, setPlayers] = useState<Player[]>([]);
  const [posts, setPosts] = useState<CommunityPost[]>([]);
  const [promotions, setPromotions] = useState<HomePromotion[]>([]);
  const [followedTeams, setFollowedTeams] = useState<Team[]>([]);
  const [followedPlayers, setFollowedPlayers] = useState<Player[]>([]);

  useEffect(() => {
    if (!isFirebaseConfigured()) {
      return;
    }
    Promise.all([
      listMatches({ status: ["scheduled", "tossCompleted"], take: 8 }),
      listMatches({ status: "completed", take: 8 }),
      listTournaments(8),
      listTeams(8),
      listPlayers(8),
      listCommunityPosts({ take: 6 }),
      listPromotions(),
    ]).then(([nextUpcoming, nextRecent, nextTournaments, nextTeams, nextPlayers, nextPosts, nextPromos]) => {
      setUpcoming(nextUpcoming);
      setRecent(nextRecent);
      setTournaments(nextTournaments);
      setTeams(nextTeams);
      setPlayers(nextPlayers);
      setPosts(nextPosts);
      setPromotions(nextPromos);
    }).catch(() => undefined).finally(() => setReady(true));
  }, []);

  useEffect(() => {
    if (!isFirebaseConfigured()) return;
    return watchLiveMatches(setLive, 8);
  }, []);

  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    Promise.all([listFollowedTeams(user.uid), listFollowedPlayers(user.uid)])
      .then(([nextTeams, nextPlayers]) => {
        if (cancelled) return;
        setFollowedTeams(nextTeams);
        setFollowedPlayers(nextPlayers);
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, [user]);

  if (!isFirebaseConfigured()) {
    return (
      <EmptyState
        title="Firebase is not configured"
        description="Copy crickflow-web/.env.example to .env.local"
      />
    );
  }

  if (!ready) {
    return (
      <div className="space-y-12">
        <Hero />
        <p>Loading live cricket…</p>
      </div>
    );
  }

  const broadcasts = live.filter((m) => Boolean(m.stream.youtubeWatchUrl) || m.stream.status === "live");
  const followedTeamIds = new Set(followedTeams.map((team) => team.id));
  const yourMatches = user
    ? [...live, ...upcoming, ...recent].filter(
        (match) =>
          (match.teamAId && followedTeamIds.has(match.teamAId)) ||
          (match.teamBId && followedTeamIds.has(match.teamBId)),
      )
    : [];
  const showFollowing = Boolean(user) && (followedTeams.length > 0 || followedPlayers.length > 0 || yourMatches.length > 0);

  return (
    <div className="space-y-12">
      <Hero />
      {promotions.length > 0 ? (
        <section className="grid gap-4 md:grid-cols-3">
          {promotions.map((promo) => (
            <a key={promo.id} href={promo.redirectUrl || "/"} className="rounded-2xl border border-border bg-card p-5">
              <p className="text-xs uppercase text-muted-foreground">{promo.kind}</p>
              <h3 className="mt-1 font-semibold">{promo.title}</h3>
              <p className="mt-1 text-sm text-muted-foreground">{promo.description}</p>
            </a>
          ))}
        </section>
      ) : null}

      {showFollowing ? (
        <Section title="Following" href="/profile">
          {yourMatches.length > 0 ? (
            <Grid>
              {yourMatches.slice(0, 6).map((match) => (
                <MatchCard key={match.id} match={match} />
              ))}
            </Grid>
          ) : null}
          {followedTeams.length > 0 ? (
            <div className="mt-4 grid gap-3 md:grid-cols-2">
              {followedTeams.slice(0, 6).map((team) => (
                <EntityCard
                  key={team.id}
                  href={`/teams/${team.id}`}
                  title={team.name}
                  subtitle={locationLabel(team.location)}
                  image={team.logoUrl}
                />
              ))}
            </div>
          ) : null}
          {followedPlayers.length > 0 ? (
            <div className="mt-4 grid gap-3 md:grid-cols-2">
              {followedPlayers.slice(0, 6).map((player) => (
                <EntityCard
                  key={player.id}
                  href={`/players/${player.id}`}
                  title={player.name}
                  subtitle={player.role || player.playerId}
                  image={player.photoUrl}
                />
              ))}
            </div>
          ) : null}
        </Section>
      ) : user ? (
        <Section title="Following" href="/teams">
          <EmptyState
            title="Follow teams and players"
            description="Matches from people you follow will appear here."
            action={
              <Link href="/teams" className="text-primary">
                Browse teams
              </Link>
            }
          />
        </Section>
      ) : null}

      <Section title="Live matches" href="/matches?status=live">
        {live.length === 0 ? (
          <EmptyState title="No live matches right now" description="Upcoming fixtures appear below." />
        ) : (
          <Grid>
            {live.map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </Grid>
        )}
      </Section>

      <Section title="Watch live" href="/matches">
        {broadcasts.length === 0 ? (
          <EmptyState title="No live broadcasts" description="When a match is streamed, Watch Live appears here." />
        ) : (
          <Grid>
            {broadcasts.map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </Grid>
        )}
      </Section>

      <Section title="Upcoming" href="/matches?status=upcoming">
        <Grid>
          {upcoming.map((match) => (
            <MatchCard key={match.id} match={match} />
          ))}
        </Grid>
      </Section>

      <Section title="Recent results" href="/matches?status=completed">
        <Grid>
          {recent.map((match) => (
            <MatchCard key={match.id} match={match} />
          ))}
        </Grid>
      </Section>

      <Section title="Tournaments" href="/tournaments">
        <Grid>
          {tournaments.map((t) => (
            <EntityCard
              key={t.id}
              href={`/tournaments/${t.id}`}
              title={t.name}
              subtitle={locationLabel(t.location)}
              image={t.bannerUrl}
              meta={String(t.status)}
            />
          ))}
        </Grid>
      </Section>

      <div className="grid gap-8 lg:grid-cols-2">
        <Section title="Featured teams" href="/teams">
          <div className="grid gap-3">
            {teams.map((t) => (
              <EntityCard
                key={t.id}
                href={`/teams/${t.id}`}
                title={t.name}
                subtitle={locationLabel(t.location)}
                image={t.logoUrl}
              />
            ))}
          </div>
        </Section>
        <Section title="Featured players" href="/players">
          <div className="grid gap-3">
            {players.map((p) => (
              <EntityCard
                key={p.id}
                href={`/players/${p.id}`}
                title={p.name}
                subtitle={p.role || p.playerId}
                image={p.photoUrl}
              />
            ))}
          </div>
        </Section>
      </div>

      <Section title="Community" href="/community">
        <Grid>
          {posts.map((post) => (
            <EntityCard
              key={post.id}
              href={`/community/${post.id}`}
              title={post.title || post.body.slice(0, 80)}
              subtitle={post.authorName}
              image={post.media[0]?.url}
            />
          ))}
        </Grid>
      </Section>
    </div>
  );
}

function Hero() {
  return (
    <section className="overflow-hidden rounded-3xl bg-scoreboard px-6 py-14 text-white md:px-12">
      <p className="text-sm font-semibold uppercase tracking-[0.2em] text-gold">CrickFlow Web</p>
      <h1 className="mt-3 max-w-3xl text-4xl font-black tracking-tight md:text-6xl">
        Live cricket for every ground, team, and tournament.
      </h1>
      <p className="mt-4 max-w-2xl text-lg text-white/80">
        Watch scores, follow players, discover games near you, and share match centres — the same CrickFlow ecosystem, built for the web.
      </p>
      <div className="mt-8 flex flex-wrap gap-3">
        <Button variant="gold" asChild>
          <Link href="/matches">Live matches</Link>
        </Button>
        <Button variant="outline" className="border-white/30 text-white hover:bg-white/10" asChild>
          <Link href="/discover">Discover cricket</Link>
        </Button>
        <Button variant="outline" className="border-white/30 text-white hover:bg-white/10" asChild>
          <a href={siteConfig.playStoreUrl} target="_blank" rel="noreferrer">
            Get the app
          </a>
        </Button>
      </div>
    </section>
  );
}

function Section({ title, href, children }: { title: string; href: string; children: ReactNode }) {
  return (
    <section>
      <div className="mb-4 flex items-end justify-between">
        <h2 className="text-2xl font-bold">{title}</h2>
        <Link href={href} className="text-sm font-semibold text-primary">
          View all
        </Link>
      </div>
      {children}
    </section>
  );
}

function Grid({ children }: { children: ReactNode }) {
  return <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">{children}</div>;
}
