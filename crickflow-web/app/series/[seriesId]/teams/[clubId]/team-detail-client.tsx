"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { FormEvent, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import { PlayerRegistrationForm } from "@/features/series/components/player-registration-form";
import {
  useAddClubAdmin,
  useAddPlayerToClub,
  useClubAdmins,
  useClubSquad,
  useJoinClub,
  useMyLinkableTournaments,
  useProposeSeriesMatch,
  useProposeSeriesTournament,
  useReviewClubJoinRequest,
  useSearchPlayersForOrg,
  useSeriesDetail,
} from "@/features/series/hooks";
import type { PlayerSearchHit } from "@/features/series/repository";
import { officialIdentityFromProfile } from "@/lib/cricket/official-identity";
import { canRequestToJoinOrgTeam } from "@/lib/cricket/official-identity";
import {
  matchTeamsError,
  orgActionLabel,
  orgCompetitionPolicyFromMap,
  orgStartMode,
} from "@/lib/cricket/org-competition-access";
import { loginUrl, SIGN_IN_PROMPTS } from "@/lib/auth/guest-access";
import { usePathParam } from "@/lib/use-path-param";
import { friendlyError } from "@/lib/friendly-error";

export function OrgTeamDetailPage() {
  const seriesId = usePathParam("seriesId", 1);
  const clubId = usePathParam("clubId", 3);
  const { user, profile } = useAuth();
  const { data, isLoading } = useSeriesDetail(seriesId, user?.uid);
  const squad = useClubSquad(seriesId, clubId);
  const admins = useClubAdmins(seriesId, clubId);
  const joinClub = useJoinClub(seriesId);
  const addPlayer = useAddPlayerToClub(seriesId, clubId);
  const addAdmin = useAddClubAdmin(seriesId, clubId);
  const searchPlayers = useSearchPlayersForOrg();
  const proposeMatch = useProposeSeriesMatch(seriesId);
  const proposeTournament = useProposeSeriesTournament(seriesId);
  const linkable = useMyLinkableTournaments(user?.uid);
  const clubReview = useReviewClubJoinRequest(seriesId);

  const [joinOpen, setJoinOpen] = useState(false);
  const [opponentId, setOpponentId] = useState("");
  const [tournamentId, setTournamentId] = useState("");
  const [addPlayerOpen, setAddPlayerOpen] = useState(false);
  const [addAdminOpen, setAddAdminOpen] = useState(false);
  const [searchQ, setSearchQ] = useState("");
  const [searchHits, setSearchHits] = useState<PlayerSearchHit[]>([]);
  const [selectedPlayer, setSelectedPlayer] = useState<PlayerSearchHit | null>(null);
  const [adminHits, setAdminHits] = useState<PlayerSearchHit[]>([]);
  const [actionError, setActionError] = useState("");

  const club = (data?.clubs ?? []).find((c) => c.id === clubId);
  const access = useMemo(() => {
    if (!data) return null;
    return {
      role: data.myRole,
      policy: orgCompetitionPolicyFromMap(data.series.competitionPolicy),
      myTeamIds: data.myTeamIds,
    };
  }, [data]);

  if (!seriesId || !clubId || isLoading) return <p>Loading…</p>;
  if (!data || !access) return <EmptyState title="Organization not available" />;
  if (!club) return <EmptyState title="Team not found" />;

  const isOrgAdmin = Boolean(data.isSuperAdmin || data.canManage);
  const isTeamAdmin = data.myAdminClubIds.includes(clubId);
  const canManage = isOrgAdmin || isTeamAdmin;
  const activeSquad = (squad.data ?? []).filter((m) => m.status === "active");
  const isOnSquad = Boolean(
    user && activeSquad.some((m) => m.userId === user.uid),
  ) || Boolean(user && !squad.data && data.myTeamIds.includes(clubId));
  const showJoin = canRequestToJoinOrgTeam({
    signedIn: Boolean(user),
    isApproved: club.status === "approved",
    isTeamAdmin,
    isOnSquad: Boolean(isOnSquad || (user && squad.isLoading && data.myTeamIds.includes(clubId))),
  });
  const matchMode = orgStartMode(access, false);
  const tournamentMode = orgStartMode(access, true);
  const playable = (data.clubs ?? []).filter((c) => c.status === "approved");
  const joinRequests = (data.approvals ?? []).filter((a) => {
    if (a.targetType !== "playerJoin") return false;
    const requestClub =
      (typeof a.clubId === "string" && a.clubId) ||
      (typeof a.metadata.clubId === "string" ? a.metadata.clubId : "");
    return requestClub === clubId && a.metadata.clubReviewStatus !== "approved";
  });
  const activeAdmins = (admins.data ?? []).filter((a) => a.status !== "removed");

  async function runSearch(forAdmin: boolean, value: string) {
    setSearchQ(value);
    if (value.trim().length < 2) {
      if (forAdmin) setAdminHits([]);
      else setSearchHits([]);
      return;
    }
    try {
      const hits = await searchPlayers.mutateAsync({
        query: value,
        currentUserId: user?.uid,
      });
      if (forAdmin) setAdminHits(hits);
      else setSearchHits(hits);
    } catch (err) {
      setActionError(friendlyError(err, "Could not search players"));
    }
  }

  return (
    <div className="space-y-6 pb-16">
      <p className="text-sm text-muted-foreground">
        <Link href={`/series/${seriesId}?tab=teams`} className="hover:text-foreground">
          ← {data.series.name}
        </Link>
      </p>
      <div>
        <h1 className="text-2xl font-black">{club.name}</h1>
        <p className="text-sm font-semibold capitalize text-primary">{club.status}</p>
        {club.description ? (
          <p className="mt-2 text-sm text-muted-foreground">{club.description}</p>
        ) : null}
      </div>
      {actionError ? <p className="text-sm text-destructive">{actionError}</p> : null}

      {showJoin ? (
        <div className="space-y-3">
          {user ? (
            joinOpen ? (
              <Card className="space-y-3 p-4">
                <div className="flex items-center justify-between gap-2">
                  <h2 className="font-semibold">Request to join</h2>
                  <Button variant="ghost" size="sm" onClick={() => setJoinOpen(false)}>
                    Close
                  </Button>
                </div>
                <PlayerRegistrationForm
                  seriesId={seriesId}
                  settings={data.series.settings}
                  clubs={[club]}
                  lockIdentity
                  fixedClubId={clubId}
                  identity={officialIdentityFromProfile(profile)}
                  pending={joinClub.isPending}
                  onSubmit={async (values) => {
                    await joinClub.mutateAsync(values);
                    setJoinOpen(false);
                  }}
                />
              </Card>
            ) : (
              <Button onClick={() => setJoinOpen(true)}>Request to join</Button>
            )
          ) : (
            <Card className="space-y-2 p-4">
              <p className="text-sm text-muted-foreground">{SIGN_IN_PROMPTS.join_org_team}</p>
              <Button asChild>
                <Link href={loginUrl(`/series/${seriesId}/teams/${clubId}`, "join_org_team")}>
                  Sign in
                </Link>
              </Button>
            </Card>
          )}
        </div>
      ) : null}

      {canManage && (matchMode !== "none" || tournamentMode !== "none" || isOrgAdmin) ? (
        <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap">
          {matchMode !== "none" ? (
            <form
              className="flex flex-1 flex-wrap items-center gap-2"
              onSubmit={async (e: FormEvent) => {
                e.preventDefault();
                const err = matchTeamsError(access, clubId, opponentId);
                if (err) {
                  setActionError(err);
                  return;
                }
                await proposeMatch.mutateAsync({ clubAId: clubId, clubBId: opponentId });
                setOpponentId("");
              }}
            >
              <select
                className="min-w-[160px] flex-1 rounded-md border border-border bg-background px-3 py-2"
                value={opponentId}
                onChange={(e) => setOpponentId(e.target.value)}
                required
              >
                <option value="">Opponent</option>
                {playable.filter((c) => c.id !== clubId).map((c) => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
              </select>
              <Button type="submit" variant="outline" disabled={proposeMatch.isPending || !opponentId}>
                {proposeMatch.isPending ? "…" : orgActionLabel(matchMode, false)}
              </Button>
            </form>
          ) : null}
          {tournamentMode !== "none" ? (
            <form
              className="flex flex-1 flex-wrap items-center gap-2"
              onSubmit={async (e: FormEvent) => {
                e.preventDefault();
                if (!tournamentId) return;
                await proposeTournament.mutateAsync({ tournamentId });
                setTournamentId("");
              }}
            >
              <select
                className="min-w-[160px] flex-1 rounded-md border border-border bg-background px-3 py-2"
                value={tournamentId}
                onChange={(e) => setTournamentId(e.target.value)}
                required
              >
                <option value="">Your tournament</option>
                {(linkable.data ?? []).map((t) => (
                  <option key={t.id} value={t.id}>{t.name}</option>
                ))}
              </select>
              <Button type="submit" variant="outline" disabled={proposeTournament.isPending || !tournamentId}>
                {proposeTournament.isPending ? "…" : orgActionLabel(tournamentMode, true)}
              </Button>
            </form>
          ) : null}
          {isOrgAdmin ? (
            <Button asChild variant="outline">
              <Link href={`/series/${seriesId}/approvals`}>Pending approvals</Link>
            </Button>
          ) : null}
        </div>
      ) : null}

      {canManage ? (
        <section className="space-y-2">
          <h2 className="text-lg font-bold">Join requests</h2>
          {joinRequests.length === 0 ? (
            <p className="text-sm text-muted-foreground">No pending join reviews.</p>
          ) : (
            joinRequests.map((a) => (
              <Card key={a.id} className="flex flex-wrap items-center justify-between gap-2 p-3">
                <p className="text-sm">{String(a.metadata.displayName || a.requestedBy)}</p>
                <div className="flex gap-2">
                  <Button
                    size="sm"
                    onClick={() => clubReview.mutate({ approvalId: a.id, decision: "approved" })}
                    disabled={clubReview.isPending}
                  >
                    Approve
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => clubReview.mutate({ approvalId: a.id, decision: "rejected" })}
                    disabled={clubReview.isPending}
                  >
                    Reject
                  </Button>
                </div>
              </Card>
            ))
          )}
        </section>
      ) : null}

      {canManage ? (
        <section className="space-y-2">
          <div className="flex items-center justify-between gap-2">
            <h2 className="text-lg font-bold">Team admins</h2>
            <Button variant="ghost" size="sm" onClick={() => setAddAdminOpen((v) => !v)}>
              + Add
            </Button>
          </div>
          {addAdminOpen ? (
            <Card className="space-y-2 p-3">
              <input
                className="w-full rounded-md border border-border bg-background px-3 py-2"
                placeholder="Search by name or CrickFlow Player ID"
                value={addAdminOpen ? searchQ : ""}
                onChange={(e) => runSearch(true, e.target.value)}
              />
              {adminHits.map((hit) => (
                <button
                  type="button"
                  key={hit.id}
                  className="flex w-full items-center justify-between rounded-md px-2 py-2 text-left hover:bg-muted"
                  onClick={async () => {
                    await addAdmin.mutateAsync({
                      userId: hit.id,
                      displayName: hit.displayName,
                    });
                    setAddAdminOpen(false);
                    setAdminHits([]);
                  }}
                >
                  <span>{hit.displayName || hit.name}</span>
                  <span className="text-xs text-muted-foreground">{hit.playerId}</span>
                </button>
              ))}
            </Card>
          ) : null}
          {admins.isLoading ? (
            <p className="text-sm text-muted-foreground">Loading…</p>
          ) : activeAdmins.length === 0 ? (
            <p className="text-sm text-muted-foreground">No team admins yet.</p>
          ) : (
            activeAdmins.map((a) => (
              <Card key={a.id} className="p-3">
                <p className="font-medium">{a.displayName || a.userId}</p>
                <p className="text-xs capitalize text-muted-foreground">{a.status}</p>
              </Card>
            ))
          )}
        </section>
      ) : null}

      <section className="space-y-2">
        <div className="flex items-center justify-between gap-2">
          <h2 className="text-lg font-bold">Squad</h2>
          {canManage ? (
            <Button variant="ghost" size="sm" onClick={() => {
              setAddPlayerOpen((v) => !v);
              setSelectedPlayer(null);
              setSearchHits([]);
            }}>
              + Add
            </Button>
          ) : null}
        </div>
        {addPlayerOpen && canManage ? (
          <Card className="space-y-3 p-4">
            {selectedPlayer ? (
              <>
                <div className="flex items-center justify-between gap-2">
                  <p className="text-sm">Adding {selectedPlayer.displayName || selectedPlayer.name}</p>
                  <Button variant="ghost" size="sm" onClick={() => setSelectedPlayer(null)}>
                    Change
                  </Button>
                </div>
                <PlayerRegistrationForm
                  seriesId={seriesId}
                  settings={data.series.settings}
                  clubs={[club]}
                  lockIdentity
                  fixedClubId={clubId}
                  subjectUserId={selectedPlayer.id}
                  identity={{
                    fullName: selectedPlayer.displayName || selectedPlayer.name,
                    crickFlowPlayerId: selectedPlayer.playerId,
                  }}
                  submitLabel="Add player"
                  pending={addPlayer.isPending}
                  onSubmit={async (values) => {
                    await addPlayer.mutateAsync({
                      ...values,
                      targetUserId: selectedPlayer.id,
                      userId: selectedPlayer.id,
                      playerDocId: selectedPlayer.id,
                    });
                    setAddPlayerOpen(false);
                    setSelectedPlayer(null);
                  }}
                />
              </>
            ) : (
              <>
                <input
                  className="w-full rounded-md border border-border bg-background px-3 py-2"
                  placeholder="Search by name or CrickFlow Player ID"
                  value={searchQ}
                  onChange={(e) => runSearch(false, e.target.value)}
                />
                {searchHits.length === 0 ? (
                  <p className="text-sm text-muted-foreground">Type a name to find players</p>
                ) : (
                  searchHits.map((hit) => (
                    <button
                      type="button"
                      key={hit.id}
                      className="flex w-full items-center justify-between rounded-md px-2 py-2 text-left hover:bg-muted"
                      onClick={() => setSelectedPlayer(hit)}
                    >
                      <span>{hit.displayName || hit.name}</span>
                      <span className="text-xs text-muted-foreground">{hit.playerId}</span>
                    </button>
                  ))
                )}
              </>
            )}
          </Card>
        ) : null}
        {squad.isLoading ? (
          <p className="text-sm text-muted-foreground">Loading…</p>
        ) : activeSquad.length === 0 ? (
          <p className="text-sm text-muted-foreground">Squad not published</p>
        ) : (
          activeSquad.map((m) => (
            <Card key={m.id} className="p-3">
              <p className="font-medium">{m.displayName || m.userId}</p>
              <p className="text-xs capitalize text-muted-foreground">{m.status}</p>
            </Card>
          ))
        )}
      </section>
    </div>
  );
}
