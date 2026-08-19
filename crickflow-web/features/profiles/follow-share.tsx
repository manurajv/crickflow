"use client";

import { useEffect, useState } from "react";
import { toast } from "sonner";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/features/auth/auth-provider";
import { shareEntity } from "@/lib/share";
import { toggleFollow, watchIsFollowing } from "@/repositories";
import type { FollowKind } from "@/lib/follow";

export function FollowShare({
  kind,
  id,
  title,
  path,
  followedPlayerId,
}: {
  kind: FollowKind;
  /** Team id, match id, or the followed player's Firebase user id. */
  id: string;
  title: string;
  path: string;
  followedPlayerId?: string;
}) {
  const { user, profile } = useAuth();
  const [following, setFollowing] = useState(false);
  const [busy, setBusy] = useState(false);
  const canFollow = Boolean(id) && !(kind === "player" && user?.uid === id);

  useEffect(() => {
    if (!user || !canFollow) return;
    return watchIsFollowing(kind, id, user.uid, setFollowing);
  }, [user, kind, id, canFollow]);

  return (
    <div className="flex gap-2">
      <Button
        variant="outline"
        onClick={async () => {
          const copied = await shareEntity(title, path);
          if (copied) toast.success("Link copied");
        }}
      >
        Share
      </Button>
      {!canFollow ? null : user ? (
        <Button
          variant={following ? "outline" : "default"}
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            try {
              await toggleFollow(kind, id, user.uid, !following, {
                followerPlayerId: profile?.playerId,
                followedPlayerId,
                followerName: profile?.displayName || profile?.name || user.displayName || "CrickFlow user",
              });
            } catch (error) {
              toast.error(error instanceof Error ? error.message : "Could not update follow");
            } finally {
              setBusy(false);
            }
          }}
        >
          {following ? "Following" : "Follow"}
        </Button>
      ) : (
        <Button variant="outline" asChild>
          <Link href="/login">Sign in to follow</Link>
        </Button>
      )}
    </div>
  );
}
