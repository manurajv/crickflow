import {
  addDoc,
  arrayUnion,
  arrayRemove,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  increment,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  startAfter,
  updateDoc,
  where,
  type DocumentData,
  type Query,
  type QueryConstraint,
  type Unsubscribe,
} from "firebase/firestore";
import { collections, queryLimits } from "@/config/site";
import { getDb } from "@/lib/firebase/client";
import {
  mapBallEvent,
  mapChat,
  mapCommunityComment,
  mapCommunityPost,
  mapFantasyLeague,
  mapHighlight,
  mapMatch,
  mapMessage,
  mapNotification,
  mapOpportunity,
  mapOverlay,
  mapPlayer,
  mapPromotion,
  mapTeam,
  mapTournament,
  mapUser,
} from "@/lib/firebase/mappers";
import {
  BATTING_STYLE_LABELS,
  BOWLING_STYLE_LABELS,
  PLAYING_ROLE_LABELS,
  formatCfPlayerId,
  type BattingStyle,
  type BowlingStyle,
  type PlayingRole,
} from "@/lib/cricket/player-profile";
import { haversineKm, slugify } from "@/lib/utils";
import { chatIdFor, chatBlockId } from "@/lib/chat";
import { followCollection, followDocId, followPayload, type FollowKind } from "@/lib/follow";
import type { MatchStatus } from "@/types/enums";
import { LIVE_STATUSES } from "@/types/enums";
import type {
  AppNotification,
  BallEvent,
  ChatMessage,
  ChatThread,
  CommunityComment,
  CommunityPost,
  DerivedGround,
  FantasyLeague,
  HomePromotion,
  Match,
  MatchHighlight,
  OpportunityPost,
  OverlayState,
  Player,
  Team,
  Tournament,
  UserProfile,
} from "@/types/models";

function dataOf(snap: { data: () => DocumentData | undefined }) {
  return (snap.data() ?? {}) as Record<string, unknown>;
}

const FIRESTORE_READ_MS = 8_000;

function isIndexError(error: unknown) {
  return /index|FAILED_PRECONDITION/i.test(error instanceof Error ? error.message : String(error));
}

async function getDocsTimed(q: Query) {
  return Promise.race([
    getDocs(q),
    new Promise<never>((_, reject) => {
      setTimeout(() => reject(new Error("firestore-timeout")), FIRESTORE_READ_MS);
    }),
  ]);
}

async function getDocsOrEmpty(q: Query) {
  try {
    return await getDocsTimed(q);
  } catch {
    return { docs: [] };
  }
}

export async function getMatch(id: string): Promise<Match | null> {
  const snap = await getDoc(doc(getDb(), collections.matches, id));
  if (!snap.exists()) return null;
  return mapMatch(snap.id, dataOf(snap));
}

export async function listMatches(options?: {
  status?: MatchStatus | MatchStatus[];
  take?: number;
}): Promise<Match[]> {
  const take = options?.take ?? queryLimits.list;
  const constraints: QueryConstraint[] = [];
  if (options?.status) {
    const statuses = Array.isArray(options.status) ? options.status : [options.status];
    if (statuses.length === 1) {
      constraints.push(where("status", "==", statuses[0]));
    } else {
      constraints.push(where("status", "in", statuses.slice(0, 10)));
    }
  }
  constraints.push(orderBy("createdAt", "desc"), limit(take));
  try {
    const snap = await getDocsTimed(query(collection(getDb(), collections.matches), ...constraints));
    return snap.docs.map((d) => mapMatch(d.id, dataOf(d)));
  } catch (error) {
    if (!isIndexError(error)) return [];
    const snap = await getDocsOrEmpty(query(collection(getDb(), collections.matches), limit(take)));
    return snap.docs.map((d) => mapMatch(d.id, dataOf(d)));
  }
}

export function watchMatch(
  id: string,
  onData: (match: Match | null) => void,
): Unsubscribe {
  return onSnapshot(doc(getDb(), collections.matches, id), (snap) => {
    onData(snap.exists() ? mapMatch(snap.id, dataOf(snap)) : null);
  });
}

export function watchLiveMatches(
  onData: (matches: Match[]) => void,
  take = 8,
): Unsubscribe {
  return onSnapshot(
    query(
      collection(getDb(), collections.matches),
      where("status", "in", LIVE_STATUSES.slice(0, 10)),
      orderBy("createdAt", "desc"),
      limit(take),
    ),
    (snap) => {
      onData(snap.docs.map((d) => mapMatch(d.id, dataOf(d))));
    },
    () => onData([]),
  );
}

export function watchOverlay(
  matchId: string,
  onData: (overlay: OverlayState | null) => void,
): Unsubscribe {
  return onSnapshot(
    doc(getDb(), collections.matches, matchId, collections.overlay, "current"),
    (snap) => {
      onData(snap.exists() ? mapOverlay(dataOf(snap)) : null);
    },
  );
}

export async function listBallEvents(matchId: string, take = 80): Promise<BallEvent[]> {
  const snap = await getDocs(
    query(
      collection(getDb(), collections.matches, matchId, collections.ballEvents),
      orderBy("sequence", "desc"),
      limit(take),
    ),
  );
  return snap.docs
    .map((d) => mapBallEvent(d.id, dataOf(d)))
    .sort((a, b) => a.sequence - b.sequence);
}

export function watchBallEvents(
  matchId: string,
  onData: (events: BallEvent[]) => void,
  take = queryLimits.liveCommentary,
): Unsubscribe {
  return onSnapshot(
    query(
      collection(getDb(), collections.matches, matchId, collections.ballEvents),
      orderBy("sequence", "desc"),
      limit(take),
    ),
    (snap) => {
      onData(
        snap.docs
          .map((d) => mapBallEvent(d.id, dataOf(d)))
          .sort((a, b) => a.sequence - b.sequence),
      );
    },
  );
}

export async function listHighlights(matchId: string): Promise<MatchHighlight[]> {
  try {
    const snap = await getDocs(
      query(
        collection(getDb(), collections.matches, matchId, collections.highlights),
        limit(40),
      ),
    );
    return snap.docs.map((d) => mapHighlight(d.id, dataOf(d)));
  } catch {
    return [];
  }
}

export async function getTeam(id: string): Promise<Team | null> {
  const snap = await getDoc(doc(getDb(), collections.teams, id));
  if (!snap.exists()) return null;
  return mapTeam(snap.id, dataOf(snap));
}

export async function listTeams(take: number = queryLimits.list): Promise<Team[]> {
  const snap = await getDocsOrEmpty(query(collection(getDb(), collections.teams), limit(take)));
  return snap.docs.map((d) => mapTeam(d.id, dataOf(d)));
}

export async function listFollowedTeams(userId: string): Promise<Team[]> {
  if (!userId) return [];
  const snap = await getDocsOrEmpty(
    query(collection(getDb(), collections.teamFollowers), where("userId", "==", userId), limit(24)),
  );
  const ids = [
    ...new Set(snap.docs.map((d) => String(dataOf(d).teamId ?? "")).filter(Boolean)),
  ];
  const teams = await Promise.all(ids.map((id) => getTeam(id)));
  return teams.filter((team): team is Team => Boolean(team));
}

export async function listFollowedMatches(userId: string): Promise<Match[]> {
  if (!userId) return [];
  const snap = await getDocsOrEmpty(
    query(collection(getDb(), collections.matchFollowers), where("userId", "==", userId), limit(24)),
  );
  const ids = [
    ...new Set(snap.docs.map((d) => String(dataOf(d).matchId ?? "")).filter(Boolean)),
  ];
  const matches = await Promise.all(ids.map((id) => getMatch(id)));
  return matches.filter((match): match is Match => Boolean(match));
}

export async function listFollowedPlayers(userId: string): Promise<Player[]> {
  if (!userId) return [];
  const snap = await getDocsOrEmpty(
    query(
      collection(getDb(), collections.playerFollows),
      where("followerUserId", "==", userId),
      limit(24),
    ),
  );
  const followedUserIds = [
    ...new Set(snap.docs.map((d) => String(dataOf(d).followedUserId ?? "")).filter(Boolean)),
  ];
  const players = await Promise.all(followedUserIds.map((id) => getPlayerByUserId(id)));
  return players.filter((player): player is Player => Boolean(player));
}

export async function getPlayer(id: string): Promise<Player | null> {
  const snap = await getDoc(doc(getDb(), collections.players, id));
  if (!snap.exists()) return null;
  return mapPlayer(snap.id, dataOf(snap));
}

export async function getPlayerByUserId(userId: string): Promise<Player | null> {
  if (!userId) return null;
  const snap = await getDocsOrEmpty(
    query(collection(getDb(), collections.players), where("userId", "==", userId), limit(1)),
  );
  const docSnap = snap.docs[0];
  return docSnap ? mapPlayer(docSnap.id, dataOf(docSnap)) : null;
}

export async function listPlayers(take: number = queryLimits.list): Promise<Player[]> {
  const snap = await getDocsOrEmpty(query(collection(getDb(), collections.players), limit(take)));
  return snap.docs.map((d) => mapPlayer(d.id, dataOf(d)));
}

export async function getTournament(id: string): Promise<Tournament | null> {
  const snap = await getDoc(doc(getDb(), collections.tournaments, id));
  if (!snap.exists()) return null;
  return mapTournament(snap.id, dataOf(snap));
}

export async function listTournaments(take: number = queryLimits.list): Promise<Tournament[]> {
  try {
    const snap = await getDocsTimed(
      query(
        collection(getDb(), collections.tournaments),
        orderBy("createdAt", "desc"),
        limit(take),
      ),
    );
    return snap.docs.map((d) => mapTournament(d.id, dataOf(d)));
  } catch (error) {
    if (!isIndexError(error)) return [];
    const snap = await getDocsOrEmpty(
      query(collection(getDb(), collections.tournaments), limit(take)),
    );
    return snap.docs.map((d) => mapTournament(d.id, dataOf(d)));
  }
}

export async function listCommunityPosts(options?: {
  category?: string;
  authorId?: string;
  take?: number;
}): Promise<CommunityPost[]> {
  const take = options?.take ?? queryLimits.feed;
  const constraints: QueryConstraint[] = [];
  if (options?.authorId) constraints.push(where("authorId", "==", options.authorId));
  else if (options?.category) constraints.push(where("category", "==", options.category));
  constraints.push(orderBy("createdAt", "desc"), limit(take));
  try {
    const snap = await getDocsTimed(
      query(collection(getDb(), collections.communityPosts), ...constraints),
    );
    return snap.docs.map((d) => mapCommunityPost(d.id, dataOf(d)));
  } catch {
    const snap = await getDocsOrEmpty(
      query(collection(getDb(), collections.communityPosts), limit(Math.max(take, 80))),
    );
    return snap.docs
      .map((d) => mapCommunityPost(d.id, dataOf(d)))
      .filter((post) => {
        if (options?.authorId && post.authorId !== options.authorId) return false;
        if (!options?.authorId && options?.category && post.category !== options.category) return false;
        return true;
      })
      .slice(0, take);
  }
}

export async function getCommunityPost(id: string): Promise<CommunityPost | null> {
  const snap = await getDoc(doc(getDb(), collections.communityPosts, id));
  if (!snap.exists()) return null;
  return mapCommunityPost(snap.id, dataOf(snap));
}

export async function listOpportunities(options?: {
  category?: string;
  authorId?: string;
  take?: number;
}): Promise<OpportunityPost[]> {
  const take = options?.take ?? queryLimits.feed;
  const constraints: QueryConstraint[] = [where("status", "==", "active")];
  if (options?.authorId) constraints.push(where("authorId", "==", options.authorId));
  else if (options?.category) constraints.push(where("category", "==", options.category));
  constraints.push(orderBy("createdAt", "desc"), limit(take));
  try {
    const snap = await getDocsTimed(
      query(collection(getDb(), collections.opportunityPosts), ...constraints),
    );
    return snap.docs.map((d) => mapOpportunity(d.id, dataOf(d)));
  } catch (error) {
    if (!isIndexError(error)) return [];
    const snap = await getDocsOrEmpty(
      query(collection(getDb(), collections.opportunityPosts), limit(take)),
    );
    return snap.docs
      .map((d) => mapOpportunity(d.id, dataOf(d)))
      .filter((p) => {
        if (p.status !== "active") return false;
        if (options?.authorId && p.authorId !== options.authorId) return false;
        if (!options?.authorId && options?.category && p.category !== options.category) return false;
        return true;
      })
      .slice(0, take);
  }
}

export async function getOpportunity(id: string): Promise<OpportunityPost | null> {
  const snap = await getDoc(doc(getDb(), collections.opportunityPosts, id));
  if (!snap.exists()) return null;
  return mapOpportunity(snap.id, dataOf(snap));
}

export async function listPromotions(): Promise<HomePromotion[]> {
  try {
    const snap = await getDocsTimed(
      query(
        collection(getDb(), collections.homePromotions),
        where("active", "==", true),
        limit(8),
      ),
    );
    return snap.docs.map((d) => mapPromotion(d.id, dataOf(d)));
  } catch {
    return [];
  }
}

export async function getUserProfile(uid: string): Promise<UserProfile | null> {
  const snap = await getDoc(doc(getDb(), collections.users, uid));
  if (!snap.exists()) return null;
  return mapUser(snap.id, dataOf(snap));
}

export async function upsertUserProfile(profile: Partial<UserProfile> & { id: string }) {
  const payload: Record<string, unknown> = { updatedAt: new Date().toISOString() };
  if (profile.email !== undefined) payload.email = profile.email;
  if (profile.name !== undefined) payload.name = profile.name;
  if (profile.displayName !== undefined) payload.displayName = profile.displayName || profile.name || "";
  if (profile.photoUrl !== undefined) payload.photoUrl = profile.photoUrl || null;
  if (profile.role !== undefined) payload.role = profile.role;
  if (profile.phoneNumber !== undefined) payload.phoneNumber = profile.phoneNumber || null;
  if (profile.bio !== undefined) payload.bio = profile.bio;
  if (profile.location !== undefined) payload.location = profile.location;
  if (profile.playerId !== undefined) payload.playerId = profile.playerId || null;
  if (profile.playingRole !== undefined) {
    payload.playingRole = profile.playingRole || null;
    payload.playerRole = profile.playingRole || null;
  }
  if (profile.battingStyle !== undefined) payload.battingStyle = profile.battingStyle || null;
  if (profile.bowlingStyle !== undefined) payload.bowlingStyle = profile.bowlingStyle || null;
  if (profile.jerseyNumber !== undefined) payload.jerseyNumber = profile.jerseyNumber ?? null;
  if (profile.onboardingCompleted !== undefined) payload.onboardingCompleted = profile.onboardingCompleted;
  await setDoc(doc(getDb(), collections.users, profile.id), payload, { merge: true });
}

export async function allocatePlayerId(): Promise<string> {
  const counterRef = doc(getDb(), "app_meta", "cf_player_ids");
  const id = await runTransaction(getDb(), async (tx) => {
    const snap = await tx.get(counterRef);
    const last = typeof snap.data()?.lastNumber === "number" ? snap.data()!.lastNumber : 0;
    const next = last + 1;
    tx.set(
      counterRef,
      { lastNumber: next, updatedAt: new Date().toISOString() },
      { merge: true },
    );
    return formatCfPlayerId(next);
  });
  return id;
}

export async function ensurePlayerProfileForUser(payload: {
  userId: string;
  displayName: string;
  fullName?: string;
  photoUrl?: string;
  email?: string;
  playerId?: string;
}) {
  const ref = doc(getDb(), collections.players, payload.userId);
  const existing = await getDoc(ref);
  const now = new Date().toISOString();
  if (existing.exists()) {
    const merge: Record<string, unknown> = { updatedAt: now };
    if (payload.playerId) merge.playerId = payload.playerId;
    if (payload.fullName) merge.fullName = payload.fullName;
    if (Object.keys(merge).length > 1) {
      await setDoc(ref, merge, { merge: true });
    }
    return mapPlayer(payload.userId, dataOf(await getDoc(ref)));
  }
  const data: Record<string, unknown> = {
    name: payload.displayName || "Player",
    fullName: payload.fullName ?? "",
    userId: payload.userId,
    createdBy: payload.userId,
    role: "",
    battingStyle: "",
    bowlingStyle: "",
    location: {
      country: "",
      stateProvince: "",
      district: "",
      city: "",
      placeName: "",
    },
    stats: {},
    badgeIds: [],
    createdAt: now,
    updatedAt: now,
  };
  if (payload.playerId) data.playerId = payload.playerId;
  if (payload.photoUrl) data.photoUrl = payload.photoUrl;
  if (payload.email) data.email = payload.email;
  await setDoc(ref, data);
  return mapPlayer(payload.userId, data);
}

export async function updatePlayerProfile(
  playerId: string,
  patch: Partial<Player> & { id?: string },
) {
  const payload: Record<string, unknown> = { updatedAt: new Date().toISOString() };
  if (patch.name !== undefined) payload.name = patch.name;
  if (patch.photoUrl !== undefined) payload.photoUrl = patch.photoUrl ?? null;
  if (patch.role !== undefined) payload.role = patch.role;
  if (patch.battingStyle !== undefined) payload.battingStyle = patch.battingStyle;
  if (patch.bowlingStyle !== undefined) payload.bowlingStyle = patch.bowlingStyle;
  if (patch.jerseyNumber !== undefined) payload.jerseyNumber = patch.jerseyNumber ?? null;
  if (patch.playerId !== undefined) payload.playerId = patch.playerId;
  await setDoc(doc(getDb(), collections.players, playerId), payload, { merge: true });
}

export async function completePlayerOnboarding(
  profile: Partial<UserProfile> & {
    id: string;
    email: string;
    name: string;
    displayName: string;
    role: string;
    location: UserProfile["location"];
    bio: string;
    playingRole: PlayingRole;
    battingStyle: BattingStyle;
    bowlingStyle: BowlingStyle;
  },
) {
  let playerId = profile.playerId;
  if (!playerId) {
    playerId = await allocatePlayerId();
  }

  await upsertUserProfile({
    ...profile,
    playerId,
    onboardingCompleted: true,
  });

  await ensurePlayerProfileForUser({
    userId: profile.id,
    displayName: profile.displayName,
    fullName: profile.name,
    photoUrl: profile.photoUrl,
    email: profile.email,
    playerId,
  });

  await updatePlayerProfile(profile.id, {
    name: profile.displayName,
    photoUrl: profile.photoUrl,
    role: PLAYING_ROLE_LABELS[profile.playingRole],
    battingStyle: BATTING_STYLE_LABELS[profile.battingStyle],
    bowlingStyle: BOWLING_STYLE_LABELS[profile.bowlingStyle],
    jerseyNumber: profile.jerseyNumber,
    playerId,
  });
}

export function watchNotifications(
  userId: string,
  onData: (items: AppNotification[]) => void,
): Unsubscribe {
  return onSnapshot(
    query(
      collection(getDb(), collections.notifications),
      where("userId", "==", userId),
      orderBy("createdAt", "desc"),
      limit(50),
    ),
    (snap) => {
      onData(snap.docs.map((d) => mapNotification(d.id, dataOf(d))));
    },
  );
}

export async function markNotificationRead(id: string) {
  await updateDoc(doc(getDb(), collections.notifications, id), { read: true });
}

export async function markNotificationsRead(ids: string[]) {
  await Promise.all(ids.map((id) => markNotificationRead(id)));
}

export function watchChats(
  userId: string,
  onData: (items: ChatThread[]) => void,
): Unsubscribe {
  return onSnapshot(
    query(
      collection(getDb(), collections.chats),
      where("participantIds", "array-contains", userId),
      orderBy("lastMessageAt", "desc"),
      limit(80),
    ),
    (snap) => {
      onData(snap.docs.map((d) => mapChat(d.id, dataOf(d))));
    },
  );
}

export function watchMessages(
  chatId: string,
  onData: (items: ChatMessage[]) => void,
): Unsubscribe {
  return onSnapshot(
    query(
      collection(getDb(), collections.chats, chatId, "messages"),
      orderBy("createdAt", "asc"),
      limit(100),
    ),
    (snap) => {
      onData(snap.docs.map((d) => mapMessage(d.id, dataOf(d))));
    },
  );
}

export function watchChat(
  chatId: string,
  onData: (chat: ChatThread | null) => void,
): Unsubscribe {
  return onSnapshot(doc(getDb(), collections.chats, chatId), (snap) => {
    onData(snap.exists() ? mapChat(snap.id, dataOf(snap)) : null);
  });
}

export async function sendChatMessage(chatId: string, senderId: string, text: string) {
  const chatRef = doc(getDb(), collections.chats, chatId);
  const snap = await getDoc(chatRef);
  if (!snap.exists()) throw new Error("Chat not found");
  const thread = mapChat(snap.id, dataOf(snap));
  if (thread.status === "declined") throw new Error("Conversation declined");
  const unread: Record<string, number> = { ...thread.unread };
  for (const id of thread.participantIds) {
    unread[id] = id === senderId ? 0 : (unread[id] || 0) + 1;
  }
  await addDoc(collection(getDb(), collections.chats, chatId, "messages"), {
    senderId,
    text,
    createdAt: new Date().toISOString(),
    readBy: [senderId],
  });
  await updateDoc(chatRef, {
    lastMessage: text,
    lastMessageAt: new Date().toISOString(),
    lastSenderId: senderId,
    unread,
    updatedAt: new Date().toISOString(),
  });
}

export async function markChatRead(chatId: string, userId: string) {
  await updateDoc(doc(getDb(), collections.chats, chatId), {
    [`unread.${userId}`]: 0,
    updatedAt: new Date().toISOString(),
  });
}

export async function setChatStatus(chatId: string, status: "active" | "declined") {
  await updateDoc(doc(getDb(), collections.chats, chatId), { status });
}

export async function setChatArchived(chatId: string, userId: string, archived: boolean) {
  await updateDoc(doc(getDb(), collections.chats, chatId), {
    archivedBy: archived ? arrayUnion(userId) : arrayRemove(userId),
    updatedAt: new Date().toISOString(),
  });
}

export async function addCommunityComment(
  postId: string,
  payload: { authorId: string; authorName: string; body: string },
) {
  await addDoc(collection(getDb(), collections.communityPosts, postId, "comments"), {
    ...payload,
    createdAt: new Date().toISOString(),
  });
  await updateDoc(doc(getDb(), collections.communityPosts, postId), {
    commentCount: increment(1),
    updatedAt: new Date().toISOString(),
  });
}

export async function deleteCommunityComment(postId: string, commentId: string) {
  await deleteDoc(doc(getDb(), collections.communityPosts, postId, "comments", commentId));
  await updateDoc(doc(getDb(), collections.communityPosts, postId), {
    commentCount: increment(-1),
    updatedAt: new Date().toISOString(),
  });
}

export function watchCommunityComments(
  postId: string,
  onData: (items: CommunityComment[]) => void,
): Unsubscribe {
  return onSnapshot(
    query(
      collection(getDb(), collections.communityPosts, postId, "comments"),
      orderBy("createdAt", "asc"),
      limit(80),
    ),
    (snap) => {
      onData(snap.docs.map((d) => mapCommunityComment(d.id, dataOf(d))));
    },
  );
}

export function watchCommunityLiked(
  postId: string,
  userId: string,
  onData: (liked: boolean) => void,
): Unsubscribe {
  return onSnapshot(doc(getDb(), collections.communityPosts, postId, "likes", userId), (snap) => {
    onData(snap.exists());
  });
}

export async function toggleCommunityLike(postId: string, userId: string, like: boolean) {
  const db = getDb();
  const likeRef = doc(db, collections.communityPosts, postId, "likes", userId);
  const postRef = doc(db, collections.communityPosts, postId);
  await runTransaction(db, async (tx) => {
    const likeSnap = await tx.get(likeRef);
    const postSnap = await tx.get(postRef);
    if (!postSnap.exists()) return;
    const alreadyLiked = likeSnap.exists();
    if (like === alreadyLiked) return;
    const current = Number(postSnap.data()?.likeCount ?? 0);
    const nextCount = Math.max(0, current + (like ? 1 : -1));
    const now = new Date().toISOString();
    if (like) {
      tx.set(likeRef, { userId, createdAt: now });
    } else {
      tx.delete(likeRef);
    }
    tx.update(postRef, { likeCount: nextCount, updatedAt: now });
  });
}

export function watchCommunitySaved(
  postId: string,
  userId: string,
  onData: (saved: boolean) => void,
): Unsubscribe {
  return onSnapshot(doc(getDb(), collections.communityPosts, postId, "saves", userId), (snap) => {
    onData(snap.exists());
  });
}

export async function toggleCommunitySave(postId: string, userId: string, save: boolean) {
  const db = getDb();
  const saveRef = doc(db, collections.communityPosts, postId, "saves", userId);
  const postRef = doc(db, collections.communityPosts, postId);
  await runTransaction(db, async (tx) => {
    const saveSnap = await tx.get(saveRef);
    const postSnap = await tx.get(postRef);
    if (!postSnap.exists()) return;
    const alreadySaved = saveSnap.exists();
    if (save === alreadySaved) return;
    const current = Number(postSnap.data()?.saveCount ?? 0);
    const nextCount = Math.max(0, current + (save ? 1 : -1));
    const now = new Date().toISOString();
    if (save) {
      tx.set(saveRef, { userId, createdAt: now });
    } else {
      tx.delete(saveRef);
    }
    tx.update(postRef, { saveCount: nextCount, updatedAt: now });
  });
  await syncUserSavedIndex("saved_community_posts", userId, postId, save);
}

export function watchOpportunitySaved(
  postId: string,
  userId: string,
  onData: (saved: boolean) => void,
): Unsubscribe {
  return onSnapshot(doc(getDb(), collections.opportunityPosts, postId, "saves", userId), (snap) => {
    onData(snap.exists());
  });
}

export async function toggleOpportunitySave(postId: string, userId: string, save: boolean) {
  const db = getDb();
  const saveRef = doc(db, collections.opportunityPosts, postId, "saves", userId);
  const postRef = doc(db, collections.opportunityPosts, postId);
  await runTransaction(db, async (tx) => {
    const saveSnap = await tx.get(saveRef);
    const postSnap = await tx.get(postRef);
    if (!postSnap.exists()) return;
    const alreadySaved = saveSnap.exists();
    if (save === alreadySaved) return;
    const current = Number(postSnap.data()?.saveCount ?? 0);
    const nextCount = Math.max(0, current + (save ? 1 : -1));
    const now = new Date().toISOString();
    if (save) {
      tx.set(saveRef, { userId, createdAt: now });
    } else {
      tx.delete(saveRef);
    }
    tx.update(postRef, { saveCount: nextCount, updatedAt: now });
  });
  await syncUserSavedIndex("saved_opportunity_posts", userId, postId, save);
}

async function syncUserSavedIndex(
  subcollection: "saved_community_posts" | "saved_opportunity_posts",
  userId: string,
  postId: string,
  saved: boolean,
) {
  const ref = doc(getDb(), collections.users, userId, subcollection, postId);
  try {
    if (saved) {
      await setDoc(ref, { userId, postId, createdAt: new Date().toISOString() });
    } else {
      await deleteDoc(ref);
    }
  } catch {
    // Bookmark still works on the post; the profile index is best-effort.
  }
}

async function listUserSavedIds(
  userId: string,
  subcollection: "saved_community_posts" | "saved_opportunity_posts",
): Promise<string[]> {
  try {
    const snap = await getDocsTimed(
      query(
        collection(getDb(), collections.users, userId, subcollection),
        orderBy("createdAt", "desc"),
        limit(40),
      ),
    );
    return snap.docs.map((d) => d.id);
  } catch {
    const snap = await getDocsOrEmpty(query(collection(getDb(), collections.users, userId, subcollection), limit(40)));
    return snap.docs.map((d) => d.id);
  }
}

async function fetchDocsByIds<T>(
  col: string,
  ids: string[],
  map: (id: string, data: Record<string, unknown>) => T,
): Promise<T[]> {
  const ordered = ids.filter(Boolean);
  if (!ordered.length) return [];
  const snaps = await Promise.all(ordered.map((id) => getDoc(doc(getDb(), col, id))));
  const byId = new Map<string, T>();
  for (const snap of snaps) {
    if (!snap.exists()) continue;
    byId.set(snap.id, map(snap.id, dataOf(snap)));
  }
  return ordered.flatMap((id) => {
    const item = byId.get(id);
    return item ? [item] : [];
  });
}

export async function listSavedCommunityPosts(userId: string): Promise<CommunityPost[]> {
  const ids = await listUserSavedIds(userId, "saved_community_posts");
  return fetchDocsByIds(collections.communityPosts, ids, mapCommunityPost);
}

export async function listSavedOpportunityPosts(userId: string): Promise<OpportunityPost[]> {
  const ids = await listUserSavedIds(userId, "saved_opportunity_posts");
  return fetchDocsByIds(collections.opportunityPosts, ids, mapOpportunity);
}

export async function incrementOpportunityView(postId: string) {
  await updateDoc(doc(getDb(), collections.opportunityPosts, postId), {
    viewCount: increment(1),
  });
}

export async function incrementOpportunityShare(postId: string) {
  await updateDoc(doc(getDb(), collections.opportunityPosts, postId), {
    shareCount: increment(1),
    updatedAt: new Date().toISOString(),
  });
}

export async function incrementCommunityShare(postId: string) {
  await updateDoc(doc(getDb(), collections.communityPosts, postId), {
    shareCount: increment(1),
    updatedAt: new Date().toISOString(),
  });
}

export async function createCommunityPost(payload: {
  authorId: string;
  authorName: string;
  authorPhotoUrl?: string;
  title: string;
  body: string;
  category: string;
  location?: Record<string, unknown>;
  media?: { url: string; type: string; aspect: string }[];
  authorPlayerId?: string;
}) {
  await addDoc(collection(getDb(), collections.communityPosts), {
    authorId: payload.authorId,
    authorName: payload.authorName,
    authorPhotoUrl: payload.authorPhotoUrl ?? null,
    title: payload.title,
    body: payload.body,
    category: payload.category,
    likeCount: 0,
    commentCount: 0,
    shareCount: 0,
    saveCount: 0,
    media: payload.media ?? [],
    location: payload.location ?? {},
    authorPlayerId: payload.authorPlayerId ?? null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });
}

export async function createOpportunityPost(payload: {
  authorId: string;
  authorName: string;
  category: string;
  title: string;
  description: string;
  location?: Record<string, unknown>;
  mediaUrls?: string[];
  contactPhone?: string;
  contactWhatsApp?: string;
}) {
  const contactPhone = payload.contactPhone?.trim() ?? "";
  const contactWhatsApp = payload.contactWhatsApp?.trim() ?? "";
  const contactMethods = ["chat"];
  if (contactPhone) contactMethods.push("phone");
  if (contactWhatsApp) contactMethods.push("whatsapp");
  await addDoc(collection(getDb(), collections.opportunityPosts), {
    authorId: payload.authorId,
    authorName: payload.authorName,
    category: payload.category,
    title: payload.title,
    description: payload.description,
    status: "active",
    fields: {},
    tags: [],
    searchText: `${payload.title} ${payload.description}`.toLowerCase(),
    contactMethods,
    contactPhone,
    contactWhatsApp,
    mediaUrls: payload.mediaUrls ?? [],
    location: payload.location ?? {},
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });
}

export async function reportPost(
  kind: "community" | "opportunity",
  postId: string,
  reporterUserId: string,
  reason: string,
) {
  const col =
    kind === "community"
      ? collections.communityPostReports
      : collections.opportunityPostReports;
  await addDoc(collection(getDb(), col), {
    postId,
    reporterUserId,
    reason,
    status: "pending",
    createdAt: new Date().toISOString(),
  });
}

export async function deleteCommunityPost(postId: string) {
  await deleteDoc(doc(getDb(), collections.communityPosts, postId));
}

export async function deleteOpportunityPost(postId: string) {
  await deleteDoc(doc(getDb(), collections.opportunityPosts, postId));
}

export async function closeOpportunityPost(postId: string) {
  await updateDoc(doc(getDb(), collections.opportunityPosts, postId), {
    status: "removed",
    updatedAt: new Date().toISOString(),
  });
}

export async function isChatBlocked(a: string, b: string) {
  const [left, right] = await Promise.all([
    getDoc(doc(getDb(), collections.chatBlocks, chatBlockId(a, b))),
    getDoc(doc(getDb(), collections.chatBlocks, chatBlockId(b, a))),
  ]);
  return left.exists() || right.exists();
}

export function watchBlockedUserIds(
  blockerId: string,
  onData: (ids: Set<string>) => void,
): Unsubscribe {
  return onSnapshot(
    query(collection(getDb(), collections.chatBlocks), where("blockerId", "==", blockerId), limit(200)),
    (snap) => {
      onData(new Set(snap.docs.map((d) => String(dataOf(d).blockedId ?? "")).filter(Boolean)));
    },
    () => onData(new Set()),
  );
}

export async function blockUser(blockerId: string, blockedId: string) {
  if (!blockerId || !blockedId || blockerId === blockedId) {
    throw new Error("Invalid block");
  }
  await setDoc(doc(getDb(), collections.chatBlocks, chatBlockId(blockerId, blockedId)), {
    blockerId,
    blockedId,
    createdAt: new Date().toISOString(),
  });
  const chatRef = doc(getDb(), collections.chats, chatIdFor(blockerId, blockedId));
  const existing = await getDoc(chatRef);
  if (existing.exists()) {
    await updateDoc(chatRef, { status: "declined", updatedAt: new Date().toISOString() });
  }
}

export async function openOrCreateChat(me: {
  id: string;
  name: string;
  photoUrl?: string;
  playerId?: string;
}, other: {
  id: string;
  name: string;
  photoUrl?: string;
  playerId?: string;
}) {
  if (!me.id || !other.id || me.id === other.id) {
    throw new Error("Invalid participants");
  }
  if (await isChatBlocked(me.id, other.id)) {
    throw new Error("Messaging is blocked");
  }
  const chatId = chatIdFor(me.id, other.id);
  const ref = doc(getDb(), collections.chats, chatId);
  const existing = await getDoc(ref);
  if (existing.exists()) {
    const thread = mapChat(existing.id, dataOf(existing));
    if (thread.status === "declined") {
      throw new Error("This conversation was declined");
    }
    return chatId;
  }
  const now = new Date().toISOString();
  const ids = [me.id, other.id].sort();
  await setDoc(ref, {
    participantIds: ids,
    participants: {
      [me.id]: { name: me.name, photoUrl: me.photoUrl ?? null, playerId: me.playerId ?? null },
      [other.id]: { name: other.name, photoUrl: other.photoUrl ?? null, playerId: other.playerId ?? null },
    },
    lastMessage: "",
    lastMessageAt: now,
    lastSenderId: "",
    status: "request",
    requestFrom: me.id,
    unread: { [me.id]: 0, [other.id]: 0 },
    pinnedBy: [],
    mutedBy: [],
    archivedBy: [],
    createdAt: now,
    updatedAt: now,
  });
  return chatId;
}

export function watchIsFollowing(
  kind: FollowKind,
  targetId: string,
  followerUserId: string,
  onData: (following: boolean) => void,
): Unsubscribe {
  return onSnapshot(doc(getDb(), followCollection(kind), followDocId(kind, targetId, followerUserId)), (snap) => {
    onData(snap.exists());
  });
}

export async function toggleFollow(
  kind: FollowKind,
  targetId: string,
  followerUserId: string,
  follow: boolean,
  extras?: { followerPlayerId?: string; followedPlayerId?: string; followerName?: string },
) {
  if (!targetId || !followerUserId) return;
  if (kind === "player" && targetId === followerUserId) return;
  const ref = doc(getDb(), followCollection(kind), followDocId(kind, targetId, followerUserId));
  if (follow) {
    await setDoc(ref, followPayload(kind, targetId, followerUserId, extras));
  } else {
    await deleteDoc(ref);
  }
}

export async function listFantasyLeaguesForMatch(matchId: string): Promise<FantasyLeague[]> {
  if (!matchId) return [];
  const snap = await getDocsOrEmpty(
    query(collection(getDb(), collections.fantasyLeagues), where("matchId", "==", matchId), limit(8)),
  );
  return snap.docs.map((d) => mapFantasyLeague(d.id, dataOf(d)));
}

export async function listDerivedGrounds(): Promise<DerivedGround[]> {
  const [matches, tournaments] = await Promise.all([
    listMatches({ take: 80 }),
    listTournaments(40),
  ]);
  const map = new Map<string, DerivedGround>();
  const add = (name: string, location: DerivedGround["location"], from: "match" | "tournament") => {
    const trimmed = name.trim();
    if (!trimmed) return;
    const id = slugify(trimmed);
    const existing = map.get(id);
    if (existing) {
      if (from === "match") existing.matchCount += 1;
      else existing.tournamentCount += 1;
      return;
    }
    map.set(id, {
      id,
      name: trimmed,
      location,
      matchCount: from === "match" ? 1 : 0,
      tournamentCount: from === "tournament" ? 1 : 0,
    });
  };
  for (const match of matches) {
    add(match.venue || match.location.placeName, match.location, "match");
  }
  for (const tournament of tournaments) {
    for (const ground of tournament.grounds) {
      add(ground, tournament.location, "tournament");
    }
    if (tournament.location.placeName) {
      add(tournament.location.placeName, tournament.location, "tournament");
    }
  }
  return [...map.values()].sort((a, b) => b.matchCount - a.matchCount);
}

export function filterNearby<T extends { location: { latitude?: number; longitude?: number } }>(
  items: T[],
  origin: { latitude: number; longitude: number } | null,
  km = 30,
): T[] {
  if (!origin) return items;
  return items.filter((item) => {
    const { latitude, longitude } = item.location;
    if (latitude == null || longitude == null) return false;
    return haversineKm(origin.latitude, origin.longitude, latitude, longitude) <= km;
  });
}

export { LIVE_STATUSES, startAfter, serverTimestamp, arrayUnion };

export type PlayerInvite = {
  id: string;
  phoneNumber: string;
  displayName?: string;
  invitedByName: string;
  inviteType?: string;
  status: string;
  expiresAt?: string;
};

export async function getPlayerInvite(id: string): Promise<PlayerInvite | null> {
  if (!id) return null;
  const snap = await getDoc(doc(getDb(), collections.playerInvites, id));
  if (!snap.exists()) return null;
  const data = dataOf(snap);
  return {
    id: snap.id,
    phoneNumber: String(data.phoneNumber ?? ""),
    displayName: typeof data.displayName === "string" ? data.displayName : undefined,
    invitedByName: String(data.invitedByName || "A CrickFlow user"),
    inviteType: typeof data.inviteType === "string" ? data.inviteType : undefined,
    status: String(data.status || "pending"),
    expiresAt: typeof data.expiresAt === "string" ? data.expiresAt : undefined,
  };
}
