"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { AppLink as Link } from "@/components/shared/app-link";
import { PageHeader } from "@/components/shared/page-shell";
import { Button } from "@/components/ui/button";
import { mailto, supportContact } from "@/config/support-contact";
import { useAuth } from "@/features/auth/auth-provider";
import { loginUrl } from "@/lib/auth/guest-access";
import {
  markUserSupportRead,
  sendUserSupportMessage,
  watchSupportMessages,
  watchSupportThread,
  type SupportMessage,
  type SupportThread,
} from "@/features/help/support-repository";

export function HelpPage() {
  const { user, profile, loading } = useAuth();
  return (
    <div className="mx-auto max-w-3xl px-4 py-8">
      <PageHeader
        eyebrow="Support"
        title="CrickFlow Help"
        description="Use the contact details below, or chat with CrickFlow staff if you are signed in."
      />
      <HelpContactCard />
      <div className="mt-8">
        {loading ? (
          <p className="text-sm text-muted-foreground">Loading chat…</p>
        ) : (
          <SupportChat
            userId={user?.uid ?? null}
            displayName={
              (profile?.displayName || profile?.name || user?.displayName || "CrickFlow user").trim()
            }
            photoUrl={profile?.photoUrl || user?.photoURL || undefined}
          />
        )}
      </div>
    </div>
  );
}

function HelpContactCard() {
  return (
    <section className="rounded-2xl border border-border bg-card p-5 shadow-sm">
      <h2 className="text-lg font-bold">Contact details</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        Reach the CrickFlow team by email, phone, or WhatsApp.
      </p>
      <ul className="mt-4 space-y-3">
        {supportContact.emails.map((email) => (
          <li key={email}>
            <ContactLink href={mailto(email)} label="Email" value={email} />
          </li>
        ))}
        <li>
          <ContactLink href={supportContact.tel} label="Phone" value={supportContact.phoneDisplay} />
        </li>
        <li>
          <ContactLink
            href={supportContact.whatsappUrl}
            label="WhatsApp"
            value={supportContact.phoneDisplay}
            external
          />
        </li>
      </ul>
    </section>
  );
}

function ContactLink({
  href,
  label,
  value,
  external,
}: {
  href: string;
  label: string;
  value: string;
  external?: boolean;
}) {
  return (
    <a
      href={href}
      className="flex items-center justify-between rounded-xl px-3 py-2 hover:bg-muted"
      {...(external ? { target: "_blank", rel: "noreferrer" } : {})}
    >
      <span>
        <span className="block text-xs text-muted-foreground">{label}</span>
        <span className="font-semibold text-primary">{value}</span>
      </span>
    </a>
  );
}

function SupportChat({
  userId,
  displayName,
  photoUrl,
}: {
  userId: string | null;
  displayName: string;
  photoUrl?: string;
}) {
  const [thread, setThread] = useState<SupportThread | null>(null);
  const [messages, setMessages] = useState<SupportMessage[]>([]);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const bottomRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!userId) return undefined;
    const unsubThread = watchSupportThread(userId, setThread, (err) => setError(err.message));
    const unsubMessages = watchSupportMessages(userId, setMessages, (err) => setError(err.message));
    return () => {
      unsubThread();
      unsubMessages();
    };
  }, [userId]);

  useEffect(() => {
    if (!userId || !thread || thread.userUnreadCount <= 0) return;
    void markUserSupportRead(userId);
  }, [userId, thread?.userUnreadCount]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length]);

  const statusCopy = useMemo(() => {
    if (!thread) return "Send a message to start a conversation.";
    if (thread.status === "resolved") {
      return "This conversation is marked resolved. Send a message to open it again.";
    }
    return "A CrickFlow teammate will reply here.";
  }, [thread]);

  if (!userId) {
    return (
      <section className="rounded-2xl border border-border bg-card p-5 shadow-sm">
        <h2 className="text-lg font-bold">Chat with CrickFlow staff</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          Sign in to start a conversation. A teammate will reply here.
        </p>
        <Button className="mt-4" asChild>
          <Link href={loginUrl("/help", "support_chat")}>Sign in</Link>
        </Button>
      </section>
    );
  }

  async function onSend() {
    const text = draft.trim();
    if (!text || sending || !userId) return;
    setSending(true);
    setError(null);
    try {
      await sendUserSupportMessage({ userId, displayName, photoUrl, text });
      setDraft("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not send that message.");
    } finally {
      setSending(false);
    }
  }

  return (
    <section className="rounded-2xl border border-border bg-card p-5 shadow-sm">
      <h2 className="text-lg font-bold">Chat with CrickFlow staff</h2>
      <p className="mt-1 text-sm text-muted-foreground">{statusCopy}</p>
      <div className="mt-4 max-h-80 space-y-3 overflow-y-auto rounded-xl bg-muted/40 p-3">
        {messages.length === 0 ? (
          <p className="py-8 text-center text-sm text-muted-foreground">No messages yet.</p>
        ) : (
          messages.map((message) => {
            const mine = message.senderId === userId && message.senderRole !== "staff";
            return (
              <div key={message.id} className={mine ? "ml-8 text-right" : "mr-8"}>
                <p className="text-xs font-semibold text-muted-foreground">
                  {mine ? "You" : message.senderName}
                </p>
                <p className="mt-1 inline-block rounded-2xl bg-background px-3 py-2 text-sm">
                  {message.text}
                </p>
              </div>
            );
          })
        )}
        <div ref={bottomRef} />
      </div>
      {error ? <p className="mt-2 text-sm text-destructive">{error}</p> : null}
      <div className="mt-3 flex gap-2">
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              void onSend();
            }
          }}
          rows={2}
          className="min-h-[2.5rem] flex-1 rounded-xl border border-border bg-background px-3 py-2 text-sm"
          placeholder="Write a message…"
        />
        <Button onClick={() => void onSend()} disabled={sending || !draft.trim()}>
          {sending ? "Sending…" : "Send"}
        </Button>
      </div>
    </section>
  );
}
