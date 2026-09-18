"use client";

import Link from "next/link";
import Image from "next/image";
import { FormEvent, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import {
  useAddSeriesAdmin,
  useCreateSeriesClub,
  useJoinClub,
  useProposeSeriesMatch,
  useProposeSeriesTournament,
  useReviewSeriesApproval,
  useSeriesAdmins,
  useSeriesCompetitions,
  useSeriesDetail,
  useSeriesRegistrationIdentity,
  useUpdateSeriesSettings,
} from "@/features/series/hooks";
import { usePathParam } from "@/lib/use-path-param";

export default function SeriesDetailPage() {
  const seriesId = usePathParam("seriesId", 1);
  const { user } = useAuth();
  const { data, isLoading } = useSeriesDetail(seriesId, user?.uid);
  const competitions = useSeriesCompetitions(seriesId);
  const admins = useSeriesAdmins(seriesId);
  const review = useReviewSeriesApproval(seriesId);
  const createClub = useCreateSeriesClub(seriesId);
  const updateSettings = useUpdateSeriesSettings(seriesId);
  const joinClub = useJoinClub(seriesId);
  const proposeMatch = useProposeSeriesMatch(seriesId);
  const proposeTournament = useProposeSeriesTournament(seriesId);
  const addAdmin = useAddSeriesAdmin(seriesId);
  const identity = useSeriesRegistrationIdentity(seriesId);

  const [clubName, setClubName] = useState("");
  const [clubDesc, setClubDesc] = useState("");
  const [joinClubId, setJoinClubId] = useState("");
  const [joinName, setJoinName] = useState("");
  const [clubAId, setClubAId] = useState("");
  const [clubBId, setClubBId] = useState("");
  const [tournamentId, setTournamentId] = useState("");
  const [adminUserId, setAdminUserId] = useState("");
  const [maxSquad, setMaxSquad] = useState(20);
  const [identityText, setIdentityText] = useState<string | null>(null);

  if (!seriesId || isLoading) return <p>Loading…</p>;
  if (!data) return <EmptyState title="Series not found" />;
  const { series, clubs, clubRankings, playerRankings } = data;
  const approvedClubs = clubs.filter((c) => c.status === "approved");

  async function onCreateClub(e: FormEvent) {
    e.preventDefault();
    await createClub.mutateAsync({ name: clubName, description: clubDesc });
    setClubName("");
    setClubDesc("");
  }

  async function onJoin(e: FormEvent) {
    e.preventDefault();
    if (!joinClubId || !joinName.trim()) return;
    await joinClub.mutateAsync({
      clubId: joinClubId,
      fullName: joinName.trim(),
      crickFlowPlayerId: user?.uid,
    });
    setJoinName("");
  }

  async function onPropose(e: FormEvent) {
    e.preventDefault();
    await proposeMatch.mutateAsync({ clubAId, clubBId });
  }

  async function onSaveSettings(e: FormEvent) {
    e.preventDefault();
    await updateSettings.mutateAsync({
      ...series.settings,
      maxSquadSize: maxSquad,
    });
  }

  return (
    <div className="space-y-8">
      <header className="rounded-3xl bg-scoreboard p-8 text-white">
        <Badge>{series.status}</Badge>
        <h1 className="mt-3 text-4xl font-black">{series.name}</h1>
        <p className="mt-2 max-w-3xl text-white/75">
          {series.description || "Official CrickFlow series"}
        </p>
        {series.rulesText ? (
          <p className="mt-3 max-w-3xl whitespace-pre-wrap text-sm text-white/70">
            {series.rulesText}
          </p>
        ) : null}
        <div className="mt-5 flex flex-wrap gap-3 text-sm">
          <span>{series.clubCount} clubs</span>
          <span>·</span>
          <span>{series.playerCount} players</span>
          <span>·</span>
          <span>{series.matchCount} matches</span>
          <span>·</span>
          <span>Max squad {series.settings.maxSquadSize}</span>
        </div>
        {data.canManage ? (
          <p className="mt-4 text-sm font-semibold text-gold">
            Admin workspace · {data.pendingApprovalCount} pending approvals
          </p>
        ) : null}
      </header>

      <section>
        <h2 className="mb-3 text-xl font-bold">Clubs</h2>
        {!clubs.length ? (
          <EmptyState title="No clubs published" />
        ) : (
          <div className="grid gap-3 md:grid-cols-2">
            {clubs.map((club) => (
              <Card key={club.id} className="p-4">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <h3 className="font-bold">{club.name}</h3>
                    <p className="text-sm text-muted-foreground">
                      {club.squadCount} players · {club.status}
                    </p>
                  </div>
                  {club.logoUrl ? (
                    <Image
                      unoptimized
                      src={club.logoUrl}
                      alt=""
                      width={48}
                      height={48}
                      className="h-12 w-12 rounded-full object-cover"
                    />
                  ) : null}
                </div>
              </Card>
            ))}
          </div>
        )}
      </section>

      {user ? (
        <section className="grid gap-6 lg:grid-cols-2">
          <Card className="space-y-3 p-4">
            <h2 className="text-lg font-bold">Create club</h2>
            <form className="space-y-3" onSubmit={onCreateClub}>
              <input
                className="w-full rounded-md border border-border bg-background px-3 py-2"
                placeholder="Club name"
                value={clubName}
                onChange={(e) => setClubName(e.target.value)}
                required
              />
              <textarea
                className="w-full rounded-md border border-border bg-background px-3 py-2"
                placeholder="Description"
                value={clubDesc}
                onChange={(e) => setClubDesc(e.target.value)}
              />
              <Button type="submit" disabled={createClub.isPending}>
                {createClub.isPending ? "Submitting…" : "Submit for approval"}
              </Button>
            </form>
          </Card>
          <Card className="space-y-3 p-4">
            <h2 className="text-lg font-bold">Register & join club</h2>
            <form className="space-y-3" onSubmit={onJoin}>
              <select
                className="w-full rounded-md border border-border bg-background px-3 py-2"
                value={joinClubId}
                onChange={(e) => setJoinClubId(e.target.value)}
                required
              >
                <option value="">Select approved club</option>
                {approvedClubs.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
              <input
                className="w-full rounded-md border border-border bg-background px-3 py-2"
                placeholder="Full name"
                value={joinName}
                onChange={(e) => setJoinName(e.target.value)}
                required
              />
              <Button type="submit" disabled={joinClub.isPending}>
                {joinClub.isPending ? "Submitting…" : "Submit join request"}
              </Button>
            </form>
          </Card>
        </section>
      ) : null}

      {data.canManage ? (
        <Card className="space-y-3 p-4">
          <h2 className="text-lg font-bold">Propose Series match</h2>
          <form className="grid gap-3 md:grid-cols-3" onSubmit={onPropose}>
            <select
              className="rounded-md border border-border bg-background px-3 py-2"
              value={clubAId}
              onChange={(e) => setClubAId(e.target.value)}
              required
            >
              <option value="">Club A</option>
              {approvedClubs.map((c) => (
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
              <option value="">Club B</option>
              {approvedClubs.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
            <Button type="submit" disabled={proposeMatch.isPending}>
              {proposeMatch.isPending ? "Submitting…" : "Propose"}
            </Button>
          </form>
          <form
            className="flex flex-wrap gap-3"
            onSubmit={async (e) => {
              e.preventDefault();
              await proposeTournament.mutateAsync({ tournamentId });
              setTournamentId("");
            }}
          >
            <input
              className="min-w-[220px] flex-1 rounded-md border border-border bg-background px-3 py-2"
              placeholder="Existing tournament ID"
              value={tournamentId}
              onChange={(e) => setTournamentId(e.target.value)}
              required
            />
            <Button type="submit" disabled={proposeTournament.isPending}>
              Propose tournament
            </Button>
          </form>
        </Card>
      ) : null}

      <section>
        <h2 className="mb-3 text-xl font-bold">Fixtures</h2>
        {!competitions.data?.length ? (
          <EmptyState title="No Series fixtures yet" />
        ) : (
          <div className="space-y-2">
            {competitions.data.map((c) => (
              <Card key={c.id} className="flex flex-wrap items-center justify-between gap-2 p-4">
                <div>
                  <p className="font-bold">{c.title || c.type}</p>
                  <p className="text-sm text-muted-foreground">
                    {c.type} · {c.status}
                  </p>
                </div>
                {c.matchId ? (
                  <Link href={`/matches/${c.matchId}`} className="text-sm text-primary">
                    Open match
                  </Link>
                ) : null}
                {c.tournamentId ? (
                  <Link href={`/tournaments/${c.tournamentId}`} className="text-sm text-primary">
                    Open tournament
                  </Link>
                ) : null}
              </Card>
            ))}
          </div>
        )}
      </section>

      {data.canManage ? (
        <section>
          <h2 className="mb-3 text-xl font-bold">Series Admins</h2>
          <div className="mb-3 space-y-2">
            {(admins.data ?? [])
              .filter((a) => a.status === "active")
              .map((a) => (
                <Card key={a.id} className="p-3 text-sm">
                  {a.displayName || a.userId} · {a.role || "seriesAdmin"}
                </Card>
              ))}
          </div>
          {data.isSuperAdmin ? (
            <form
              className="flex flex-wrap gap-3"
              onSubmit={async (e) => {
                e.preventDefault();
                await addAdmin.mutateAsync({ userId: adminUserId });
                setAdminUserId("");
              }}
            >
              <input
                className="min-w-[220px] flex-1 rounded-md border border-border bg-background px-3 py-2"
                placeholder="User ID to grant Series Admin"
                value={adminUserId}
                onChange={(e) => setAdminUserId(e.target.value)}
                required
              />
              <Button type="submit" disabled={addAdmin.isPending}>
                Add admin
              </Button>
            </form>
          ) : null}
        </section>
      ) : null}

      {data.isSuperAdmin ? (
        <Card className="space-y-3 p-4">
          <h2 className="text-lg font-bold">Settings</h2>
          <form className="flex flex-wrap items-end gap-3" onSubmit={onSaveSettings}>
            <label className="text-sm">
              Max squad size
              <input
                type="number"
                min={1}
                className="mt-1 block w-28 rounded-md border border-border bg-background px-3 py-2"
                value={maxSquad}
                onChange={(e) => setMaxSquad(Number(e.target.value) || 20)}
              />
            </label>
            <Button type="submit" disabled={updateSettings.isPending}>
              Save
            </Button>
          </form>
          <p className="text-sm text-muted-foreground">
            Registration flags: name={String(series.settings.requireFullName)}, playerId=
            {String(series.settings.requireCrickFlowPlayerId)}, nationalId=
            {String(series.settings.requireNationalId)}
          </p>
        </Card>
      ) : null}

      <section>
        <h2 className="mb-3 text-xl font-bold">Club rankings</h2>
        {!clubRankings.length ? (
          <EmptyState title="Rankings not published" />
        ) : (
          <Card className="overflow-x-auto p-0">
            <table className="w-full text-sm">
              <thead className="bg-muted/50 text-left">
                <tr>
                  <th className="p-3">#</th>
                  <th>Club</th>
                  <th>P</th>
                  <th>W</th>
                  <th>L</th>
                  <th>Pts</th>
                  <th>NRR</th>
                </tr>
              </thead>
              <tbody>
                {clubRankings.map((row, index) => (
                  <tr key={row.id} className="border-t border-border">
                    <td className="p-3">{index + 1}</td>
                    <td>{row.clubName}</td>
                    <td>{row.played}</td>
                    <td>{row.won}</td>
                    <td>{row.lost}</td>
                    <td className="font-bold">{row.points}</td>
                    <td>{row.netRunRate.toFixed(3)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Card>
        )}
      </section>

      <section>
        <h2 className="mb-3 text-xl font-bold">Player leaders</h2>
        {!playerRankings.length ? (
          <EmptyState title="Player rankings not published" />
        ) : (
          <div className="grid gap-3 md:grid-cols-2">
            {playerRankings.slice(0, 12).map((row, index) => (
              <Card key={row.id} className="flex items-center justify-between p-4">
                <div>
                  <span className="mr-3 text-gold">#{index + 1}</span>
                  {row.userId ? (
                    <Link href={`/players/${row.userId}`} className="font-bold text-primary">
                      {row.displayName}
                    </Link>
                  ) : (
                    row.displayName
                  )}
                </div>
                <span className="text-sm">
                  {row.runs} runs · {row.wickets} wkts
                </span>
              </Card>
            ))}
          </div>
        )}
      </section>

      {data.canManage ? (
        <section>
          <h2 className="mb-3 text-xl font-bold">Pending approvals</h2>
          {!data.approvals.length ? (
            <EmptyState title="No pending approvals" />
          ) : (
            <div className="space-y-3">
              {data.approvals.map((approval) => {
                const clubReview =
                  typeof approval.metadata.clubReviewStatus === "string"
                    ? approval.metadata.clubReviewStatus
                    : null;
                const registrationId =
                  typeof approval.metadata.registrationId === "string"
                    ? approval.metadata.registrationId
                    : approval.targetType === "playerRegistration"
                      ? approval.targetId
                      : null;
                const joinBlocked =
                  approval.targetType === "playerJoin" &&
                  clubReview !== "approved" &&
                  !data.isSuperAdmin;
                return (
                  <Card
                    key={approval.id}
                    className="flex flex-wrap items-center justify-between gap-3 p-4"
                  >
                    <div>
                      <p className="font-bold">{approval.targetType}</p>
                      <p className="text-sm text-muted-foreground">
                        {String(
                          approval.metadata.displayName ||
                            approval.metadata.name ||
                            approval.targetId,
                        )}
                      </p>
                      {clubReview ? (
                        <p className="text-xs text-muted-foreground">
                          Club review: {clubReview}
                          {joinBlocked ? " · waiting on Club Admin" : ""}
                        </p>
                      ) : null}
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {registrationId ? (
                        <Button
                          size="sm"
                          variant="outline"
                          disabled={identity.isPending}
                          onClick={async () => {
                            const result = await identity.mutateAsync(registrationId);
                            setIdentityText(
                              result.identity
                                ? JSON.stringify(result.identity, null, 2)
                                : "No private identity on file.",
                            );
                          }}
                        >
                          View identity
                        </Button>
                      ) : null}
                      <Button
                        size="sm"
                        disabled={review.isPending || joinBlocked}
                        onClick={() =>
                          review.mutate({
                            approvalId: approval.id,
                            decision: "approved",
                          })
                        }
                      >
                        Approve
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        disabled={review.isPending}
                        onClick={() =>
                          review.mutate({
                            approvalId: approval.id,
                            decision: "rejected",
                          })
                        }
                      >
                        Reject
                      </Button>
                    </div>
                  </Card>
                );
              })}
            </div>
          )}
          {identityText ? (
            <Card className="mt-4 space-y-2 p-4">
              <div className="flex items-center justify-between gap-2">
                <h3 className="font-bold">Registration identity</h3>
                <Button size="sm" variant="outline" onClick={() => setIdentityText(null)}>
                  Close
                </Button>
              </div>
              <pre className="overflow-x-auto whitespace-pre-wrap text-xs">{identityText}</pre>
            </Card>
          ) : null}
        </section>
      ) : null}
    </div>
  );
}
