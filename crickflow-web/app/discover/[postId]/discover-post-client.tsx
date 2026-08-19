"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { ClientEntity } from "@/components/shared/client-entity";
import { MediaGallery } from "@/components/shared/media";
import { ReportDialog } from "@/components/shared/report-dialog";
import { StartChatButton } from "@/features/chat/start-chat";
import { useAuth } from "@/features/auth/auth-provider";
import { formatRelativeTime, locationLabel } from "@/lib/cricket/format";
import { shareEntity } from "@/lib/share";
import { usePathParam } from "@/lib/use-path-param";
import {
  getOpportunity,
  incrementOpportunityShare,
  incrementOpportunityView,
  closeOpportunityPost,
  deleteOpportunityPost,
  reportPost,
  toggleOpportunitySave,
  watchOpportunitySaved,
} from "@/repositories";
import { OPPORTUNITY_LABELS } from "@/types/enums";
import type { OpportunityPost } from "@/types/models";

export function DiscoverPostClient() {
  const postId = usePathParam("postId", 1);
  const load = useCallback(() => getOpportunity(postId), [postId]);
  if (!postId) return <p>Loading…</p>;
  return (
    <ClientEntity<OpportunityPost> load={load}>
      {(post) => <DiscoverPostView post={post} />}
    </ClientEntity>
  );
}

function DiscoverPostView({ post }: { post: OpportunityPost }) {
  const { user } = useAuth();
  const router = useRouter();
  const [saved, setSaved] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const isOwner = Boolean(user && user.uid === post.authorId);

  useEffect(() => {
    if (user) void incrementOpportunityView(post.id).catch(() => undefined);
  }, [post.id, user]);

  useEffect(() => {
    if (!user) return;
    return watchOpportunitySaved(post.id, user.uid, setSaved);
  }, [post.id, user]);

  return (
    <Card className="mx-auto max-w-3xl p-6">
      <p className="text-xs uppercase text-primary">
        {OPPORTUNITY_LABELS[post.category as keyof typeof OPPORTUNITY_LABELS] ?? post.category}
      </p>
      <h1 className="mt-2 text-3xl font-bold">{post.title}</h1>
      <p className="mt-2 text-sm text-muted-foreground">
        {locationLabel(post.location)}
        {post.createdAt ? ` · ${formatRelativeTime(post.createdAt)}` : ""}
        {post.viewCount ? ` · ${post.viewCount} views` : ""}
      </p>
      <p className="mt-4 whitespace-pre-wrap">{post.description}</p>
      <MediaGallery items={post.mediaUrls} />
      <div className="mt-6 flex flex-wrap gap-2">
        {post.contactMethods.includes("chat") ? (
          <StartChatButton otherId={post.authorId} otherName={post.authorName} otherPhotoUrl={post.authorPhotoUrl} />
        ) : null}
        {post.contactPhone ? (
          <Button variant="outline" asChild>
            <a href={`tel:${post.contactPhone}`}>Call</a>
          </Button>
        ) : null}
        {post.contactWhatsApp ? (
          <Button variant="outline" asChild>
            <a href={`https://wa.me/${post.contactWhatsApp.replace(/\D/g, "")}`}>WhatsApp</a>
          </Button>
        ) : null}
        <Button
          variant={saved ? "default" : "outline"}
          disabled={!user}
          onClick={async () => {
            if (!user) return;
            try {
              await toggleOpportunitySave(post.id, user.uid, !saved);
            } catch (error) {
              toast.error(error instanceof Error ? error.message : "Could not save listing");
            }
          }}
        >
          {saved ? "Saved" : "Save"}
        </Button>
        <Button
          variant="outline"
          onClick={async () => {
            const copied = await shareEntity(post.title || "CrickFlow listing", `/discover/${post.id}`);
            void incrementOpportunityShare(post.id).catch(() => undefined);
            if (copied) toast.success("Link copied");
          }}
        >
          Share
        </Button>
        <Button variant="outline" disabled={!user} onClick={() => setReportOpen(true)}>
          Report
        </Button>
        {isOwner ? (
          <>
          <Button
            variant="outline"
            onClick={async () => {
              try {
                await closeOpportunityPost(post.id);
                toast.success("Listing closed");
                router.push("/discover");
              } catch (error) {
                toast.error(error instanceof Error ? error.message : "Could not close listing");
              }
            }}
          >
            Close listing
          </Button>
          <Button
            variant="outline"
            onClick={async () => {
              if (!window.confirm("Delete this listing?")) return;
              try {
                await deleteOpportunityPost(post.id);
                toast.success("Listing deleted");
                router.push("/discover");
              } catch (error) {
                toast.error(error instanceof Error ? error.message : "Could not delete");
              }
            }}
          >
            Delete
          </Button>
          </>
        ) : null}
      </div>
      <ReportDialog
        open={reportOpen}
        title="Report this listing"
        onClose={() => setReportOpen(false)}
        onSubmit={async (reason) => {
          if (!user) return;
          await reportPost("opportunity", post.id, user.uid, reason);
          toast.success("Report sent");
        }}
      />
    </Card>
  );
}
