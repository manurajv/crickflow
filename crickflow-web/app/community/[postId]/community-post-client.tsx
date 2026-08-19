"use client";

import { useCallback } from "react";
import { useRouter } from "next/navigation";
import { Card } from "@/components/ui/card";
import { CommunityActions } from "@/features/community/community-actions";
import { StartChatButton } from "@/features/chat/start-chat";
import { ClientEntity } from "@/components/shared/client-entity";
import { MediaGallery } from "@/components/shared/media";
import { usePathParam } from "@/lib/use-path-param";
import { formatRelativeTime } from "@/lib/cricket/format";
import { getCommunityPost } from "@/repositories";
import { COMMUNITY_LABELS } from "@/types/enums";
import type { CommunityPost } from "@/types/models";

export function CommunityPostClient() {
  const router = useRouter();
  const postId = usePathParam("postId", 1);
  const load = useCallback(() => getCommunityPost(postId), [postId]);
  if (!postId) return <p>Loading…</p>;
  return (
    <ClientEntity<CommunityPost> load={load}>
      {(post) => (
        <Card className="mx-auto max-w-3xl p-6">
          <p className="text-sm text-muted-foreground">
            {post.authorName} · {COMMUNITY_LABELS[post.category as keyof typeof COMMUNITY_LABELS] ?? post.category}
            {post.createdAt ? ` · ${formatRelativeTime(post.createdAt)}` : ""}
          </p>
          <h1 className="mt-2 text-3xl font-bold">{post.title}</h1>
          <p className="mt-4 whitespace-pre-wrap">{post.body}</p>
          <MediaGallery items={post.media} />
          <div className="mt-4">
            <StartChatButton otherId={post.authorId} otherName={post.authorName} otherPhotoUrl={post.authorPhotoUrl} />
          </div>
          <CommunityActions postId={post.id} authorId={post.authorId} onDeleted={() => router.push("/community")} />
        </Card>
      )}
    </ClientEntity>
  );
}
