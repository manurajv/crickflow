"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { EmptyState } from "@/components/shared/states";
import { PageHeader, LoadingPage } from "@/components/shared/page-shell";
import { useAuth } from "@/features/auth/auth-provider";
import { useBlockedUserIds } from "@/features/chat/use-blocked";
import { formatRelativeTime } from "@/lib/cricket/format";
import { searchHaystack } from "@/lib/utils";
import { watchChats } from "@/repositories";
import type { ChatThread } from "@/types/models";

export default function ChatListPage() {
  const { user, loading } = useAuth();
  const blocked = useBlockedUserIds();
  const [chats, setChats] = useState<ChatThread[]>([]);
  const [query, setQuery] = useState("");
  const [showArchived, setShowArchived] = useState(false);

  useEffect(() => {
    if (!user) return;
    return watchChats(user.uid, setChats);
  }, [user]);

  const visibleChats = useMemo(() => {
    if (!user) return [];
    return chats.filter((chat) => {
      const other = chat.participantIds.find((id) => id !== user.uid);
      if (other && blocked.has(other)) return false;
      const archived = chat.archivedBy?.includes(user.uid);
      if (archived && !showArchived) return false;
      if (!archived && showArchived) return false;
      if (query.trim()) {
        const name = other ? chat.participants[other]?.name : "";
        if (searchHaystack(query, [name, chat.lastMessage]) <= 0) return false;
      }
      return true;
    });
  }, [chats, user, blocked, query, showArchived]);

  if (loading) return <LoadingPage title="Loading chat" />;
  if (!user) {
    return (
      <EmptyState
        title="Sign in to chat"
        description="Direct messages use the same chats collection as mobile."
        action={
          <Link href="/login" className="text-primary">
            Sign in
          </Link>
        }
      />
    );
  }

  const inbox = visibleChats.filter((c) => c.status === "active" || c.requestFrom === user.uid);
  const requests = visibleChats.filter((c) => c.status === "request" && c.requestFrom !== user.uid);

  return (
    <div>
      <PageHeader
        title="Chat"
        eyebrow="Messages"
        description="Direct messages synced with the CrickFlow mobile app."
      />
      <div className="grid gap-8 lg:grid-cols-2">
      <section>
        <Input
          placeholder="Search conversations"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <button
          type="button"
          className="mt-2 text-sm text-primary"
          onClick={() => setShowArchived((v) => !v)}
        >
          {showArchived ? "Show inbox" : "Show archived"}
        </button>
        <div className="mt-4 space-y-2">
          {inbox.length === 0 ? (
            <EmptyState title="No conversations" />
          ) : (
            inbox.map((chat) => {
              const other = chat.participantIds.find((id) => id !== user.uid);
              const name = other ? chat.participants[other]?.name || "Player" : "Chat";
              const unread = chat.unread[user.uid] || 0;
              return (
                <Link key={chat.id} href={`/chat/${chat.id}`}>
                  <Card className="p-4 shadow-sm transition hover:border-primary/30 hover:shadow-md">
                    <div className="flex justify-between gap-3">
                      <p className="font-semibold">{name}</p>
                      {unread > 0 ? (
                        <span className="rounded-full bg-primary px-2 py-0.5 text-xs text-white">{unread}</span>
                      ) : chat.lastMessageAt ? (
                        <span className="text-xs text-muted-foreground">{formatRelativeTime(chat.lastMessageAt)}</span>
                      ) : null}
                    </div>
                    <p className="truncate text-sm text-muted-foreground">{chat.lastMessage}</p>
                  </Card>
                </Link>
              );
            })
          )}
        </div>
      </section>
      <section>
        <h2 className="text-xl font-bold">Requests</h2>
        <div className="mt-4 space-y-2">
          {requests.length === 0 ? (
            <EmptyState title="No message requests" />
          ) : (
            requests.map((chat) => {
              const other = chat.participantIds.find((id) => id !== user.uid);
              return (
                <Card key={chat.id} className="p-4">
                  <p>{other ? chat.participants[other]?.name : "Request"}</p>
                  <Link className="text-sm text-primary" href={`/chat/${chat.id}`}>
                    Review
                  </Link>
                </Card>
              );
            })
          )}
        </div>
      </section>
      </div>
    </div>
  );
}
