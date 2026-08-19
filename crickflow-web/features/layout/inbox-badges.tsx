"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { Bell, MessageCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/features/auth/auth-provider";
import { watchChats, watchNotifications } from "@/repositories";
import type { AppNotification, ChatThread } from "@/types/models";

export function InboxBadges() {
  const { user } = useAuth();
  const [notes, setNotes] = useState<AppNotification[]>([]);
  const [chats, setChats] = useState<ChatThread[]>([]);

  useEffect(() => {
    if (!user) return;
    const stopNotes = watchNotifications(user.uid, setNotes);
    const stopChats = watchChats(user.uid, setChats);
    return () => {
      stopNotes();
      stopChats();
    };
  }, [user]);

  const unreadNotes = useMemo(() => notes.filter((item) => !item.read).length, [notes]);
  const unreadChats = useMemo(() => {
    if (!user) return 0;
    return chats.reduce((sum, chat) => sum + (chat.unread[user.uid] || 0), 0);
  }, [chats, user]);

  if (!user) return null;

  return (
    <>
      <Button variant="ghost" size="icon" asChild className="relative">
        <Link href="/notifications" aria-label={unreadNotes ? `${unreadNotes} unread notifications` : "Notifications"}>
          <Bell className="h-5 w-5" />
          {unreadNotes > 0 ? <CountBadge value={unreadNotes} /> : null}
        </Link>
      </Button>
      <Button variant="ghost" size="icon" asChild className="relative">
        <Link href="/chat" aria-label={unreadChats ? `${unreadChats} unread chats` : "Chat"}>
          <MessageCircle className="h-5 w-5" />
          {unreadChats > 0 ? <CountBadge value={unreadChats} /> : null}
        </Link>
      </Button>
    </>
  );
}

function CountBadge({ value }: { value: number }) {
  return (
    <span className="absolute right-1 top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-live px-1 text-[10px] font-bold text-white">
      {value > 9 ? "9+" : value}
    </span>
  );
}
