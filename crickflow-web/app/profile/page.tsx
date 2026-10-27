"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { useQuery } from "@tanstack/react-query";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { EntityCard, MatchCard } from "@/components/shared/cards";
import { useAuth } from "@/features/auth/auth-provider";
import { locationLabel } from "@/lib/cricket/format";
import { getPlayerByUserId, listCommunityPosts, listFollowedMatches, listFollowedPlayers, listFollowedTeams, listMatches, listOpportunities, listSavedCommunityPosts, listSavedOpportunityPosts, listTeams, listTournaments } from "@/repositories";

export default function ProfilePage() {
  const { user, profile, loading } = useAuth();
  const player = useQuery({
    queryKey: ["my-player", user?.uid],
    queryFn: () => getPlayerByUserId(user!.uid),
    enabled: Boolean(user),
  });
  
  // My teams (where user is a member)
  const allTeams = useQuery({
    queryKey: ["all-teams-for-my"],
    queryFn: () => listTeams(100),
    enabled: Boolean(user && profile?.playerId),
  });
  const myTeams = allTeams.data?.filter(t => t.playerIds.includes(profile?.playerId || "")) || [];
  
  // My tournaments (created or participating)
  const allTournaments = useQuery({
    queryKey: ["all-tournaments-for-my"],
    queryFn: () => listTournaments(100),
    enabled: Boolean(user),
  });
  const myTournaments = allTournaments.data?.filter(t => 
    t.createdBy === user?.uid || 
    myTeams.some(team => t.teamIds.includes(team.id))
  ) || [];
  
  // My matches (participated or created)
  const allMatches = useQuery({
    queryKey: ["all-matches-for-my"],
    queryFn: () => listMatches({ take: 100 }),
    enabled: Boolean(user),
  });
  const myMatches = allMatches.data?.filter(m => 
    m.createdBy === user?.uid ||
    m.teamAId && myTeams.some(t => t.id === m.teamAId) ||
    m.teamBId && myTeams.some(t => t.id === m.teamBId)
  ) || [];

  const followedTeams = useQuery({
    queryKey: ["followed-teams", user?.uid],
    queryFn: () => listFollowedTeams(user!.uid),
    enabled: Boolean(user),
  });
  const followedPlayers = useQuery({
    queryKey: ["followed-players", user?.uid],
    queryFn: () => listFollowedPlayers(user!.uid),
    enabled: Boolean(user),
  });
  const savedCommunity = useQuery({
    queryKey: ["saved-community", user?.uid],
    queryFn: () => listSavedCommunityPosts(user!.uid),
    enabled: Boolean(user),
  });
  const savedDiscover = useQuery({
    queryKey: ["saved-discover", user?.uid],
    queryFn: () => listSavedOpportunityPosts(user!.uid),
    enabled: Boolean(user),
  });
  const followedMatches = useQuery({
    queryKey: ["followed-matches", user?.uid],
    queryFn: () => listFollowedMatches(user!.uid),
    enabled: Boolean(user),
  });
  const myPosts = useQuery({
    queryKey: ["my-community", user?.uid],
    queryFn: () => listCommunityPosts({ authorId: user!.uid, take: 12 }),
    enabled: Boolean(user),
  });
  const myListings = useQuery({
    queryKey: ["my-discover", user?.uid],
    queryFn: () => listOpportunities({ authorId: user!.uid, take: 12 }),
    enabled: Boolean(user),
  });

  if (loading) return <p>Loading…</p>;
  if (!user) {
    return <EmptyState title="Sign in to view your profile" action={<Link href="/login">Sign in</Link>} />;
  }
  const linked = player.data;
  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <Card className="p-6">
        <div className="flex items-start gap-4">
          {profile?.photoUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={profile.photoUrl} alt="" className="h-16 w-16 rounded-full object-cover" />
          ) : null}
          <div>
            <h1 className="text-3xl font-bold">{profile?.displayName || profile?.name || "CrickFlow User"}</h1>
            <p className="text-muted-foreground">{profile?.email || user.email || user.phoneNumber}</p>
            <p className="mt-2 text-sm">{linked?.playerId || profile?.playerId}</p>
            {profile?.playingRole && (
              <p className="mt-1 text-sm text-muted-foreground">
                {profile.playingRole}
                {profile.battingStyle && ` · ${profile.battingStyle}`}
                {profile.bowlingStyle && ` · ${profile.bowlingStyle}`}
              </p>
            )}
          </div>
        </div>
        <p className="mt-4">{profile?.bio || "No bio yet."}</p>
        {!profile?.onboardingCompleted ? (
          <p className="mt-4 text-sm">
            <Link className="text-primary" href="/register">
              Complete your profile
            </Link>
          </p>
        ) : null}
        <div className="mt-6 flex gap-3 text-sm">
          <Link className="text-primary" href="/settings">
            Settings
          </Link>
          {linked ? (
            <Link className="text-primary" href={`/players/${linked.id}`}>
              Public cricket profile
            </Link>
          ) : null}
        </div>
      </Card>

      <section>
        <h2 className="text-xl font-bold">My Cricket</h2>
        <div className="mt-4 grid gap-3 md:grid-cols-3">
          <Card className="p-4">
            <p className="text-sm text-muted-foreground">Teams</p>
            <p className="text-2xl font-bold">{myTeams.length}</p>
          </Card>
          <Card className="p-4">
            <p className="text-sm text-muted-foreground">Tournaments</p>
            <p className="text-2xl font-bold">{myTournaments.length}</p>
          </Card>
          <Card className="p-4">
            <p className="text-sm text-muted-foreground">Matches</p>
            <p className="text-2xl font-bold">{myMatches.length}</p>
          </Card>
        </div>
      </section>

      <section>
        <h2 className="text-xl font-bold">My teams</h2>
        {myTeams.length ? (
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {myTeams.map((team) => (
              <EntityCard
                key={team.id}
                href={`/teams/${team.id}`}
                title={team.name}
                subtitle={locationLabel(team.location)}
                image={team.logoUrl}
                meta={`${team.stats.matchesWon} wins`}
              />
            ))}
          </div>
        ) : (
          <div className="mt-4">
            <EmptyState
              title="You are not in any teams yet"
              description="Create a team or get added by a captain."
              action={
                <Link className="text-primary" href="/teams">
                  Browse teams
                </Link>
              }
            />
          </div>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">My tournaments</h2>
        {myTournaments.length ? (
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {myTournaments.map((t) => (
              <EntityCard
                key={t.id}
                href={`/tournaments/${t.id}`}
                title={t.name}
                subtitle={locationLabel(t.location)}
                image={t.bannerUrl}
                meta={`${t.format} · ${t.status}`}
              />
            ))}
          </div>
        ) : (
          <div className="mt-4">
            <EmptyState
              title="You are not in any tournaments yet"
              description="Create a tournament or join with your team."
              action={
                <Link className="text-primary" href="/tournaments">
                  Browse tournaments
                </Link>
              }
            />
          </div>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">My matches</h2>
        {myMatches.length ? (
          <div className="mt-4 grid gap-3">
            {myMatches.slice(0, 10).map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </div>
        ) : (
          <p className="mt-4 text-sm text-muted-foreground">
            Matches you play, score, or stream appear here.{" "}
            <Link className="text-primary" href="/matches">
              Browse matches
            </Link>
          </p>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">Following</h2>
        {followedTeams.data?.length || followedPlayers.data?.length ? (
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {(followedTeams.data ?? []).map((team) => (
              <EntityCard
                key={team.id}
                href={`/teams/${team.id}`}
                title={team.name}
                subtitle={locationLabel(team.location)}
                image={team.logoUrl}
              />
            ))}
            {(followedPlayers.data ?? []).map((item) => (
              <EntityCard
                key={item.id}
                href={`/players/${item.id}`}
                title={item.name}
                subtitle={item.role || item.playerId}
                image={item.photoUrl}
              />
            ))}
          </div>
        ) : (
          <div className="mt-4">
            <EmptyState
              title="You are not following anyone yet"
              description="Follow teams and players from their profiles."
              action={
                <Link className="text-primary" href="/teams">
                  Browse teams
                </Link>
              }
            />
          </div>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">Followed matches</h2>
        {followedMatches.data?.length ? (
          <div className="mt-4 grid gap-3">
            {followedMatches.data.map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </div>
        ) : (
          <p className="mt-4 text-sm text-muted-foreground">
            Follow a match from Match Centre to pin it here.
          </p>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">My posts</h2>
        {myPosts.data?.length ? (
          <div className="mt-4 grid gap-3">
            {myPosts.data.map((post) => (
              <EntityCard
                key={post.id}
                href={`/community/${post.id}`}
                title={post.title || "Post"}
                subtitle={post.category}
                meta={post.body}
              />
            ))}
          </div>
        ) : (
          <p className="mt-4 text-sm text-muted-foreground">
            Posts you publish on Community appear here.
          </p>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">My listings</h2>
        {myListings.data?.length ? (
          <div className="mt-4 grid gap-3">
            {myListings.data.map((post) => (
              <EntityCard
                key={post.id}
                href={`/discover/${post.id}`}
                title={post.title || "Listing"}
                subtitle={post.category}
                meta={post.description}
              />
            ))}
          </div>
        ) : (
          <p className="mt-4 text-sm text-muted-foreground">
            Listings you publish on Discover appear here.
          </p>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">Saved community</h2>
        {savedCommunity.isPending ? (
          <p className="mt-4 text-sm text-muted-foreground">Loading…</p>
        ) : savedCommunity.data?.length ? (
          <div className="mt-4 grid gap-3">
            {savedCommunity.data.map((post) => (
              <EntityCard
                key={post.id}
                href={`/community/${post.id}`}
                title={post.title || "Post"}
                subtitle={post.authorName}
                meta={post.body}
              />
            ))}
          </div>
        ) : (
          <p className="mt-4 text-sm text-muted-foreground">
            Save a post from Community to see it here.{" "}
            <Link className="text-primary" href="/community">
              Open Community
            </Link>
          </p>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">Saved Discover</h2>
        {savedDiscover.isPending ? (
          <p className="mt-4 text-sm text-muted-foreground">Loading…</p>
        ) : savedDiscover.data?.length ? (
          <div className="mt-4 grid gap-3">
            {savedDiscover.data.map((post) => (
              <EntityCard
                key={post.id}
                href={`/discover/${post.id}`}
                title={post.title || "Listing"}
                subtitle={post.authorName}
                meta={post.description}
              />
            ))}
          </div>
        ) : (
          <p className="mt-4 text-sm text-muted-foreground">
            Bookmark a listing on Discover to see it here.{" "}
            <Link className="text-primary" href="/discover">
              Open Discover
            </Link>
          </p>
        )}
      </section>
    </div>
  );
}
