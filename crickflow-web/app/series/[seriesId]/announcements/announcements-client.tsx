"use client";

import { useRef, useState } from "react";
import { AppLink as Link } from "@/components/shared/app-link";
import { AnnouncementBody } from "@/components/shared/announcement-body";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Textarea } from "@/components/ui/input";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import { useSendSeriesAnnouncement, useSeriesAnnouncements, useSeriesDetail } from "@/features/series/hooks";
import { loginUrl } from "@/lib/auth/guest-access";
import { sanitizeAnnouncementText, wrapMarkdownSelection } from "@/lib/rich-text";
import { usePathParam } from "@/lib/use-path-param";
import { friendlyError } from "@/lib/friendly-error";

const AUDIENCES: { id: "all" | "admins" | "clubAdmins" | "members"; label: string }[] = [
  { id: "all", label: "Everyone" },
  { id: "admins", label: "Admins" },
  { id: "clubAdmins", label: "Team admins" },
  { id: "members", label: "Players" },
];

export function SeriesAnnouncementsPage() {
  const seriesId = usePathParam("seriesId", 1);
  const { user, loading: authLoading } = useAuth();
  const { data, isLoading } = useSeriesAnnouncements(seriesId || "");
  const detailQ = useSeriesDetail(seriesId || "", user?.uid);
  const canPost = Boolean(detailQ.data?.canManage && detailQ.data.series.status === "active");

  if (!seriesId || authLoading || isLoading) return <p>Loading…</p>;
  if (!user) {
    return (
      <EmptyState
        title="Sign in to see announcements"
        description="Organization news is available after you sign in — same as the app."
        action={
          <Link href={loginUrl(`/series/${seriesId}/announcements`, "org_manage")}>Sign in</Link>
        }
      />
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <Link href={`/series/${seriesId}?tab=overview`} className="text-sm text-primary">
          ← Overview
        </Link>
        <h1 className="text-2xl font-bold">Announcements</h1>
      </div>
      {canPost ? <AnnouncementComposer seriesId={seriesId} /> : null}
      {!data?.length ? (
        <EmptyState
          title="No announcements yet"
          description={
            canPost
              ? "Share fixtures, deadlines, and news with your teams and players."
              : "News from the organizers will show up here."
          }
        />
      ) : (
        data.map((a) => (
          <Card key={a.id} className="space-y-2 p-4">
            <p className="font-bold">{a.title}</p>
            <AnnouncementBody body={a.body} />
            <p className="text-xs text-muted-foreground">
              {a.createdByName || "Organizer"}
              {a.createdAt ? ` · ${new Date(a.createdAt).toLocaleString()}` : ""}
              {canPost && a.audience
                ? ` · ${a.audience}${a.recipientCount != null ? ` (${a.recipientCount})` : ""}`
                : ""}
            </p>
          </Card>
        ))
      )}
    </div>
  );
}

function AnnouncementComposer({ seriesId }: { seriesId: string }) {
  const send = useSendSeriesAnnouncement(seriesId);
  const bodyRef = useRef<HTMLTextAreaElement>(null);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState<(typeof AUDIENCES)[number]["id"]>("all");
  const [preview, setPreview] = useState(false);
  const [error, setError] = useState("");

  function applyWrap(prefix: string, suffix = prefix) {
    const el = bodyRef.current;
    const start = el?.selectionStart ?? body.length;
    const end = el?.selectionEnd ?? body.length;
    const next = wrapMarkdownSelection(body, start, end, prefix, suffix);
    setBody(next.value);
    requestAnimationFrame(() => {
      el?.focus();
      el?.setSelectionRange(next.start, next.end);
    });
  }

  return (
    <Card className="space-y-3 p-4">
      <p className="font-semibold">New announcement</p>
      <p className="text-sm text-muted-foreground">
        Format with bold, italics, lists, and links. HTML is removed so the message stays safe on web and in the app.
      </p>
      <Input
        value={title}
        maxLength={120}
        onChange={(e) => setTitle(e.target.value)}
        placeholder="Title"
      />
      <div className="flex flex-wrap gap-2">
        <Button type="button" variant="outline" size="sm" onClick={() => applyWrap("**")}>
          Bold
        </Button>
        <Button type="button" variant="outline" size="sm" onClick={() => applyWrap("*")}>
          Italic
        </Button>
        <Button type="button" variant="outline" size="sm" onClick={() => applyWrap("\n- ", "")}>
          List
        </Button>
        <Button type="button" variant="outline" size="sm" onClick={() => applyWrap("[", "](https://)")}>
          Link
        </Button>
        <Button type="button" variant="outline" size="sm" onClick={() => setPreview((v) => !v)}>
          {preview ? "Edit" : "Preview"}
        </Button>
      </div>
      {preview ? (
        <div className="rounded-md border border-border p-3">
          <p className="mb-2 font-semibold">{title || "Untitled"}</p>
          <AnnouncementBody body={body} />
        </div>
      ) : (
        <Textarea
          ref={bodyRef}
          value={body}
          onChange={(e) => setBody(e.target.value)}
          minLength={1}
          maxLength={2000}
          rows={6}
          placeholder="Message"
        />
      )}
      <div>
        <p className="mb-2 text-sm font-medium">Send to</p>
        <div className="flex flex-wrap gap-2">
          {AUDIENCES.map((item) => (
            <Button
              key={item.id}
              type="button"
              size="sm"
              variant={audience === item.id ? "default" : "outline"}
              onClick={() => setAudience(item.id)}
            >
              {item.label}
            </Button>
          ))}
        </div>
      </div>
      {error ? <p className="text-sm text-destructive">{error}</p> : null}
      <Button
        type="button"
        disabled={send.isPending}
        onClick={async () => {
          const nextTitle = sanitizeAnnouncementText(title, 120);
          const nextBody = sanitizeAnnouncementText(body, 2000);
          if (nextTitle.length < 3 || !nextBody) {
            setError("Add a title (3+ characters) and a message.");
            return;
          }
          setError("");
          try {
            const result = await send.mutateAsync({ title: nextTitle, body: nextBody, audience });
            setTitle("");
            setBody("");
            setPreview(false);
            const count = result.recipientCount ?? 0;
            setError(`Sent to ${count} ${count === 1 ? "person" : "people"}.`);
          } catch (err) {
            setError(friendlyError(err, "Could not send announcement."));
          }
        }}
      >
        {send.isPending ? "Sending…" : "Send"}
      </Button>
    </Card>
  );
}
