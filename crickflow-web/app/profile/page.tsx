"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { useQuery } from "@tanstack/react-query";
import { EntityCard, MatchCard } from "@/components/shared/cards";
import { LoadingPage } from "@/components/shared/page-shell";
import { useAuth } from "@/features/auth/auth-provider";
import { GuestProfileSignIn, PlayerProfileView, teamsForPlayer } from "@/features/profiles/player-profile-view";
import { matchInvolvesPlayer } from "@/lib/cricket/events";
import { locationLabel } from "@/lib/cricket/format";
import {
  getPlayerByUserId,
  listCommunityPosts,
  listFollowedMatches,
  listFollowedPlayers,
  listFollowedTeams,
  listMatches,
  listOpportunities,
  listSavedCommunityPosts,
  listSavedOpportunityPosts,
  listTeams,
} from "@/repositories";

export default function ProfilePage() {
  const { user, profile, loading } = useAuth();
  const player = useQuery({
    queryKey: ["my-player", user?.uid],
    queryFn: () => getPlayerByUserId(user!.uid),
    enabled: Boolean(user),
  });

  const allTeams = useQuery({
    queryKey: ["profile-teams"],
    queryFn: () => listTeams(100),
    enabled: Boolean(user),
  });
  const myTeams = teamsForPlayer(allTeams.data, player.data);

  const allMatches = useQuery({
    queryKey: ["profile-matches", player.data?.id],
    queryFn: () => listMatches({ take: 100 }),
    enabled: Boolean(user && player.data),
  });
  const recentMatches = player.data
    ? (allMatches.data ?? []).filter((match) => matchInvolvesPlayer(match, player.data!.id)).slice(0, 8)
    : [];

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

  if (loading) return <LoadingPage title="Loading profile" />;
  if (!user) return <GuestProfileSignIn />;

  const name = profile?.displayName || profile?.name || "CrickFlow User";
  const linked = player.data;

  return (
    <PlayerProfileView
      name={name}
      photoUrl={profile?.photoUrl || linked?.photoUrl}
      playerId={linked?.playerId || profile?.playerId}
      role={profile?.playingRole || linked?.role}
      battingStyle={profile?.battingStyle || linked?.battingStyle}
      bowlingStyle={profile?.bowlingStyle || linked?.bowlingStyle}
      locationText={locationLabel(profile?.location ?? linked?.location)}
      country={linked?.country}
      bio={profile?.bio}
      stats={linked?.stats}
      teams={myTeams}
      recentMatches={recentMatches}
      isOwner
      viewerUserId={user.uid}
      profileUserId={user.uid}
      email={profile?.email || user.email}
      phoneNumber={profile?.phoneNumber || user.phoneNumber}
      dateOfBirth={profile?.dateOfBirth}
      gender={profile?.gender}
      playerDocId={linked?.id}
      sharePath={linked ? `/players/${linked.id}` : "/profile"}
      loadingTeams={allTeams.isPending}
      loadingMatches={Boolean(linked) && allMatches.isPending}
      showAccountDetails
    >
      {!profile?.onboardingCompleted ? (
        <p className="text-sm">
          <Link className="text-primary" href="/register">
            Complete your profile
          </Link>
        </p>
      ) : null}

      <section>
        <h2 className="text-xl font-bold">Following</h2>
        <div className="mt-4 space-y-4">
          {followedTeams.data?.length ? (
            <div className="grid gap-3 md:grid-cols-2">
              {followedTeams.data.map((team) => (
                <EntityCard key={team.id} href={`/teams/${team.id}`} title={team.name} image={team.logoUrl} />
              ))}
            </div>
          ) : (
            <p className="text-sm text-muted-foreground">Teams you follow appear here.</p>
          )}
          {followedPlayers.data?.length ? (
            <div className="grid gap-3 md:grid-cols-2">
              {followedPlayers.data.map((person) => (
                <EntityCard
                  key={person.id}
                  href={`/players/${person.id}`}
                  title={person.name || "Player"}
                  image={person.photoUrl}
                />
              ))}
            </div>
          ) : null}
        </div>
      </section>

      <section>
        <h2 className="text-xl font-bold">Followed matches</h2>
        {followedMatches.data?.length ? (
          <div className="mt-4 grid gap-4 md:grid-cols-2">
            {followedMatches.data.map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </div>
        ) : (
          <p className="mt-3 text-sm text-muted-foreground">Matches you follow appear here.</p>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">Your posts</h2>
        {myPosts.data?.length ? (
          <div className="mt-4 grid gap-3">
            {myPosts.data.map((post) => (
              <EntityCard key={post.id} href={`/community/${post.id}`} title={post.title || "Post"} subtitle={post.authorName} meta={post.body} />
            ))}
          </div>
        ) : (
          <p className="mt-3 text-sm text-muted-foreground">
            Posts you publish in Community appear here.{" "}
            <Link className="text-primary" href="/community">Open Community</Link>
          </p>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">Your listings</h2>
        {myListings.data?.length ? (
          <div className="mt-4 grid gap-3">
            {myListings.data.map((post) => (
              <EntityCard key={post.id} href={`/discover/${post.id}`} title={post.title || "Listing"} subtitle={post.authorName} meta={post.description} />
            ))}
          </div>
        ) : (
          <p className="mt-3 text-sm text-muted-foreground">
            Listings you publish on Discover appear here.{" "}
            <Link className="text-primary" href="/discover">Open Discover</Link>
          </p>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">Saved community</h2>
        {savedCommunity.isPending ? (
          <p className="mt-3 text-sm text-muted-foreground">Loading…</p>
        ) : savedCommunity.data?.length ? (
          <div className="mt-4 grid gap-3">
            {savedCommunity.data.map((post) => (
              <EntityCard key={post.id} href={`/community/${post.id}`} title={post.title || "Post"} subtitle={post.authorName} meta={post.body} />
            ))}
          </div>
        ) : (
          <p className="mt-3 text-sm text-muted-foreground">
            Save a post from Community to see it here.{" "}
            <Link className="text-primary" href="/community">Open Community</Link>
          </p>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">Saved Discover</h2>
        {savedDiscover.isPending ? (
          <p className="mt-3 text-sm text-muted-foreground">Loading…</p>
        ) : savedDiscover.data?.length ? (
          <div className="mt-4 grid gap-3">
            {savedDiscover.data.map((post) => (
              <EntityCard key={post.id} href={`/discover/${post.id}`} title={post.title || "Listing"} subtitle={post.authorName} meta={post.description} />
            ))}
          </div>
        ) : (
          <p className="mt-3 text-sm text-muted-foreground">
            Bookmark a listing on Discover to see it here.{" "}
            <Link className="text-primary" href="/discover">Open Discover</Link>
          </p>
        )}
      </section>
    </PlayerProfileView>
  );
}
