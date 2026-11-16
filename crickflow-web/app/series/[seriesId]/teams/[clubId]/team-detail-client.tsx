"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { FormEvent, useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Textarea } from "@/components/ui/input";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import { PlayerRegistrationForm } from "@/features/series/components/player-registration-form";
import {
  useAddClubAdmin,
  useAddPlayerToClub,
  useCancelClubAdminInvite,
  useClubAdmins,
  useClubSquad,
  useJoinClub,
  useMyLinkableTournaments,
  useProposeSeriesMatch,
  useProposeSeriesTournament,
  useRemoveClubAdmin,
  useRemovePlayerFromClub,
  useRespondClubAdminInvite,
  useReviewClubJoinRequest,
  useReviewSeriesApproval,
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
import {
  clubAdminStatusLabel,
  isListedSquadMember,
  isOpenClubAdminInvite,
  squadStatusLabel,
} from "@/lib/cricket/series-team-staff";
import { loginUrl, SIGN_IN_PROMPTS } from "@/lib/auth/guest-access";
import { usePathParam } from "@/lib/use-path-param";
import { friendlyError } from "@/lib/friendly-error";

type ConfirmState =
  | { kind: "removeAdmin"; userId: string; name: string }
  | { kind: "removePlayer"; userId: string; name: string; direct: boolean }
  | { kind: "rejectRemoval"; approvalId: string; name: string };

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  return parts.slice(0, 2).map((p) => p[0]?.toUpperCase() ?? "").join("");
}

function PlayerSearchPanel({
  query,
  onQuery,
  hits,
  loading,
  error,
  emptyHint,
  onRetry,
  onSelect,
}: {
  query: string;
  onQuery: (value: string) => void;
  hits: PlayerSearchHit[];
  loading: boolean;
  error: string;
  emptyHint: string;
  onRetry: () => void;
  onSelect: (hit: PlayerSearchHit) => void;
}) {
  return (
    <div className="space-y-3">
      <div className="relative">
        <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm text-muted-foreground">
          ⌕
        </span>
        <Input
          className="pl-8 pr-10"
          placeholder="Search by name or CrickFlow ID"
          value={query}
          onChange={(e) => onQuery(e.target.value)}
          aria-label="Search players"
          data-testid="org-player-search-field"
        />
        {query ? (
          <button
            type="button"
            className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-muted-foreground"
            onClick={() => onQuery("")}
            aria-label="Clear search"
          >
            ✕
          </button>
        ) : null}
      </div>
      {loading ? <p className="text-sm text-muted-foreground">Searching…</p> : null}
      {error ? (
        <div className="flex items-center justify-between gap-2 text-sm text-destructive">
          <span>{error}</span>
          <Button size="sm" variant="outline" type="button" onClick={onRetry}>
            Retry
          </Button>
        </div>
      ) : null}
      {!loading && !error && query.trim().length < 2 ? (
        <p className="text-sm text-muted-foreground">{emptyHint}</p>
      ) : null}
      {!loading && !error && query.trim().length >= 2 && hits.length === 0 ? (
        <p className="text-sm text-muted-foreground">No players matched that search.</p>
      ) : null}
      {hits.map((hit) => {
        const name = hit.displayName || hit.name || "Player";
        return (
          <button
            type="button"
            key={hit.id}
            className="flex w-full items-center gap-3 rounded-xl border border-border px-3 py-2 text-left hover:bg-muted"
            onClick={() => onSelect(hit)}
          >
            {hit.photoUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={hit.photoUrl} alt="" className="h-10 w-10 rounded-full object-cover" />
            ) : (
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-muted text-xs font-semibold">
                {initials(name)}
              </span>
            )}
            <span className="min-w-0 flex-1">
              <span className="block truncate font-medium">{name}</span>
              <span className="block text-xs text-muted-foreground">
                {hit.playerId || "No CrickFlow ID"}
              </span>
            </span>
          </button>
        );
      })}
    </div>
  );
}

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
  const removeAdmin = useRemoveClubAdmin(seriesId, clubId);
  const cancelInvite = useCancelClubAdminInvite(seriesId, clubId);
  const respondInvite = useRespondClubAdminInvite(seriesId, clubId);
  const removePlayer = useRemovePlayerFromClub(seriesId, clubId);
  const reviewApproval = useReviewSeriesApproval(seriesId);
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
  const [searchFor, setSearchFor] = useState<"admin" | "player" | null>(null);
  const [searchHits, setSearchHits] = useState<PlayerSearchHit[]>([]);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchError, setSearchError] = useState("");
  const [selectedPlayer, setSelectedPlayer] = useState<PlayerSearchHit | null>(null);
  const [adminHits, setAdminHits] = useState<PlayerSearchHit[]>([]);
  const [actionError, setActionError] = useState("");
  const [actionNotice, setActionNotice] = useState("");
  const [confirm, setConfirm] = useState<ConfirmState | null>(null);
  const [reason, setReason] = useState("");

  useEffect(() => {
    if (!searchFor) return;
    const value = searchQ.trim();
    if (value.length < 2) {
      setSearchError("");
      setSearchLoading(false);
      if (searchFor === "admin") setAdminHits([]);
      else setSearchHits([]);
      return;
    }
    const handle = window.setTimeout(async () => {
      setSearchLoading(true);
      setSearchError("");
      try {
        const hits = await searchPlayers.mutateAsync({
          query: value,
          currentUserId: user?.uid,
        });
        if (searchFor === "admin") setAdminHits(hits);
        else setSearchHits(hits);
      } catch (err) {
        setSearchError(friendlyError(err, "Could not search players"));
      } finally {
        setSearchLoading(false);
      }
    }, 300);
    return () => window.clearTimeout(handle);
  // mutateAsync is used for the search request; omit the mutation object so
  // loading-state updates do not retrigger the effect.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchQ, searchFor, user?.uid]);

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
  const listedSquad = (squad.data ?? []).filter((m) => isListedSquadMember(m.status));
  const isOnSquad = Boolean(
    user && listedSquad.some((m) => m.userId === user.uid),
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
  const removalRequests = (data.approvals ?? []).filter((a) => {
    if (a.targetType !== "playerRemoval") return false;
    const requestClub =
      (typeof a.clubId === "string" && a.clubId) ||
      (typeof a.metadata.clubId === "string" ? a.metadata.clubId : "");
    return requestClub === clubId && a.status === "pending";
  });
  const visibleAdmins = (admins.data ?? []).filter(
    (a) => a.status !== "removed" && a.status !== "cancelled" && a.status !== "declined",
  );
  const myInvite = (admins.data ?? []).find(
    (a) => user && a.userId === user.uid && isOpenClubAdminInvite(a.status),
  );

  function openPlayerSearch() {
    setAddPlayerOpen(true);
    setSelectedPlayer(null);
    setSearchHits([]);
    setSearchQ("");
    setSearchFor("player");
    setSearchError("");
  }

  async function runAction(message: string, work: () => Promise<unknown>) {
    setActionError("");
    setActionNotice("");
    try {
      await work();
      setActionNotice(message);
    } catch (err) {
      setActionError(friendlyError(err, "Something went wrong"));
    }
  }

  async function submitConfirm() {
    if (!confirm) return;
    if (confirm.kind === "removeAdmin") {
      await runAction("Admin removed", () => removeAdmin.mutateAsync(confirm.userId));
      setConfirm(null);
      return;
    }
    const trimmed = reason.trim();
    if (!trimmed) {
      setActionError("Please enter a reason");
      return;
    }
    if (confirm.kind === "removePlayer") {
      await runAction(
        confirm.direct ? "Player removed" : "Removal request submitted",
        () => removePlayer.mutateAsync({ userId: confirm.userId, reason: trimmed }),
      );
      setConfirm(null);
      setReason("");
      return;
    }
    await runAction("Removal declined", () =>
      reviewApproval.mutateAsync({
        approvalId: confirm.approvalId,
        decision: "rejected",
        reason: trimmed,
      }),
    );
    setConfirm(null);
    setReason("");
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
      {actionNotice ? <p className="text-sm text-primary">{actionNotice}</p> : null}

      {myInvite ? (
        <Card className="space-y-3 p-4" data-testid="org-team-admin-invite-banner">
          <p className="text-sm font-medium">
            You&apos;ve been invited to be a team admin for {club.name}.
          </p>
          <div className="flex gap-2">
            <Button
              onClick={() => runAction("Invitation accepted", () => respondInvite.mutateAsync("accepted"))}
              disabled={respondInvite.isPending}
            >
              Accept
            </Button>
            <Button
              variant="outline"
              onClick={() => runAction("Invitation declined", () => respondInvite.mutateAsync("declined"))}
              disabled={respondInvite.isPending}
            >
              Decline
            </Button>
          </div>
        </Card>
      ) : null}

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

      {canManage ? (
        <Button data-testid="org-team-search-add-player" onClick={openPlayerSearch}>
          Search & add player
        </Button>
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

      {canManage || removalRequests.length > 0 ? (
        <section className="space-y-2">
          <h2 className="text-lg font-bold">Removal requests</h2>
          {removalRequests.length === 0 ? (
            <p className="text-sm text-muted-foreground">No pending removal reviews.</p>
          ) : (
            removalRequests.map((a) => {
              const name = String(a.metadata.displayName || a.metadata.userId || a.requestedBy);
              return (
                <Card key={a.id} className="flex flex-wrap items-center justify-between gap-2 p-3">
                  <div>
                    <p className="text-sm font-medium">{name}</p>
                    {a.reason || a.metadata.reason ? (
                      <p className="text-xs text-muted-foreground">
                        {String(a.reason || a.metadata.reason)}
                      </p>
                    ) : null}
                  </div>
                  {isOrgAdmin ? (
                    <div className="flex gap-2">
                      <Button
                        size="sm"
                        onClick={() =>
                          runAction("Player removed", () =>
                            reviewApproval.mutateAsync({ approvalId: a.id, decision: "approved" }),
                          )
                        }
                        disabled={reviewApproval.isPending}
                      >
                        Approve
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => setConfirm({ kind: "rejectRemoval", approvalId: a.id, name })}
                        disabled={reviewApproval.isPending}
                      >
                        Decline
                      </Button>
                    </div>
                  ) : (
                    <p className="text-xs text-muted-foreground">Pending</p>
                  )}
                </Card>
              );
            })
          )}
        </section>
      ) : null}

      <section className="space-y-2">
        <div className="flex items-center justify-between gap-2">
          <h2 className="text-lg font-bold">Team admins</h2>
          {canManage ? (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setAddAdminOpen((v) => !v);
                setSearchQ("");
                setSearchFor("admin");
                setAdminHits([]);
                setSearchError("");
              }}
            >
              + Add
            </Button>
          ) : null}
        </div>
        {addAdminOpen && canManage ? (
          <Card className="space-y-2 p-3">
            <PlayerSearchPanel
              query={searchFor === "admin" ? searchQ : ""}
              onQuery={(value) => {
                setSearchFor("admin");
                setSearchQ(value);
              }}
              hits={adminHits}
              loading={searchFor === "admin" && searchLoading}
              error={searchFor === "admin" ? searchError : ""}
              emptyHint="Type a name or CrickFlow ID to invite a team admin"
              onRetry={() => setSearchQ((q) => q + " ")}
              onSelect={async (hit) => {
                await runAction("Invitation sent", () =>
                  addAdmin.mutateAsync({
                    userId: hit.id,
                    displayName: hit.displayName || hit.name,
                  }),
                );
                setAddAdminOpen(false);
                setAdminHits([]);
                setSearchQ("");
              }}
            />
          </Card>
        ) : null}
        {admins.isLoading ? (
          <p className="text-sm text-muted-foreground">Loading…</p>
        ) : visibleAdmins.length === 0 ? (
          <p className="text-sm text-muted-foreground">No team admins yet.</p>
        ) : (
          visibleAdmins.map((a) => {
            const name = a.displayName || a.userId;
            const invited = isOpenClubAdminInvite(a.status);
            return (
              <Card key={a.id} className="flex flex-wrap items-center justify-between gap-2 p-3">
                <div>
                  <p className="font-medium">{name}</p>
                  <p className="text-xs text-muted-foreground">{clubAdminStatusLabel(a.status)}</p>
                </div>
                <div className="flex gap-2">
                  {invited && canManage ? (
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() =>
                        runAction("Invitation cancelled", () => cancelInvite.mutateAsync(a.userId))
                      }
                      disabled={cancelInvite.isPending}
                    >
                      Cancel
                    </Button>
                  ) : null}
                  {!invited && a.status === "active" && isOrgAdmin ? (
                    <Button
                      size="sm"
                      variant="outline"
                      className="text-destructive"
                      onClick={() => setConfirm({ kind: "removeAdmin", userId: a.userId, name })}
                    >
                      Remove
                    </Button>
                  ) : null}
                </div>
              </Card>
            );
          })
        )}
      </section>

      <section className="space-y-2">
        <div className="flex items-center justify-between gap-2">
          <h2 className="text-lg font-bold">Squad</h2>
          {canManage ? (
            <Button variant="ghost" size="sm" onClick={openPlayerSearch}>
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
              <PlayerSearchPanel
                query={searchFor === "player" ? searchQ : ""}
                onQuery={(value) => {
                  setSearchFor("player");
                  setSearchQ(value);
                }}
                hits={searchHits}
                loading={searchFor === "player" && searchLoading}
                error={searchFor === "player" ? searchError : ""}
                emptyHint="Type a name or CrickFlow ID to find players"
                onRetry={() => setSearchQ((q) => q + " ")}
                onSelect={setSelectedPlayer}
              />
            )}
          </Card>
        ) : null}
        {squad.isLoading ? (
          <p className="text-sm text-muted-foreground">Loading…</p>
        ) : listedSquad.length === 0 ? (
          <p className="text-sm text-muted-foreground">Squad not published</p>
        ) : (
          listedSquad.map((m) => {
            const name = m.displayName || m.userId;
            const pendingRemoval = m.status === "pendingRemoval";
            return (
              <Card key={m.id} className="flex flex-wrap items-center justify-between gap-2 p-3">
                <div>
                  <p className="font-medium">{name}</p>
                  <p className="text-xs text-muted-foreground">{squadStatusLabel(m.status)}</p>
                </div>
                {canManage && !pendingRemoval ? (
                  <Button
                    size="sm"
                    variant="outline"
                    className="text-destructive"
                    onClick={() =>
                      setConfirm({
                        kind: "removePlayer",
                        userId: m.userId,
                        name,
                        direct: isOrgAdmin,
                      })
                    }
                  >
                    Remove
                  </Button>
                ) : null}
              </Card>
            );
          })
        )}
      </section>

      {confirm ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <Card className="w-full max-w-md space-y-3 p-4">
            {confirm.kind === "removeAdmin" ? (
              <>
                <h2 className="text-lg font-bold">Remove admin?</h2>
                <p className="text-sm text-muted-foreground">
                  Remove {confirm.name} as a team admin? They will lose admin access immediately.
                </p>
                <div className="flex justify-end gap-2">
                  <Button variant="outline" type="button" onClick={() => setConfirm(null)}>
                    Cancel
                  </Button>
                  <Button
                    type="button"
                    className="bg-red-600 text-white hover:bg-red-700"
                    onClick={submitConfirm}
                    disabled={removeAdmin.isPending}
                  >
                    Remove admin
                  </Button>
                </div>
              </>
            ) : (
              <>
                <h2 className="text-lg font-bold">
                  {confirm.kind === "rejectRemoval"
                    ? "Decline removal?"
                    : confirm.direct
                      ? "Remove player?"
                      : "Request player removal?"}
                </h2>
                <p className="text-sm text-muted-foreground">
                  {confirm.kind === "rejectRemoval"
                    ? `Explain why ${confirm.name} should stay on the squad.`
                    : confirm.direct
                      ? `Remove ${confirm.name} from the squad? Please give a reason.`
                      : `Ask organization admins to remove ${confirm.name} from the squad. The player stays listed as Removal pending until this is approved.`}
                </p>
                <Textarea
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  placeholder="Reason (required)"
                  rows={3}
                />
                <div className="flex justify-end gap-2">
                  <Button
                    variant="outline"
                    type="button"
                    onClick={() => {
                      setConfirm(null);
                      setReason("");
                    }}
                  >
                    Cancel
                  </Button>
                  <Button
                    type="button"
                    className={confirm.kind === "rejectRemoval" ? "" : "bg-red-600 text-white hover:bg-red-700"}
                    onClick={submitConfirm}
                    disabled={
                      !reason.trim() ||
                      removePlayer.isPending ||
                      reviewApproval.isPending
                    }
                  >
                    {confirm.kind === "rejectRemoval"
                      ? "Decline"
                      : confirm.direct
                        ? "Remove player"
                        : "Request removal"}
                  </Button>
                </div>
              </>
            )}
          </Card>
        </div>
      ) : null}
    </div>
  );
}
