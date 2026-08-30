"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { MatchCard, EntityCard } from "@/components/shared/cards";
import { ContentGrid, LoadingGrid, PageSection } from "@/components/shared/page-shell";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import { locationLabel } from "@/lib/cricket/format";
import { isFirebaseConfigured } from "@/lib/firebase/client";
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
        <LoadingGrid count={6} />
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
            <a
              key={promo.id}
              href={promo.redirectUrl || "/"}
              className="rounded-2xl border border-border bg-card p-5 shadow-sm transition hover:border-primary/30 hover:shadow-md"
            >
              <p className="text-xs uppercase text-muted-foreground">{promo.kind}</p>
              <h3 className="mt-1 font-semibold">{promo.title}</h3>
              <p className="mt-1 text-sm text-muted-foreground">{promo.description}</p>
            </a>
          ))}
        </section>
      ) : null}

      {showFollowing ? (
        <PageSection title="Following" href="/profile">
          {yourMatches.length > 0 ? (
            <ContentGrid>
              {yourMatches.slice(0, 6).map((match) => (
                <MatchCard key={match.id} match={match} />
              ))}
            </ContentGrid>
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
        </PageSection>
      ) : user ? (
        <PageSection title="Following" href="/teams">
          <EmptyState
            title="Follow teams and players"
            description="Matches from people you follow will appear here."
            action={
              <Link href="/teams" className="text-primary">
                Browse teams
              </Link>
            }
          />
        </PageSection>
      ) : null}

      <PageSection title="Live matches" href="/matches?status=live">
        {live.length === 0 ? (
          <EmptyState title="No live matches right now" description="Upcoming fixtures appear below." />
        ) : (
          <ContentGrid>
            {live.map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </ContentGrid>
        )}
      </PageSection>

      <PageSection title="Watch live" href="/matches">
        {broadcasts.length === 0 ? (
          <EmptyState title="No live broadcasts" description="When a match is streamed, Watch Live appears here." />
        ) : (
          <ContentGrid>
            {broadcasts.map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </ContentGrid>
        )}
      </PageSection>

      <PageSection title="Upcoming" href="/matches?status=upcoming">
        <ContentGrid>
          {upcoming.map((match) => (
            <MatchCard key={match.id} match={match} />
          ))}
        </ContentGrid>
      </PageSection>

      <PageSection title="Recent results" href="/matches?status=completed">
        <ContentGrid>
          {recent.map((match) => (
            <MatchCard key={match.id} match={match} />
          ))}
        </ContentGrid>
      </PageSection>

      <PageSection title="Tournaments" href="/tournaments">
        <ContentGrid>
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
        </ContentGrid>
      </PageSection>

      <div className="grid gap-8 lg:grid-cols-2">
        <PageSection title="Featured teams" href="/teams">
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
        </PageSection>
        <PageSection title="Featured players" href="/players">
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
        </PageSection>
      </div>

      <PageSection title="Community" href="/community">
        <ContentGrid>
          {posts.map((post) => (
            <EntityCard
              key={post.id}
              href={`/community/${post.id}`}
              title={post.title || post.body.slice(0, 80)}
              subtitle={post.authorName}
              image={post.media[0]?.url}
            />
          ))}
        </ContentGrid>
      </PageSection>
    </div>
  );
}

function Hero() {
  return (
    <section className="relative overflow-hidden rounded-3xl bg-scoreboard bg-pitch-stripes px-6 py-14 text-white md:px-12">
      <div className="relative">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-gold">Live cricket platform</p>
        <h1 className="mt-3 max-w-3xl text-4xl font-black tracking-tight md:text-5xl lg:text-6xl">
          Scores, stats & stories from every ground.
        </h1>
        <p className="mt-4 max-w-2xl text-lg text-white/85">
          Follow live matches, register as a player, discover opportunities, and connect with teams — synced with the CrickFlow mobile app.
        </p>
        <div className="mt-8 flex flex-wrap gap-3">
          <Button variant="gold" size="lg" asChild>
            <Link href="/matches?status=live">Live scores</Link>
          </Button>
          <Button variant="outline" className="border-white/35 text-white hover:bg-white/10" asChild>
            <Link href="/register">Player registration</Link>
          </Button>
          <Button variant="outline" className="border-white/35 text-white hover:bg-white/10" asChild>
            <Link href="/discover">Discover cricket</Link>
          </Button>
        </div>
        <div className="mt-10 flex flex-wrap gap-6 border-t border-white/20 pt-6 text-sm text-white/75">
          <Link href="/rankings" className="hover:text-white">Rankings</Link>
          <Link href="/statistics" className="hover:text-white">Statistics</Link>
          <Link href="/tournaments" className="hover:text-white">Tournaments</Link>
          <Link href="/community" className="hover:text-white">Community</Link>
        </div>
      </div>
    </section>
  );
}
