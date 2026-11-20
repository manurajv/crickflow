"use client";

import type { ReactNode } from "react";
import { AppLink as Link } from "@/components/shared/app-link";
import { loginUrl } from "@/lib/auth/guest-access";
import { EntityCard, MatchCard } from "@/components/shared/cards";
import { EmptyState } from "@/components/shared/states";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { FollowShare } from "@/features/profiles/follow-share";
import { StartChatButton } from "@/features/chat/start-chat";
import { battingAverage, locationLabel, strikeRate } from "@/lib/cricket/format";
import {
  canViewPrivateProfileFields,
  cfPlayerIdLabel,
  displayBattingStyle,
  displayBowlingStyle,
  displayCfPlayerId,
  displayPlayingRole,
  formatProfileDate,
  initialsForName,
  joinedLabel,
  roleStylesLine,
} from "@/lib/cricket/profile-display";
import { siteConfig } from "@/config/site";
import { toast } from "sonner";
import type { Match, Player, PlayerStats, Team, UserProfile } from "@/types/models";

type ProfileViewProps = {
  name: string;
  photoUrl?: string | null;
  playerId?: string | null;
  role?: string | null;
  battingStyle?: string | null;
  bowlingStyle?: string | null;
  locationText?: string;
  country?: string | null;
  joinedAt?: string | Date | null;
  bio?: string | null;
  stats?: PlayerStats | null;
  teams: Team[];
  recentMatches: Match[];
  isOwner: boolean;
  viewerUserId?: string | null;
  profileUserId?: string | null;
  /** Owner-only contact fields. Never pass these for a guest view. */
  email?: string | null;
  phoneNumber?: string | null;
  dateOfBirth?: string | null;
  gender?: string | null;
  playerDocId?: string | null;
  followId?: string;
  sharePath: string;
  loadingTeams?: boolean;
  loadingMatches?: boolean;
  /** When true, render the owner-only email / phone / date of birth card. */
  showAccountDetails?: boolean;
  /** Extra blocks for the signed-in account profile (followed, saved, etc.). */
  children?: ReactNode;
};

export function ProfileAvatar({
  name,
  photoUrl,
  size = "lg",
}: {
  name: string;
  photoUrl?: string | null;
  size?: "sm" | "lg";
}) {
  const dim = size === "lg" ? "h-24 w-24 text-3xl" : "h-16 w-16 text-xl";
  if (photoUrl) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={photoUrl}
        alt=""
        className={`${dim} shrink-0 rounded-full object-cover ring-2 ring-white/40`}
      />
    );
  }
  return (
    <div
      className={`${dim} flex shrink-0 items-center justify-center rounded-full bg-primary font-bold text-primary-foreground`}
      aria-hidden
    >
      {initialsForName(name)}
    </div>
  );
}

function StatTile({ label, value }: { label: string; value: string | number }) {
  return (
    <Card className="p-4">
      <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">{label}</p>
      <p className="mt-1 text-2xl font-bold tabular-nums text-foreground">{value}</p>
    </Card>
  );
}

export function CareerStatsSection({ stats }: { stats?: PlayerStats | null }) {
  if (!stats) {
    return (
      <section>
        <h2 className="text-xl font-bold">Career stats</h2>
        <p className="mt-3 text-sm text-muted-foreground">No career stats yet.</p>
      </section>
    );
  }
  const s = stats;
  return (
    <section className="space-y-4">
      <h2 className="text-xl font-bold">Career stats</h2>
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <StatTile label="Matches" value={s.matchesPlayed} />
        <StatTile label="Runs" value={s.runs} />
        <StatTile label="Wickets" value={s.wickets} />
        <StatTile label="Catches" value={s.catches} />
      </div>
      <div className="grid gap-3 md:grid-cols-3">
        <Card className="p-5">
          <h3 className="font-semibold text-primary">Batting</h3>
          <ul className="mt-2 space-y-1 text-sm text-muted-foreground">
            <li>High score {s.highScore}</li>
            <li>Fifties {s.fifties}</li>
            <li>Hundreds {s.hundreds}</li>
            <li>Strike rate {strikeRate(s.runs, s.ballsFaced)}</li>
            <li>Average {battingAverage(s.runs, s.dismissals)}</li>
          </ul>
        </Card>
        <Card className="p-5">
          <h3 className="font-semibold text-primary">Bowling</h3>
          <ul className="mt-2 space-y-1 text-sm text-muted-foreground">
            <li>Wickets {s.wickets}</li>
            <li>Runs conceded {s.runsConceded}</li>
            <li>3-fors {s.threeWickets}</li>
            <li>5-fors {s.fiveWickets}</li>
          </ul>
        </Card>
        <Card className="p-5">
          <h3 className="font-semibold text-primary">Fielding</h3>
          <ul className="mt-2 space-y-1 text-sm text-muted-foreground">
            <li>Catches {s.catches}</li>
            <li>Run outs {s.runOuts}</li>
            <li>Stumpings {s.stumpings}</li>
          </ul>
        </Card>
      </div>
    </section>
  );
}

export function PlayerProfileView(props: ProfileViewProps) {
  const {
    name,
    photoUrl,
    playerId,
    role,
    battingStyle,
    bowlingStyle,
    locationText,
    country,
    joinedAt,
    bio,
    stats,
    teams,
    recentMatches,
    isOwner,
    viewerUserId,
    profileUserId,
    email,
    phoneNumber,
    dateOfBirth,
    gender,
    playerDocId,
    followId,
    sharePath,
    loadingTeams,
    loadingMatches,
    showAccountDetails,
    children,
  } = props;

  const showPrivate =
    Boolean(showAccountDetails) && canViewPrivateProfileFields(viewerUserId, profileUserId);
  const idLabel = cfPlayerIdLabel(playerId);
  const styles = roleStylesLine({ role, battingStyle, bowlingStyle });
  const place = [locationText, country].filter(Boolean).join(" · ");

  async function copyId() {
    const id = displayCfPlayerId(playerId);
    if (!id) return;
    await navigator.clipboard.writeText(id);
    toast.success("CrickFlow ID copied");
  }

  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="overflow-hidden rounded-3xl border border-border bg-card shadow-sm">
        <div className="h-2 bg-gradient-to-r from-primary via-cricket to-gold" aria-hidden />
        <div className="flex flex-col gap-5 p-6 sm:flex-row sm:items-start">
          <ProfileAvatar name={name} photoUrl={photoUrl} />
          <div className="min-w-0 flex-1">
            <h1 className="text-3xl font-bold tracking-tight">{name}</h1>
            {idLabel ? (
              <p className="mt-1 flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
                <span className="font-medium tracking-wide">{idLabel}</span>
                <Button className="h-7 px-2 text-xs" size="sm" variant="outline" onClick={copyId}>
                  Copy ID
                </Button>
              </p>
            ) : (
              <p className="mt-1 text-sm text-muted-foreground">CrickFlow ID pending</p>
            )}
            {styles ? <p className="mt-2 text-sm font-medium text-foreground">{styles}</p> : null}
            <div className="mt-2 flex flex-wrap gap-2">
              {displayPlayingRole(role) ? <Badge variant="outline">{displayPlayingRole(role)}</Badge> : null}
              {displayBattingStyle(battingStyle) ? (
                <Badge variant="outline">{displayBattingStyle(battingStyle)}</Badge>
              ) : null}
              {displayBowlingStyle(bowlingStyle) ? (
                <Badge variant="outline">{displayBowlingStyle(bowlingStyle)}</Badge>
              ) : null}
            </div>
            {place ? <p className="mt-2 text-sm text-muted-foreground">{place}</p> : null}
            {joinedLabel(joinedAt) ? (
              <p className="text-sm text-muted-foreground">{joinedLabel(joinedAt)}</p>
            ) : null}
            {bio ? <p className="mt-3 text-sm leading-relaxed">{bio}</p> : null}
          </div>
        </div>
        <div className="flex flex-wrap gap-2 border-t border-border px-6 py-4">
          {isOwner ? (
            <>
              <Button asChild>
                <Link href="/profile/edit">Edit profile</Link>
              </Button>
              <Button variant="outline" asChild>
                <Link href="/settings">Settings</Link>
              </Button>
              {playerDocId ? (
                <Button variant="outline" asChild>
                  <Link href={`/players/${playerDocId}`}>Cricket profile</Link>
                </Button>
              ) : null}
            </>
          ) : (
            <>
              <FollowShare
                kind="player"
                id={followId || profileUserId || ""}
                title={name}
                path={sharePath}
                followedPlayerId={playerId || playerDocId || ""}
              />
              <StartChatButton
                otherId={profileUserId ?? undefined}
                otherName={name}
                otherPhotoUrl={photoUrl ?? undefined}
                otherPlayerId={playerId ?? undefined}
              />
            </>
          )}
        </div>
      </header>

      <CareerStatsSection stats={stats} />

      <section>
        <h2 className="text-xl font-bold">Teams</h2>
        {loadingTeams ? (
          <p className="mt-3 text-sm text-muted-foreground">Loading teams…</p>
        ) : teams.length ? (
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {teams.map((team) => (
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
          <p className="mt-3 text-sm text-muted-foreground">No teams yet.</p>
        )}
      </section>

      <section>
        <h2 className="text-xl font-bold">Recent matches</h2>
        {loadingMatches ? (
          <p className="mt-3 text-sm text-muted-foreground">Loading matches…</p>
        ) : recentMatches.length ? (
          <div className="mt-4 grid gap-4 md:grid-cols-2">
            {recentMatches.map((match) => (
              <MatchCard key={match.id} match={match} />
            ))}
          </div>
        ) : (
          <p className="mt-3 text-sm text-muted-foreground">No recent matches yet.</p>
        )}
      </section>

      {showPrivate ? (
        <section>
          <h2 className="text-xl font-bold">Account details</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Email, phone, and date of birth are only visible to you.
          </p>
          <Card className="mt-4 divide-y divide-border">
            <PrivateRow label="Email" value={email || "—"} />
            <PrivateRow label="Phone" value={phoneNumber || "—"} />
            <PrivateRow label="Date of birth" value={formatProfileDate(dateOfBirth) || "—"} />
            {gender ? <PrivateRow label="Gender" value={gender} /> : null}
          </Card>
        </section>
      ) : null}

      {!isOwner && playerDocId ? (
        <section>
          <h2 className="text-xl font-bold">Share</h2>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            alt={`QR for ${name}`}
            className="mt-3 h-32 w-32 rounded-2xl border border-border bg-white p-2"
            src={`https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${encodeURIComponent(`${siteConfig.url}${sharePath}`)}`}
          />
        </section>
      ) : null}

      {children}
    </div>
  );
}

function PrivateRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 px-4 py-3 text-sm">
      <span className="text-muted-foreground">{label}</span>
      <span className="font-semibold">{value}</span>
    </div>
  );
}

export function GuestProfileSignIn() {
  return (
    <EmptyState
      title="Sign in to view your profile"
      description="Browse matches and scorecards without an account. Sign in to follow players and build your cricket network."
      action={<Link href={loginUrl("/profile", "manage_profile")}>Sign in</Link>}
    />
  );
}

export function teamsForPlayer(teams: Team[] | undefined, player: Player | null | undefined): Team[] {
  if (!teams?.length || !player) return [];
  const memberIds = new Set([player.id, ...(player.teamIds ?? [])].filter(Boolean));
  return teams.filter(
    (team) =>
      team.playerIds.includes(player.id) ||
      (player.teamIds ?? []).includes(team.id) ||
      memberIds.has(team.id),
  );
}

export function mapUserToProfileFields(profile: UserProfile) {
  return {
    name: profile.displayName || profile.name || "CrickFlow User",
    photoUrl: profile.photoUrl,
    playerId: profile.playerId,
    role: profile.playingRole,
    battingStyle: profile.battingStyle,
    bowlingStyle: profile.bowlingStyle,
    locationText: locationLabel(profile.location),
    bio: profile.bio,
    email: profile.email,
    phoneNumber: profile.phoneNumber,
    dateOfBirth: profile.dateOfBirth,
    gender: profile.gender,
  };
}
