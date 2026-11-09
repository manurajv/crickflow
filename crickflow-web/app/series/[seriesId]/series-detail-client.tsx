"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { FormEvent, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import {
  useCreateSeriesClub,
  useJoinClub,
  useProposeSeriesMatch,
  useProposeSeriesTournament,
  useMyLinkableTournaments,
  useSeriesAnnouncements,
  useSeriesAuditLogs,
  useSeriesCompetitions,
  useSeriesDetail,
} from "@/features/series/hooks";
import { seriesAuditActionLabel } from "@/features/series/repository";
import { usePathParam } from "@/lib/use-path-param";
import { OrgLeaderboard } from "@/features/series/org-leaderboard";
import { SIGN_IN_PROMPTS, loginUrl } from "@/lib/auth/guest-access";
import {
  matchTeamsError,
  orgActionLabel,
  orgCompetitionPolicyFromMap,
  orgStartMode,
  playableOrgTeams,
} from "@/lib/cricket/org-competition-access";
import {
  OrgDetailHeader,
  OrgDetailTabs,
  parseOrgTab,
  type OrgTabSlug,
} from "@/features/series/components/org-detail-shell";
import { shouldShowOrgWelcome, markOrgWelcomeSeen } from "@/features/series/org-welcome";

export function SeriesDetailPage() {
  const seriesId = usePathParam("seriesId", 1);
  const router = useRouter();
  const search = useSearchParams();
  const { user } = useAuth();
  const { data, isLoading } = useSeriesDetail(seriesId, user?.uid);
  const competitions = useSeriesCompetitions(seriesId);
  const announcements = useSeriesAnnouncements(seriesId);
  const audit = useSeriesAuditLogs(seriesId, Boolean(data?.canManage));
  const createClub = useCreateSeriesClub(seriesId);
  const joinClub = useJoinClub(seriesId);
  const proposeMatch = useProposeSeriesMatch(seriesId);
  const proposeTournament = useProposeSeriesTournament(seriesId);
  const linkable = useMyLinkableTournaments(user?.uid);

  const [clubAId, setClubAId] = useState("");
  const [clubBId, setClubBId] = useState("");
  const [tournamentId, setTournamentId] = useState("");
  const [clubName, setClubName] = useState("");
  const [joinClubId, setJoinClubId] = useState("");
  const [joinName, setJoinName] = useState("");
  const [welcomeDismissed, setWelcomeDismissed] = useState(false);
  const [dontShowAgain, setDontShowAgain] = useState(false);

  const activeTab: OrgTabSlug = parseOrgTab(search.get("tab"));

  const uid = user?.uid;
  const canManage = Boolean(data?.canManage);
  const welcomeFlag = search.get("welcome") === "1";
  const welcomeOpen =
    !welcomeDismissed &&
    canManage &&
    Boolean(uid && seriesId) &&
    shouldShowOrgWelcome(uid || "", seriesId || "", welcomeFlag);

  const access = useMemo(() => {
    if (!data) return null;
    const policy = orgCompetitionPolicyFromMap(data.series.competitionPolicy);
    return {
      role: data.myRole,
      policy,
      myTeamIds: data.myTeamIds,
    };
  }, [data]);

  if (!seriesId || isLoading) return <p>Loading…</p>;
  if (!data || !access) return <EmptyState title="Organization not available" description="It may have been removed." />;

  const { series, clubs } = data;
  const playable = playableOrgTeams(clubs.filter((c) => c.status === "approved"));
  const matchMode = orgStartMode(access, false);
  const tournamentMode = orgStartMode(access, true);
  const showMatchFab = matchMode !== "none" && activeTab === "matches";
  const showTournamentFab = tournamentMode !== "none" && activeTab === "tournaments";
  const showTeamFab = activeTab === "teams";

  const matchComps = (competitions.data ?? []).filter(
    (c) => c.type === "singleMatch" || c.type === "match",
  );
  const tournamentComps = (competitions.data ?? []).filter(
    (c) => c.type === "tournament",
  );

  async function dismissWelcome(goSettings: boolean) {
    if (user?.uid && seriesId) {
      markOrgWelcomeSeen(user.uid, seriesId, dontShowAgain);
    }
    setWelcomeDismissed(true);
    if (goSettings) router.push(`/series/${seriesId}/settings`);
    else if (search.get("welcome") === "1") {
      router.replace(`/series/${seriesId}?tab=overview`);
    }
  }

  return (
    <div className="relative space-y-6 pb-24">
      <OrgDetailHeader
        series={series}
        canManage={data.canManage}
        pendingApprovalCount={data.pendingApprovalCount}
      />
      <OrgDetailTabs seriesId={seriesId} active={activeTab} />

      {activeTab === "overview" ? (
        <div className="space-y-5">
          {(series.status !== "active" || false) && (
            <Card className="border-amber-500/40 bg-amber-500/10 p-4 text-sm">
              Status: {series.status}
            </Card>
          )}
          {data.canManage ? (
            <Card className="flex flex-wrap items-center justify-between gap-3 bg-[color:var(--accent-soft)] p-4">
              <div>
                <p className="font-bold">Pending approvals</p>
                <p className="text-sm text-muted-foreground">
                  {data.pendingApprovalCount === 0
                    ? "All caught up"
                    : `${data.pendingApprovalCount} waiting for review`}
                </p>
              </div>
              <Button asChild variant="outline">
                <Link href={`/series/${seriesId}/approvals`}>Review</Link>
              </Button>
            </Card>
          ) : null}
          <p className="text-base text-foreground">
            {series.description || `Official CrickFlow ${series.kind}`}
          </p>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              [series.clubCount, "Teams"],
              [series.playerCount, "Players"],
              [series.matchCount, "Matches"],
              [series.tournamentCount, "Tournaments"],
            ].map(([n, label]) => (
              <Card key={String(label)} className="p-4 text-center">
                <p className="text-2xl font-black">{n as number}</p>
                <p className="text-xs text-muted-foreground">{label as string}</p>
              </Card>
            ))}
          </div>
          <div>
            <div className="mb-2 flex items-center justify-between">
              <h2 className="text-lg font-bold">Latest announcements</h2>
              <Link
                href={`/series/${seriesId}/announcements`}
                className="text-sm text-primary"
              >
                See all
              </Link>
            </div>
            {!announcements.data?.length ? (
              <p className="text-sm text-muted-foreground">No announcements yet</p>
            ) : (
              <div className="space-y-2">
                {announcements.data.slice(0, 2).map((a) => (
                  <Card key={a.id} className="space-y-1 p-4">
                    <p className="font-semibold">{a.title}</p>
                    <p className="text-sm text-muted-foreground line-clamp-3">{a.body}</p>
                    <p className="text-xs text-muted-foreground">
                      {a.createdByName || "Organizer"}
                      {a.createdAt ? ` · ${new Date(a.createdAt).toLocaleDateString()}` : ""}
                    </p>
                  </Card>
                ))}
              </div>
            )}
          </div>
          <Card className="p-0">
            <Link
              href={`/series/${seriesId}/my-requests`}
              className="flex items-center justify-between p-4 hover:bg-muted/50"
            >
              <div>
                <p className="font-semibold">My requests</p>
                <p className="text-sm text-muted-foreground">
                  Track join and registration status
                </p>
              </div>
              <span aria-hidden>›</span>
            </Link>
          </Card>
          {data.canManage ? (
            <>
              <Card className="p-0">
                <Link
                  href={`/series/${seriesId}/admins`}
                  className="flex items-center justify-between p-4 hover:bg-muted/50"
                >
                  <p className="font-semibold">Admins</p>
                  <span aria-hidden>›</span>
                </Link>
              </Card>
              <div>
                <div className="mb-2 flex items-center justify-between">
                  <h2 className="text-lg font-bold">Recent activity</h2>
                  <Link href={`/series/${seriesId}/admins`} className="text-sm text-primary">
                    See all
                  </Link>
                </div>
                {!audit.data?.length ? (
                  <p className="text-sm text-muted-foreground">No activity yet</p>
                ) : (
                  <ul className="space-y-2">
                    {audit.data.slice(0, 5).map((log) => (
                      <li key={log.id} className="text-sm">
                        <span className="font-medium">
                          {seriesAuditActionLabel(log.action)}
                        </span>
                        <span className="text-muted-foreground">
                          {log.timestamp
                            ? ` · ${new Date(log.timestamp).toLocaleString()}`
                            : ""}
                        </span>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
              <Button asChild variant="outline">
                <Link href={`/series/${seriesId}/settings`}>Settings & permissions</Link>
              </Button>
            </>
          ) : null}
        </div>
      ) : null}

      {activeTab === "matches" ? (
        <div className="space-y-4">
          {!matchComps.length ? (
            <EmptyState title="No matches yet" />
          ) : (
            matchComps.map((c) => (
              <Card key={c.id} className="flex flex-wrap items-center justify-between gap-2 p-4">
                <div>
                  <p className="font-bold">{c.title || "Match"}</p>
                  <p className="text-sm text-muted-foreground">
                    {c.status === "pendingApproval" ? "Pending approval" : c.status}
                  </p>
                </div>
                {c.matchId ? (
                  <Link href={`/matches/${c.matchId}`} className="text-sm text-primary">
                    Open
                  </Link>
                ) : null}
              </Card>
            ))
          )}
          {showMatchFab ? (
            <Card className="space-y-3 p-4">
              <h3 className="font-semibold">{orgActionLabel(matchMode, false)}</h3>
              <form
                className="grid gap-3 md:grid-cols-3"
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!user) {
                    router.push(loginUrl(`/series/${seriesId}?tab=matches`, "propose_match"));
                    return;
                  }
                  const err = matchTeamsError(access, clubAId, clubBId);
                  if (err) {
                    window.alert(err);
                    return;
                  }
                  await proposeMatch.mutateAsync({ clubAId, clubBId });
                  setClubAId("");
                  setClubBId("");
                }}
              >
                <select
                  className="rounded-md border border-border bg-background px-3 py-2"
                  value={clubAId}
                  onChange={(e) => setClubAId(e.target.value)}
                  required
                >
                  <option value="">Team A</option>
                  {playable.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
                <select
                  className="rounded-md border border-border bg-background px-3 py-2"
                  value={clubBId}
                  onChange={(e) => setClubBId(e.target.value)}
                  required
                >
                  <option value="">Team B</option>
                  {playable.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
                <Button type="submit" disabled={proposeMatch.isPending}>
                  {proposeMatch.isPending ? "…" : orgActionLabel(matchMode, false)}
                </Button>
              </form>
            </Card>
          ) : null}
        </div>
      ) : null}

      {activeTab === "tournaments" ? (
        <div className="space-y-4">
          {!tournamentComps.length ? (
            <EmptyState title="No tournaments yet" />
          ) : (
            tournamentComps.map((c) => (
              <Card key={c.id} className="flex flex-wrap items-center justify-between gap-2 p-4">
                <div>
                  <p className="font-bold">{c.title || "Tournament"}</p>
                  <p className="text-sm text-muted-foreground">{c.status}</p>
                </div>
                {c.tournamentId ? (
                  <Link href={`/tournaments/${c.tournamentId}`} className="text-sm text-primary">
                    Open
                  </Link>
                ) : null}
              </Card>
            ))
          )}
          {showTournamentFab ? (
            <Card className="space-y-3 p-4">
              <h3 className="font-semibold">{orgActionLabel(tournamentMode, true)}</h3>
              <form
                className="flex flex-wrap gap-3"
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!user) {
                    router.push(
                      loginUrl(`/series/${seriesId}?tab=tournaments`, "propose_tournament"),
                    );
                    return;
                  }
                  const picked = (linkable.data ?? []).find((t) => t.id === tournamentId);
                  await proposeTournament.mutateAsync({
                    tournamentId,
                    title: picked?.name,
                  });
                  setTournamentId("");
                }}
              >
                <select
                  className="min-w-[220px] flex-1 rounded-md border border-border bg-background px-3 py-2"
                  value={tournamentId}
                  onChange={(e) => setTournamentId(e.target.value)}
                  required
                >
                  <option value="">Add one of your tournaments</option>
                  {(linkable.data ?? []).map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.name}
                    </option>
                  ))}
                </select>
                <Button type="submit" disabled={proposeTournament.isPending || !tournamentId}>
                  {proposeTournament.isPending
                    ? "…"
                    : orgActionLabel(tournamentMode, true)}
                </Button>
              </form>
            </Card>
          ) : null}
        </div>
      ) : null}

      {activeTab === "teams" ? (
        <div className="space-y-4">
          {!clubs.length ? (
            <EmptyState title="No teams yet" />
          ) : (
            clubs.map((c) => (
              <Card key={c.id} className="p-4">
                <p className="font-bold">{c.name}</p>
                <p className="text-sm text-muted-foreground">
                  {c.status} · {c.squadCount} players
                </p>
              </Card>
            ))
          )}
          {showTeamFab ? (
            <Card className="space-y-3 p-4">
              {!user ? (
                <>
                  <p className="text-sm text-muted-foreground">{SIGN_IN_PROMPTS.create_org_team}</p>
                  <Button asChild>
                    <Link href={loginUrl(`/series/${seriesId}?tab=teams`, "create_org_team")}>
                      Sign in
                    </Link>
                  </Button>
                </>
              ) : (
                <form
                  className="flex flex-wrap gap-2"
                  onSubmit={async (e: FormEvent) => {
                    e.preventDefault();
                    await createClub.mutateAsync({ name: clubName });
                    setClubName("");
                  }}
                >
                  <input
                    className="min-w-[200px] flex-1 rounded-md border border-border bg-background px-3 py-2"
                    placeholder="New team name"
                    value={clubName}
                    onChange={(e) => setClubName(e.target.value)}
                    required
                  />
                  <Button type="submit" disabled={createClub.isPending}>
                    {createClub.isPending ? "…" : "+ Team"}
                  </Button>
                </form>
              )}
              {user ? (
                <form
                  className="flex flex-wrap gap-2 border-t border-border pt-3"
                  onSubmit={async (e) => {
                    e.preventDefault();
                    if (!joinClubId || !joinName.trim()) return;
                    await joinClub.mutateAsync({
                      clubId: joinClubId,
                      fullName: joinName.trim(),
                      crickFlowPlayerId: user.uid,
                    });
                    setJoinName("");
                  }}
                >
                  <select
                    className="rounded-md border border-border bg-background px-3 py-2"
                    value={joinClubId}
                    onChange={(e) => setJoinClubId(e.target.value)}
                    required
                  >
                    <option value="">Join a team</option>
                    {clubs
                      .filter((c) => c.status === "approved")
                      .map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                        </option>
                      ))}
                  </select>
                  <input
                    className="rounded-md border border-border bg-background px-3 py-2"
                    placeholder="Your name"
                    value={joinName}
                    onChange={(e) => setJoinName(e.target.value)}
                    required
                  />
                  <Button type="submit" variant="outline" disabled={joinClub.isPending}>
                    Request to join
                  </Button>
                </form>
              ) : null}
            </Card>
          ) : null}
        </div>
      ) : null}

      {activeTab === "leaderboard" ? (
        <OrgLeaderboard
          seriesId={seriesId}
          clubs={clubs}
          rules={series.settings.rankingRules}
          canManage={data.canManage}
        />
      ) : null}

      {activeTab === "about" ? (
        <div className="space-y-4">
          <Card className="space-y-2 p-4">
            <h2 className="font-bold">About</h2>
            <p>{series.description || "No description yet."}</p>
          </Card>
          {series.rulesText ? (
            <Card className="space-y-2 p-4">
              <h2 className="font-bold">Rules / playing conditions</h2>
              <p className="whitespace-pre-wrap text-sm">{series.rulesText}</p>
            </Card>
          ) : null}
          <p className="text-sm text-muted-foreground">
            Max team squad: {series.settings.maxSquadSize}
          </p>
        </div>
      ) : null}

      {welcomeOpen ? (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 p-4 sm:items-center">
          <Card className="w-full max-w-md space-y-4 p-6">
            <h2 className="text-xl font-bold">Welcome to your organization</h2>
            <p className="text-sm text-muted-foreground">
              Go to Settings to set who can propose matches and tournaments, whether
              requests need approval, and walk-in players — the same controls as the app.
            </p>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={dontShowAgain}
                onChange={(e) => setDontShowAgain(e.target.checked)}
              />
              Don&apos;t show this again
            </label>
            <div className="flex flex-wrap gap-2">
              <Button onClick={() => dismissWelcome(true)}>Go to settings</Button>
              <Button variant="outline" onClick={() => dismissWelcome(false)}>
                Later
              </Button>
            </div>
          </Card>
        </div>
      ) : null}
    </div>
  );
}
