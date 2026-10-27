import { collection, documentId, getDocs, query, where } from "firebase/firestore";
import { collections } from "@/config/site";
import { getDb } from "@/lib/firebase/client";
import { mapMatch } from "@/lib/firebase/mappers";
import type {
  DigestPlayer,
  MatchDigest,
  OrgPlayerInfo,
} from "@/lib/cricket/org-leaderboard";
import type { Match } from "@/types/models";

type Data = Record<string, unknown>;
const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");
const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : 0);

export interface OrgTournamentInfo {
  id: string;
  name: string;
  teamIds: string[];
}

export interface OrgLeaderboardData {
  matches: Match[];
  digests: Record<string, MatchDigest>;
  tournaments: OrgTournamentInfo[];
}

function mapDigest(id: string, data: Data): MatchDigest {
  const raw = (data.players && typeof data.players === "object" ? data.players : {}) as Record<string, Data>;
  const players: Record<string, DigestPlayer> = {};
  for (const [playerId, p] of Object.entries(raw)) {
    const fifty = p?.fastestFiftyBalls;
    const hundred = p?.fastestHundredBalls;
    players[playerId] = {
      catches: num(p?.catches),
      runOuts: num(p?.runOuts),
      stumpings: num(p?.stumpings),
      dotBalls: num(p?.dotBalls),
      maidens: num(p?.maidens),
      fastestFiftyBalls: typeof fifty === "number" ? fifty : null,
      fastestHundredBalls: typeof hundred === "number" ? hundred : null,
    };
  }
  return { matchId: str(data.matchId) || id, players };
}

/**
 * Everything the org leaderboard needs: the org's matches (all of them; the
 * calculation filters like the app does), the server-built replay digests and
 * the org's tournaments (for the competition filter).
 */
export async function getOrgLeaderboardData(seriesId: string): Promise<OrgLeaderboardData> {
  const db = getDb();
  const [matchSnap, digestSnap, tournamentSnap] = await Promise.all([
    getDocs(query(collection(db, collections.matches), where("seriesId", "==", seriesId))),
    getDocs(query(collection(db, collections.seriesMatchDigests), where("seriesId", "==", seriesId))),
    getDocs(query(collection(db, collections.tournaments), where("seriesId", "==", seriesId))),
  ]);
  const digests: Record<string, MatchDigest> = {};
  for (const d of digestSnap.docs) digests[d.id] = mapDigest(d.id, d.data());
  return {
    matches: matchSnap.docs.map((d) => mapMatch(d.id, d.data())),
    digests,
    tournaments: tournamentSnap.docs
      .filter((d) => str(d.data().seriesOfficialStatus) === "approved")
      .map((d) => {
        const x = d.data();
        return {
          id: d.id,
          name: str(x.name) || "Tournament",
          teamIds: Array.isArray(x.teamIds) ? x.teamIds.filter((t): t is string => typeof t === "string") : [],
        };
      })
      .sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase())),
  };
}

async function docsByIds(collectionName: string, ids: string[]): Promise<Array<{ id: string; data: Data }>> {
  const out: Array<{ id: string; data: Data }> = [];
  const unique = [...new Set(ids.filter(Boolean))];
  for (let i = 0; i < unique.length; i += 30) {
    const chunk = unique.slice(i, i + 30);
    const snap = await getDocs(
      query(collection(getDb(), collectionName), where(documentId(), "in", chunk)),
    );
    for (const d of snap.docs) out.push({ id: d.id, data: d.data() });
  }
  return out;
}

/**
 * Player docs for the ranked ids. Like the app, a player only ranks with an
 * account (`userId`); walk-ins (no doc, or a doc without userId) come back
 * without one and are skipped by the ranking.
 */
export async function loadOrgPlayers(ids: string[]): Promise<OrgPlayerInfo[]> {
  const docs = await docsByIds(collections.players, ids);
  const teamIdOf = (x: Data): string => {
    const list = Array.isArray(x.teamIds) ? x.teamIds.filter((t): t is string => typeof t === "string" && t !== "") : [];
    return list[0] ?? str(x.teamId);
  };
  const teams = await docsByIds(
    collections.teams,
    docs.map((d) => teamIdOf(d.data)),
  );
  const teamName = new Map(teams.map((t) => [t.id, str(t.data.name)]));
  return docs.map(({ id, data }) => ({
    id,
    name: str(data.name) || str(data.fullName) || "Player",
    userId: str(data.userId) || undefined,
    playerId: str(data.playerId) || str(data.cfPlayerId) || undefined,
    photoUrl: str(data.photoUrl) || undefined,
    role: str(data.role) || undefined,
    teamName: teamName.get(teamIdOf(data)) ?? "",
  }));
}
