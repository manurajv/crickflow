import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  where,
} from "firebase/firestore";
import { collections } from "@/config/site";
import { getDb } from "@/lib/firebase/client";
import { getFirebaseFunctions } from "@/lib/firebase/client";
import { httpsCallable } from "firebase/functions";
import type {
  Series,
  SeriesClub,
  SeriesDetailData,
  SeriesAnnouncement,
  SeriesAuditLog,
} from "./types";

type Data = Record<string, unknown>;
const text = (data: Data, key: string) => (typeof data[key] === "string" ? data[key] as string : "");
const number = (data: Data, key: string) => (typeof data[key] === "number" ? data[key] as number : 0);

function mapSettings(data: Data): Series["settings"] {
  const raw = (data.settings && typeof data.settings === "object"
    ? data.settings
    : {}) as Data;
  const rankingRaw = (raw.rankingRules && typeof raw.rankingRules === "object"
    ? raw.rankingRules
    : {}) as Data;
  return {
    maxSquadSize: number(raw, "maxSquadSize") || 20,
    requireFullName: raw.requireFullName !== false,
    requireCrickFlowPlayerId: raw.requireCrickFlowPlayerId !== false,
    requireDateOfBirth: Boolean(raw.requireDateOfBirth),
    requireNationalId: Boolean(raw.requireNationalId),
    requirePassport: Boolean(raw.requirePassport),
    requirePhoneNumber: Boolean(raw.requirePhoneNumber),
    requireAddress: Boolean(raw.requireAddress),
    requireProfilePhoto: Boolean(raw.requireProfilePhoto),
    rankingRules: {
      // 0 is a valid value (e.g. no-result worth nothing); only absent means default.
      winPoints: typeof rankingRaw.winPoints === "number" ? rankingRaw.winPoints : 2,
      lossPoints: number(rankingRaw, "lossPoints"),
      tiePoints: typeof rankingRaw.tiePoints === "number" ? rankingRaw.tiePoints : 1,
      noResultPoints: typeof rankingRaw.noResultPoints === "number" ? rankingRaw.noResultPoints : 1,
      useNetRunRate: rankingRaw.useNetRunRate !== false,
    },
  };
}

function mapSeries(id: string, data: Data): Series {
  return {
    id,
    name: text(data, "name") || "Series",
    description: text(data, "description"),
    rulesText: text(data, "rulesText"),
    status: (text(data, "status") || "draft") as Series["status"],
    kind: text(data, "kind") || "series",
    coverImageUrl: text(data, "coverImageUrl") || undefined,
    logoUrl: text(data, "logoUrl") || undefined,
    superAdminUserId: text(data, "superAdminUserId") || undefined,
    clubCount: number(data, "clubCount"),
    playerCount: number(data, "playerCount"),
    matchCount: number(data, "matchCount"),
    tournamentCount: number(data, "tournamentCount"),
    settings: mapSettings(data),
    competitionPolicy:
      data.competitionPolicy && typeof data.competitionPolicy === "object"
        ? (data.competitionPolicy as Record<string, unknown>)
        : undefined,
  };
}

function mapClub(id: string, d: Data): SeriesClub {
  return {
    id, seriesId: text(d, "seriesId"), name: text(d, "name") || "Team",
    description: text(d, "description"), logoUrl: text(d, "logoUrl") || undefined,
    status: text(d, "status"), squadCount: number(d, "squadCount"),
    linkedTeamId: text(d, "linkedTeamId") || undefined,
  };
}

export async function rebuildSeriesStandings(seriesId: string) {
  const callable = httpsCallable(getFirebaseFunctions(), "rebuildSeriesStandings");
  const result = await callable({ seriesId });
  return (result.data ?? {}) as { written?: number; removed?: number; skipped?: number };
}

export async function listActiveSeries(take = 40): Promise<Series[]> {
  try {
    const snap = await getDocs(query(
      collection(getDb(), collections.series),
      where("status", "==", "active"),
      orderBy("createdAt", "desc"),
      limit(take),
    ));
    return snap.docs.map((d) => mapSeries(d.id, d.data()));
  } catch {
    const snap = await getDocs(query(collection(getDb(), collections.series), limit(take)));
    return snap.docs.map((d) => mapSeries(d.id, d.data())).filter((s) => s.status === "active");
  }
}

export async function getSeriesDetail(seriesId: string, userId?: string): Promise<SeriesDetailData | null> {
  const seriesSnap = await getDoc(doc(getDb(), collections.series, seriesId));
  if (!seriesSnap.exists()) return null;
  const [clubs, admins, approvalsNested, approvalsLegacy, competitions, allAdmins, clubAdmins, memberships] = await Promise.all([
    getDocs(query(collection(getDb(), collections.seriesClubs), where("seriesId", "==", seriesId))),
    userId ? getDocs(query(collection(getDb(), collections.seriesAdmins), where("seriesId", "==", seriesId), where("userId", "==", userId), limit(1))) : null,
    userId
      ? getDocs(
          query(
            collection(getDb(), collections.series, seriesId, "approvals"),
            where("status", "==", "pending"),
            limit(100),
          ),
        ).catch(() => null)
      : null,
    userId
      ? getDocs(
          query(
            collection(getDb(), collections.seriesApprovals),
            where("seriesId", "==", seriesId),
            where("status", "==", "pending"),
            limit(100),
          ),
        ).catch(() => null)
      : null,
    getDocs(query(collection(getDb(), collections.seriesCompetitions), where("seriesId", "==", seriesId), limit(100))),
    getDocs(query(collection(getDb(), collections.seriesAdmins), where("seriesId", "==", seriesId), limit(50))),
    userId
      ? getDocs(
          query(
            collection(getDb(), collections.seriesClubAdmins),
            where("seriesId", "==", seriesId),
            where("userId", "==", userId),
            limit(50),
          ),
        ).catch(() => null)
      : null,
    userId
      ? getDocs(
          query(
            collection(getDb(), collections.seriesMemberships),
            where("seriesId", "==", seriesId),
            where("userId", "==", userId),
            limit(50),
          ),
        ).catch(() => null)
      : null,
  ]);
  const approvals =
    approvalsNested && approvalsNested.size > 0 ? approvalsNested : approvalsLegacy;
  const series = mapSeries(seriesSnap.id, seriesSnap.data());
  return {
    series,
    clubs: clubs.docs.map((d) => mapClub(d.id, d.data())),
    competitions: competitions.docs.map((d) => {
      const x = d.data();
      return {
        id: d.id,
        title: text(x, "title"),
        type: text(x, "type"),
        status: text(x, "status"),
        matchId: text(x, "matchId") || undefined,
        tournamentId: text(x, "tournamentId") || undefined,
      };
    }),
    admins: allAdmins.docs
      .map((d) => {
        const x = d.data();
        return {
          id: d.id,
          userId: text(x, "userId"),
          displayName: text(x, "displayName"),
          status: text(x, "status") || "active",
          role: text(x, "role"),
        };
      })
      .filter((a) => a.status === "active"),
    canManage: Boolean(userId && (series.superAdminUserId === userId || admins?.size)),
    isSuperAdmin: Boolean(userId && series.superAdminUserId === userId),
    myRole: ((): SeriesDetailData["myRole"] => {
      if (!userId) return "viewer";
      if (series.superAdminUserId === userId) return "superAdmin";
      const seriesAdminActive = Boolean(
        admins?.docs.some((d) => (d.data().status as string | undefined) !== "removed" && (d.data().status as string | undefined) !== "inactive"),
      );
      if (seriesAdminActive || (admins && admins.size > 0)) return "seriesAdmin";
      const clubAdminActive = Boolean(
        clubAdmins?.docs.some((d) => {
          const st = d.data().status;
          return st === "active" || st == null;
        }),
      );
      if (clubAdminActive) return "clubAdmin";
      const memberActive = Boolean(
        memberships?.docs.some((d) => d.data().status === "active"),
      );
      if (memberActive) return "seriesPlayer";
      return "viewer";
    })(),
    myTeamIds: (() => {
      if (!userId) return [] as string[];
      const ids = new Set<string>();
      for (const d of clubAdmins?.docs ?? []) {
        const st = d.data().status;
        if (st === "active" || st == null) {
          const clubId = typeof d.data().clubId === "string" ? d.data().clubId : "";
          if (clubId) ids.add(clubId);
        }
      }
      for (const d of memberships?.docs ?? []) {
        if (d.data().status === "active") {
          const clubId = typeof d.data().clubId === "string" ? d.data().clubId : "";
          if (clubId) ids.add(clubId);
        }
      }
      return [...ids];
    })(),
    pendingApprovalCount: approvals?.size ?? 0,
    approvals: approvals?.docs.map((d) => {
      const x = d.data();
      return {
        id: d.id,
        targetType: text(x, "targetType"),
        targetId: text(x, "targetId"),
        requestedBy: text(x, "requestedBy"),
        metadata: (x.metadata && typeof x.metadata === "object"
          ? x.metadata
          : {}) as Record<string, unknown>,
      };
    }) ?? [],
  };
}

export async function reviewSeriesApproval(
  seriesId: string,
  approvalId: string,
  decision: "approved" | "rejected",
  reason = "",
) {
  const callable = httpsCallable(getFirebaseFunctions(), "reviewSeriesApproval");
  await callable({ seriesId, approvalId, decision, reason });
}

/** Tournaments the user organizes that are not already in an org. */
export async function listMyLinkableTournaments(uid: string) {
  const snap = await getDocs(
    query(collection(getDb(), collections.tournaments), where("createdBy", "==", uid), limit(50)),
  );
  return snap.docs
    .map((d) => ({ id: d.id, data: d.data() as Record<string, unknown> }))
    .filter(({ data }) => !data.seriesId || data.seriesOfficialStatus === "rejected")
    .map(({ id, data }) => ({
      id,
      name: typeof data.name === "string" && data.name ? data.name : "Tournament",
    }));
}

/** Org admins: add one of their own tournaments to the org. */
export async function linkSeriesTournament(input: {
  seriesId: string;
  tournamentId: string;
  title?: string;
}) {
  const callable = httpsCallable(getFirebaseFunctions(), "startSeriesTournament");
  const result = await callable({ ...input, mode: "link", teamClubIds: [] });
  return result.data as { autoApproved?: boolean; status?: string };
}

export async function createSeriesClub(input: {
  seriesId: string;
  name: string;
  description?: string;
}) {
  const callable = httpsCallable(getFirebaseFunctions(), "createSeriesClub");
  const result = await callable(input);
  return (result.data ?? {}) as { clubId?: string };
}

export async function updateSeriesSettings(
  seriesId: string,
  settings: Record<string, unknown>,
) {
  const callable = httpsCallable(getFirebaseFunctions(), "updateSeriesSettings");
  await callable({ seriesId, settings });
}

export async function updateSeriesCompetitionPolicy(
  seriesId: string,
  policy: Record<string, unknown>,
) {
  const callable = httpsCallable(
    getFirebaseFunctions(),
    "updateSeriesCompetitionPolicy",
  );
  await callable({ seriesId, policy });
}

export async function submitSeriesRegistration(input: Record<string, unknown>) {
  const callable = httpsCallable(getFirebaseFunctions(), "submitSeriesRegistration");
  const result = await callable(input);
  return (result.data ?? {}) as { registrationId?: string };
}

export async function submitPlayerJoinRequest(input: {
  seriesId: string;
  clubId: string;
  registrationId?: string;
  displayName?: string;
}) {
  const callable = httpsCallable(getFirebaseFunctions(), "submitPlayerJoinRequest");
  await callable(input);
}

export async function createSeries(input: {
  name: string;
  description?: string;
  rulesText?: string;
  kind?: string;
  displayName?: string;
  logoUrl?: string;
  coverImageUrl?: string;
  region?: string;
  location?: string;
  country?: string;
  settings?: Record<string, unknown>;
}) {
  const callable = httpsCallable(getFirebaseFunctions(), "createSeries");
  const result = await callable(input);
  return (result.data ?? {}) as { seriesId?: string };
}

export async function getSeriesRegistrationIdentity(
  seriesId: string,
  registrationId: string,
) {
  const callable = httpsCallable(getFirebaseFunctions(), "getSeriesRegistrationIdentity");
  const result = await callable({ seriesId, registrationId });
  return (result.data ?? {}) as {
    registrationId?: string;
    identity?: Record<string, unknown> | null;
  };
}

export async function reviewClubJoinRequest(input: {
  seriesId: string;
  approvalId: string;
  decision: "approved" | "rejected";
  reason?: string;
}) {
  const callable = httpsCallable(getFirebaseFunctions(), "reviewClubJoinRequest");
  await callable(input);
}

export async function proposeSeriesMatch(input: {
  seriesId: string;
  clubAId: string;
  clubBId: string;
  title?: string;
  createMatchDraft?: boolean;
}) {
  const callable = httpsCallable(getFirebaseFunctions(), "proposeSeriesMatch");
  const result = await callable(input);
  return (result.data ?? {}) as { matchId?: string; competitionId?: string };
}

export async function proposeSeriesTournament(input: {
  seriesId: string;
  tournamentId: string;
  title?: string;
  clubId?: string;
}) {
  const callable = httpsCallable(getFirebaseFunctions(), "proposeSeriesTournament");
  await callable(input);
}

export async function addSeriesAdmin(input: {
  seriesId: string;
  userId: string;
  displayName?: string;
}) {
  const callable = httpsCallable(getFirebaseFunctions(), "addSeriesAdmin");
  await callable(input);
}

export async function listSeriesCompetitions(seriesId: string) {
  const snap = await getDocs(
    query(
      collection(getDb(), collections.seriesCompetitions),
      where("seriesId", "==", seriesId),
      limit(100),
    ),
  );
  return snap.docs.map((d) => {
    const x = d.data();
    return {
      id: d.id,
      title: text(x, "title"),
      type: text(x, "type"),
      status: text(x, "status"),
      matchId: text(x, "matchId") || undefined,
      tournamentId: text(x, "tournamentId") || undefined,
    };
  });
}

export async function listSeriesAdmins(seriesId: string) {
  const snap = await getDocs(
    query(
      collection(getDb(), collections.seriesAdmins),
      where("seriesId", "==", seriesId),
      limit(50),
    ),
  );
  return snap.docs.map((d) => {
    const x = d.data();
    return {
      id: d.id,
      userId: text(x, "userId"),
      displayName: text(x, "displayName"),
      status: text(x, "status") || "active",
      role: text(x, "role"),
    };
  });
}


export async function listSeriesAnnouncements(
  seriesId: string,
  take = 20,
): Promise<SeriesAnnouncement[]> {
  try {
    const snap = await getDocs(
      query(
        collection(getDb(), collections.series, seriesId, "announcements"),
        orderBy("createdAt", "desc"),
        limit(take),
      ),
    );
    return snap.docs.map((d) => {
      const x = d.data();
      const createdAt = x.createdAt;
      let createdAtStr: string | null = null;
      if (createdAt && typeof createdAt.toDate === "function") {
        createdAtStr = createdAt.toDate().toISOString();
      } else if (typeof createdAt === "string") {
        createdAtStr = createdAt;
      }
      return {
        id: d.id,
        title: text(x, "title"),
        body: text(x, "body"),
        createdBy: text(x, "createdBy"),
        createdByName: text(x, "createdByName"),
        createdAt: createdAtStr,
        audience: text(x, "audience") || undefined,
        recipientCount: number(x, "recipientCount") || undefined,
      };
    });
  } catch {
    return [];
  }
}

export async function listSeriesAuditLogs(
  seriesId: string,
  take = 20,
): Promise<SeriesAuditLog[]> {
  try {
    const snap = await getDocs(
      query(
        collection(getDb(), collections.seriesAuditLogs),
        where("seriesId", "==", seriesId),
        orderBy("timestamp", "desc"),
        limit(take),
      ),
    );
    return snap.docs.map((d) => {
      const x = d.data();
      const ts = x.timestamp;
      let timestamp: string | null = null;
      if (ts && typeof ts.toDate === "function") {
        timestamp = ts.toDate().toISOString();
      } else if (typeof ts === "string") {
        timestamp = ts;
      }
      return {
        id: d.id,
        action: text(x, "action"),
        actorUserId: text(x, "actorUserId"),
        timestamp,
      };
    });
  } catch {
    // Fallback without orderBy if index missing
    try {
      const snap = await getDocs(
        query(
          collection(getDb(), collections.seriesAuditLogs),
          where("seriesId", "==", seriesId),
          limit(take),
        ),
      );
      return snap.docs.map((d) => {
        const x = d.data();
        return {
          id: d.id,
          action: text(x, "action"),
          actorUserId: text(x, "actorUserId"),
          timestamp: typeof x.timestamp === "string" ? x.timestamp : null,
        };
      });
    } catch {
      return [];
    }
  }
}

export async function listActiveSeriesByKind(
  kind?: string,
  take = 40,
): Promise<Series[]> {
  const all = await listActiveSeries(Math.max(take, 80));
  if (!kind || kind === "all") return all.slice(0, take);
  return all.filter((s) => s.kind === kind).slice(0, take);
}

export function seriesAuditActionLabel(action: string): string {
  const map: Record<string, string> = {
    APPROVAL_APPROVED: "Approved a request",
    APPROVAL_REJECTED: "Rejected a request",
    CLUB_APPROVED: "Approved a team",
    CLUB_REJECTED: "Rejected a team",
    PLAYER_APPROVED: "Approved a player",
    PLAYER_REJECTED: "Rejected a player",
    MATCH_APPROVED: "Approved a match",
    MATCH_REJECTED: "Rejected a match",
    TOURNAMENT_APPROVED: "Approved a tournament",
    TOURNAMENT_REJECTED: "Rejected a tournament",
    SETTINGS_UPDATED: "Updated settings",
    POLICY_UPDATED: "Updated permissions",
    ANNOUNCEMENT_SENT: "Posted an announcement",
  };
  return map[action] || action.replace(/_/g, " ").toLowerCase();
}
