"use client";

import { useEffect, useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ReportDialog } from "@/components/shared/report-dialog";
import { useAuth } from "@/features/auth/auth-provider";
import { shareEntity } from "@/lib/share";
import { formatRelativeTime } from "@/lib/cricket/format";
import {
  addCommunityComment,
  deleteCommunityComment,
  deleteCommunityPost,
  incrementCommunityShare,
  reportPost,
  toggleCommunityLike,
  toggleCommunitySave,
  watchCommunityComments,
  watchCommunityLiked,
  watchCommunitySaved,
} from "@/repositories";
import type { CommunityComment } from "@/types/models";

export function CommunityActions({
  postId,
  authorId,
  onDeleted,
}: {
  postId: string;
  authorId: string;
  onDeleted?: () => void;
}) {
  const { user, profile } = useAuth();
  const [comment, setComment] = useState("");
  const [liked, setLiked] = useState(false);
  const [saved, setSaved] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const [comments, setComments] = useState<CommunityComment[]>([]);
  const isOwner = Boolean(user && user.uid === authorId);

  useEffect(() => {
    return watchCommunityComments(postId, setComments);
  }, [postId]);

  useEffect(() => {
    if (!user) return;
    return watchCommunityLiked(postId, user.uid, setLiked);
  }, [postId, user]);

  useEffect(() => {
    if (!user) return;
    return watchCommunitySaved(postId, user.uid, setSaved);
  }, [postId, user]);

  return (
    <div className="mt-6 flex flex-col gap-3">
      <div className="flex flex-wrap gap-2">
        <Button
          variant={liked ? "default" : "outline"}
          disabled={!user}
          onClick={async () => {
            if (!user) return;
            try {
              await toggleCommunityLike(postId, user.uid, !liked);
            } catch (error) {
              toast.error(error instanceof Error ? error.message : "Could not update like");
            }
          }}
        >
          {liked ? "Liked" : "Like"}
        </Button>
        <Button
          variant={saved ? "default" : "outline"}
          disabled={!user}
          onClick={async () => {
            if (!user) return;
            try {
              await toggleCommunitySave(postId, user.uid, !saved);
            } catch (error) {
              toast.error(error instanceof Error ? error.message : "Could not save post");
            }
          }}
        >
          {saved ? "Saved" : "Save"}
        </Button>
        <Button
          variant="outline"
          onClick={async () => {
            const copied = await shareEntity("CrickFlow post", `/community/${postId}`);
            void incrementCommunityShare(postId).catch(() => undefined);
            if (copied) toast.success("Link copied");
          }}
        >
          Share
        </Button>
        <Button variant="outline" disabled={!user} onClick={() => setReportOpen(true)}>
          Report
        </Button>
        {isOwner ? (
          <Button
            variant="outline"
            onClick={async () => {
              if (!window.confirm("Delete this post?")) return;
              try {
                await deleteCommunityPost(postId);
                toast.success("Post deleted");
                onDeleted?.();
              } catch (error) {
                toast.error(error instanceof Error ? error.message : "Could not delete");
              }
            }}
          >
            Delete
          </Button>
        ) : null}
      </div>
      {comments.length ? (
        <ul className="space-y-2 text-sm">
          {comments.map((item) => (
            <li key={item.id} className="rounded-xl bg-muted px-3 py-2">
              <p className="text-xs text-muted-foreground">
                {item.authorName}
                {item.createdAt ? ` · ${formatRelativeTime(item.createdAt)}` : ""}
              </p>
              <p>{item.body}</p>
              {user?.uid === item.authorId ? (
                <button
                  type="button"
                  className="mt-1 text-xs text-primary"
                  onClick={async () => {
                    try {
                      await deleteCommunityComment(postId, item.id);
                    } catch (error) {
                      toast.error(error instanceof Error ? error.message : "Could not delete comment");
                    }
                  }}
                >
                  Delete
                </button>
              ) : null}
            </li>
          ))}
        </ul>
      ) : null}
      {user ? (
        <form
          className="flex gap-2"
          onSubmit={async (e) => {
            e.preventDefault();
            if (!comment.trim()) return;
            await addCommunityComment(postId, {
              authorId: user.uid,
              authorName: profile?.displayName || profile?.name || user.displayName || "User",
              body: comment.trim(),
            });
            setComment("");
          }}
        >
          <Input value={comment} onChange={(e) => setComment(e.target.value)} placeholder="Write a comment" />
          <Button type="submit">Comment</Button>
        </form>
      ) : (
        <p className="text-sm text-muted-foreground">Sign in to like or comment.</p>
      )}
      <ReportDialog
        open={reportOpen}
        title="Report this post"
        onClose={() => setReportOpen(false)}
        onSubmit={async (reason) => {
          if (!user) return;
          await reportPost("community", postId, user.uid, reason);
          toast.success("Report sent");
        }}
      />
    </div>
  );
}
