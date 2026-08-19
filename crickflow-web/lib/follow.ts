export type FollowKind = "player" | "team" | "match";

/** Document ids must match Firestore rules / mobile repositories. */
export function followDocId(kind: FollowKind, targetId: string, followerUserId: string) {
  if (kind === "player") return `${followerUserId}_${targetId}`;
  return `${targetId}_${followerUserId}`;
}

export function followCollection(kind: FollowKind) {
  if (kind === "player") return "playerFollows";
  if (kind === "team") return "teamFollowers";
  return "matchFollowers";
}

export function followPayload(
  kind: FollowKind,
  targetId: string,
  followerUserId: string,
  extras?: { followerPlayerId?: string; followedPlayerId?: string; followerName?: string },
) {
  const createdAt = new Date().toISOString();
  if (kind === "player") {
    return {
      followerUserId,
      followedUserId: targetId,
      createdAt,
      ...(extras?.followerPlayerId ? { followerPlayerId: extras.followerPlayerId } : {}),
      ...(extras?.followedPlayerId ? { followedPlayerId: extras.followedPlayerId } : {}),
      ...(extras?.followerName ? { followerName: extras.followerName } : {}),
    };
  }
  if (kind === "team") {
    return { teamId: targetId, userId: followerUserId, createdAt };
  }
  return { matchId: targetId, userId: followerUserId, createdAt };
}
