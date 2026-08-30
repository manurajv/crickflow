"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Textarea } from "@/components/ui/input";
import { toast } from "sonner";
import { FilterChip } from "@/components/shared/filter-chip";
import { PageHeader, LoadingGrid } from "@/components/shared/page-shell";
import { EmptyState } from "@/components/shared/states";
import { LocationOptIn } from "@/components/shared/location-opt-in";
import { MediaGallery, PhotoPicker } from "@/components/shared/media";
import { useAuth } from "@/features/auth/auth-provider";
import { useBlockedUserIds } from "@/features/chat/use-blocked";
import { formatRelativeTime, locationLabel } from "@/lib/cricket/format";
import { locationWritePayload } from "@/lib/cricket/location";
import { storageUploadHint, uploadOpportunityImages } from "@/lib/media-upload";
import { searchHaystack } from "@/lib/utils";
import { createOpportunityPost, filterNearby, listOpportunities, listSavedOpportunityPosts } from "@/repositories";
import { useLocationStore } from "@/stores/location-store";
import { OPPORTUNITY_CATEGORIES, OPPORTUNITY_LABELS } from "@/types/enums";

export default function DiscoverPage() {
  const { user, profile } = useAuth();
  const blocked = useBlockedUserIds();
  const origin = useLocationStore((s) =>
    s.consented && s.latitude != null && s.longitude != null
      ? { latitude: s.latitude, longitude: s.longitude }
      : null,
  );
  const [category, setCategory] = useState<string>("");
  const [postCategory, setPostCategory] = useState<string>("findPlayer");
  const [description, setDescription] = useState("");
  const [photos, setPhotos] = useState<File[]>([]);
  const [publishing, setPublishing] = useState(false);
  const [take, setTake] = useState(40);
  const [savedOnly, setSavedOnly] = useState(false);
  const [query, setQuery] = useState("");
  const [phone, setPhone] = useState("");
  const [whatsapp, setWhatsapp] = useState("");
  const posts = useQuery({
    queryKey: ["discover", category, take],
    queryFn: () => listOpportunities({ category: category || undefined, take }),
    enabled: !savedOnly,
  });
  const saved = useQuery({
    queryKey: ["saved-discover", user?.uid],
    queryFn: () => listSavedOpportunityPosts(user!.uid),
    enabled: Boolean(user && savedOnly),
  });

  return (
    <div className="grid gap-8 lg:grid-cols-[2fr_1fr]">
      <div>
        <PageHeader
          title="Discover"
          eyebrow="Opportunities"
          description="Find a team, player, umpire, coach, scorer, ground, and more near you."
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
          {OPPORTUNITY_CATEGORIES.filter((c) => c !== "findTournament").map((c) => (
            <FilterChip
              key={c}
              active={!savedOnly && category === c}
              onClick={() => {
                setSavedOnly(false);
                setCategory(c);
              }}
            >
              {OPPORTUNITY_LABELS[c]}
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
          placeholder="Search listings"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <div className="mt-6 space-y-3">
          {(() => {
            const loading = savedOnly ? saved.isPending : posts.isPending;
            const errored = savedOnly ? saved.isError : posts.isError;
            if (loading) return <LoadingGrid count={4} className="md:grid-cols-1" />;
            if (errored) return <EmptyState title="Could not load listings" />;
            const source = savedOnly ? saved.data ?? [] : posts.data ?? [];
            const list = (origin && !savedOnly ? filterNearby(source, origin) : source).filter((post) => {
              if (blocked.has(post.authorId)) return false;
              if (query.trim() && searchHaystack(query, [post.title, post.description, post.authorName, post.category]) <= 0) {
                return false;
              }
              return true;
            });
            if (!list.length) return <EmptyState title={savedOnly ? "No saved listings" : "No listings"} />;
            return (
              <>
                {list.map((post) => (
                  <Link key={post.id} href={`/discover/${post.id}`}>
                    <Card className="p-5 shadow-sm transition hover:border-primary/30 hover:shadow-md">
                      <p className="text-xs uppercase text-primary">
                        {OPPORTUNITY_LABELS[post.category as keyof typeof OPPORTUNITY_LABELS] ?? post.category}
                      </p>
                      <h2 className="mt-1 font-semibold">{post.title}</h2>
                      <p className="mt-1 line-clamp-3 text-sm text-muted-foreground">{post.description}</p>
                      {post.mediaUrls[0] ? <MediaGallery items={post.mediaUrls.slice(0, 1)} /> : null}
                      <p className="mt-2 text-xs">
                        {locationLabel(post.location)}
                        {post.createdAt ? ` · ${formatRelativeTime(post.createdAt)}` : ""}
                      </p>
                    </Card>
                  </Link>
                ))}
                {list.length >= take && !savedOnly ? (
                  <Button className="mt-2" variant="outline" onClick={() => setTake((n) => n + 40)}>
                    Load more
                  </Button>
                ) : null}
              </>
            );
          })()}
        </div>
      </div>
      <Card className="h-fit p-5">
        <h2 className="font-semibold">Post an opportunity</h2>
        {user ? (
          <form
            className="mt-3 space-y-3"
            onSubmit={async (e) => {
              e.preventDefault();
              if (!user) return;
              setPublishing(true);
              try {
                const mediaUrls = photos.length ? await uploadOpportunityImages(user.uid, photos) : [];
                await createOpportunityPost({
                  authorId: user.uid,
                  authorName: profile?.displayName || "CrickFlow User",
                  category: postCategory,
                  title: OPPORTUNITY_LABELS[postCategory as keyof typeof OPPORTUNITY_LABELS] ?? "Listing",
                  description,
                  location: locationWritePayload(profile?.location, origin),
                  mediaUrls,
                  contactPhone: phone,
                  contactWhatsApp: whatsapp,
                });
                setDescription("");
                setPhotos([]);
                setPhone("");
                setWhatsapp("");
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
              {OPPORTUNITY_CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {OPPORTUNITY_LABELS[c]}
                </option>
              ))}
            </select>
            <Textarea
              required
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Describe what you need"
            />
            <Input placeholder="Phone (optional)" value={phone} onChange={(e) => setPhone(e.target.value)} />
            <Input placeholder="WhatsApp (optional)" value={whatsapp} onChange={(e) => setWhatsapp(e.target.value)} />
            <PhotoPicker files={photos} onChange={setPhotos} />
            <Button className="w-full" type="submit" disabled={publishing}>
              {publishing ? "Publishing…" : "Publish"}
            </Button>
          </form>
        ) : (
          <p className="mt-2 text-sm">
            <Link className="text-primary" href="/login">
              Sign in
            </Link>{" "}
            to post.
          </p>
        )}
      </Card>
    </div>
  );
}
