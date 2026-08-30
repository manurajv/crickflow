"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Textarea } from "@/components/ui/input";
import { toast } from "sonner";
import { EmptyState } from "@/components/shared/states";
import { FilterChip } from "@/components/shared/filter-chip";
import { PageHeader, LoadingGrid } from "@/components/shared/page-shell";
import { LocationOptIn } from "@/components/shared/location-opt-in";
import { MediaGallery, PhotoPicker } from "@/components/shared/media";
import { useAuth } from "@/features/auth/auth-provider";
import { useBlockedUserIds } from "@/features/chat/use-blocked";
import { createCommunityPost, filterNearby, listCommunityPosts, listSavedCommunityPosts } from "@/repositories";
import { useLocationStore } from "@/stores/location-store";
import { formatRelativeTime } from "@/lib/cricket/format";
import { locationWritePayload } from "@/lib/cricket/location";
import { storageUploadHint, uploadCommunityImages } from "@/lib/media-upload";
import { searchHaystack } from "@/lib/utils";
import { COMMUNITY_CATEGORIES, COMMUNITY_LABELS } from "@/types/enums";

export default function CommunityPage() {
  const { user, profile } = useAuth();
  const blocked = useBlockedUserIds();
  const origin = useLocationStore((s) =>
    s.consented && s.latitude != null && s.longitude != null
      ? { latitude: s.latitude, longitude: s.longitude }
      : null,
  );
  const [category, setCategory] = useState<string>("");
  const [postCategory, setPostCategory] = useState<string>("general");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [photos, setPhotos] = useState<File[]>([]);
  const [publishing, setPublishing] = useState(false);
  const [take, setTake] = useState(30);
  const [savedOnly, setSavedOnly] = useState(false);
  const [query, setQuery] = useState("");
  const posts = useQuery({
    queryKey: ["community", category, take],
    queryFn: () => listCommunityPosts({ category: category || undefined, take }),
    enabled: !savedOnly,
  });
  const saved = useQuery({
    queryKey: ["saved-community", user?.uid],
    queryFn: () => listSavedCommunityPosts(user!.uid),
    enabled: Boolean(user && savedOnly),
  });
  const source = savedOnly ? saved.data ?? [] : posts.data ?? [];
  const feed = (origin && !savedOnly ? filterNearby(source, origin) : source).filter((post) => {
    if (blocked.has(post.authorId)) return false;
    if (!savedOnly && category && post.category !== category) return false;
    if (query.trim() && searchHaystack(query, [post.title, post.body, post.authorName]) <= 0) return false;
    return true;
  });

  return (
    <div className="grid gap-8 lg:grid-cols-[2fr_1fr]">
      <div>
        <PageHeader
          title="Community"
          eyebrow="Cricket social"
          description="Share updates, photos, and stories with players and fans near you."
        />
        <div className="mb-4">
          <LocationOptIn />
        </div>
        <div className="flex flex-wrap gap-2">
          <FilterChip
            active={!savedOnly && category === ""}
            onClick={() => {
              setSavedOnly(false);
              setCategory("");
            }}
          >
            All
          </FilterChip>
          {COMMUNITY_CATEGORIES.map((c) => (
            <FilterChip
              key={c}
              active={!savedOnly && category === c}
              onClick={() => {
                setSavedOnly(false);
                setCategory(c);
              }}
            >
              {COMMUNITY_LABELS[c]}
            </FilterChip>
          ))}
          {user ? (
            <FilterChip active={savedOnly} onClick={() => setSavedOnly(true)}>
              Saved
            </FilterChip>
          ) : null}
        </div>
        <Input
          className="mt-4 max-w-md"
          placeholder="Search posts"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <div className="mt-6 space-y-3">
          {(savedOnly ? saved.isPending : posts.isPending) ? (
            <LoadingGrid count={4} className="md:grid-cols-1" />
          ) : (savedOnly ? saved.isError : posts.isError) ? (
            <EmptyState title="Could not load posts" />
          ) : feed.length ? (
            feed.map((post) => (
              <Link key={post.id} href={`/community/${post.id}`}>
                <Card className="p-5 shadow-sm transition hover:border-primary/30 hover:shadow-md">
                  <p className="text-xs text-muted-foreground">
                    {post.authorName} · {COMMUNITY_LABELS[post.category as keyof typeof COMMUNITY_LABELS] ?? post.category}
                    {post.createdAt ? ` · ${formatRelativeTime(post.createdAt)}` : ""}
                  </p>
                  <h2 className="mt-1 font-semibold">{post.title || "Post"}</h2>
                  <p className="mt-1 line-clamp-3 text-sm text-muted-foreground">{post.body}</p>
                  {post.media[0]?.url && post.media[0].type !== "video" ? (
                    <MediaGallery items={post.media.slice(0, 1)} />
                  ) : null}
                  <p className="mt-2 text-xs">{post.likeCount} likes · {post.commentCount} comments</p>
                </Card>
              </Link>
            ))
          ) : (
            <EmptyState title={savedOnly ? "No saved posts" : "No posts yet"} />
          )}
          {!savedOnly && !posts.isPending && feed.length >= take ? (
            <Button className="mt-4" variant="outline" onClick={() => setTake((n) => n + 30)}>
              Load more
            </Button>
          ) : null}
        </div>
      </div>
      <Card className="h-fit p-5">
        <h2 className="font-semibold">Create a post</h2>
        {user ? (
          <form
            className="mt-3 space-y-3"
            onSubmit={async (e) => {
              e.preventDefault();
              if (!user) return;
              setPublishing(true);
              try {
                const urls = photos.length ? await uploadCommunityImages(user.uid, photos) : [];
                await createCommunityPost({
                  authorId: user.uid,
                  authorName: profile?.displayName || profile?.name || "CrickFlow User",
                  authorPhotoUrl: profile?.photoUrl,
                  title,
                  body,
                  category: postCategory,
                  location: locationWritePayload(profile?.location, origin),
                  media: urls.map((url) => ({ url, type: "image", aspect: "square" })),
                  authorPlayerId: profile?.playerId,
                });
                setTitle("");
                setBody("");
                setPhotos([]);
                posts.refetch();
              } catch (error) {
                toast.error(storageUploadHint(error));
              } finally {
                setPublishing(false);
              }
            }}
          >
            <select
              className="h-10 w-full rounded-xl border border-input bg-background px-3 text-sm"
              value={postCategory}
              onChange={(e) => setPostCategory(e.target.value)}
            >
              {COMMUNITY_CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {COMMUNITY_LABELS[c]}
                </option>
              ))}
            </select>
            <Input placeholder="Title" value={title} onChange={(e) => setTitle(e.target.value)} required />
            <Textarea placeholder="What's happening in cricket?" value={body} onChange={(e) => setBody(e.target.value)} required />
            <PhotoPicker files={photos} onChange={setPhotos} />
            <Button type="submit" className="w-full" disabled={publishing}>
              {publishing ? "Publishing…" : "Publish"}
            </Button>
          </form>
        ) : (
          <p className="mt-2 text-sm text-muted-foreground">
            <Link href="/login" className="text-primary">
              Sign in
            </Link>{" "}
            to post.
          </p>
        )}
      </Card>
    </div>
  );
}
