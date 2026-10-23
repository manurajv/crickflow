"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { AppLink as Link } from "@/components/shared/app-link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import { formatRelativeTime } from "@/lib/cricket/format";
import { usePathParam } from "@/lib/use-path-param";
import { blockUser, markChatRead, sendChatMessage, setChatArchived, setChatStatus, watchChat, watchMessages } from "@/repositories";
import type { ChatMessage, ChatThread } from "@/types/models";

export function ChatConversationClient() {
  const chatId = usePathParam("id", 1);
  const { user, loading } = useAuth();
  const router = useRouter();
  const [thread, setThread] = useState<ChatThread | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [text, setText] = useState("");
  const [error, setError] = useState("");
  const [blocking, setBlocking] = useState(false);
  const endRef = useRef<HTMLLIElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  useEffect(() => {
    if (!user || !chatId) return;
    const stopChat = watchChat(chatId, setThread);
    const stopMessages = watchMessages(chatId, setMessages);
    return () => {
      stopChat();
      stopMessages();
    };
  }, [user, chatId]);

  useEffect(() => {
    if (!user || !chatId) return;
    void markChatRead(chatId, user.uid);
  }, [user, chatId, messages.length]);

  if (loading) return <p>Loading…</p>;
  if (!user) {
    return (
      <EmptyState
        title="Sign in required"
        action={
          <Link href="/login?next=/chat" className="text-primary">
            Sign in
          </Link>
        }
      />
    );
  }
  if (!chatId) return <EmptyState title="Chat not found" />;
  if (!thread) return <p>Loading conversation…</p>;

  const incomingRequest = thread.status === "request" && thread.requestFrom !== user.uid;
  const outgoingRequest = thread.status === "request" && thread.requestFrom === user.uid;
  const declined = thread.status === "declined";
  const canSend = thread.status === "active";
  const otherId = thread.participantIds.find((id) => id !== user.uid);
  const otherName = otherId ? thread.participants[otherId]?.name || "Player" : "Chat";

  return (
    <div className="mx-auto max-w-2xl">
      <div className="flex items-start justify-between gap-3">
        <h1 className="text-2xl font-bold">{otherName}</h1>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={async () => {
              const archived = thread.archivedBy?.includes(user.uid);
              await setChatArchived(chatId, user.uid, !archived);
            }}
          >
            {thread.archivedBy?.includes(user.uid) ? "Unarchive" : "Archive"}
          </Button>
          {otherId ? (
          <Button
            variant="outline"
            size="sm"
            disabled={blocking}
            onClick={async () => {
              if (!window.confirm(`Block ${otherName}? They will not be able to message you.`)) return;
              setBlocking(true);
              try {
                await blockUser(user.uid, otherId);
                router.push("/chat");
              } catch (err) {
                setError(err instanceof Error ? err.message : "Could not block");
                setBlocking(false);
              }
            }}
          >
            Block
          </Button>
        ) : null}
        </div>
      </div>
      {incomingRequest ? (
        <div className="mt-4 flex gap-2">
          <Button onClick={() => setChatStatus(chatId, "active")}>Accept</Button>
          <Button variant="outline" onClick={() => setChatStatus(chatId, "declined")}>
            Decline
          </Button>
        </div>
      ) : null}
      {outgoingRequest ? (
        <p className="mt-3 text-sm text-muted-foreground">Waiting for {otherName} to accept this request.</p>
      ) : null}
      {declined ? (
        <p className="mt-3 text-sm text-live">This conversation was declined.</p>
      ) : null}
      <ol className="mt-4 space-y-2">
        {messages.map((m) => (
          <li
            key={m.id}
            className={`max-w-[80%] rounded-2xl px-4 py-2 text-sm ${m.senderId === user.uid ? "ml-auto bg-primary text-white" : "bg-muted"}`}
          >
            {m.text}
            {m.createdAt ? (
              <p className={`mt-1 text-[10px] ${m.senderId === user.uid ? "text-white/70" : "text-muted-foreground"}`}>
                {formatRelativeTime(m.createdAt)}
              </p>
            ) : null}
          </li>
        ))}
        <li ref={endRef} className="h-0 list-none" aria-hidden />
      </ol>
      {canSend ? (
        <form
          className="mt-4 flex gap-2"
          onSubmit={async (e) => {
            e.preventDefault();
            if (!text.trim()) return;
            try {
              await sendChatMessage(chatId, user.uid, text.trim());
              setText("");
              setError("");
            } catch (err) {
              setError(err instanceof Error ? err.message : "Could not send");
            }
          }}
        >
          <Input value={text} onChange={(e) => setText(e.target.value)} placeholder="Message" />
          <Button type="submit">Send</Button>
        </form>
      ) : null}
      {error ? <p className="mt-2 text-sm text-live">{error}</p> : null}
    </div>
  );
}
