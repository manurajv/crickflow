"use client";

import {
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  type Unsubscribe,
} from "firebase/firestore";
import { collections } from "@/config/site";
import { getDb } from "@/lib/firebase/client";

export type SupportThread = {
  id: string;
  userId: string;
  userDisplayName: string;
  userPhotoUrl?: string;
  status: string;
  lastMessageAt?: Date | null;
  lastMessageText: string;
  lastSenderRole: string;
  userUnreadCount: number;
  staffUnreadCount: number;
};

export type SupportMessage = {
  id: string;
  senderId: string;
  senderName: string;
  senderRole: string;
  text: string;
  createdAt?: Date | null;
};

function asDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : new Date(parsed);
  }
  if (typeof value === "object" && value !== null && "toDate" in value) {
    const toDate = (value as { toDate: () => Date }).toDate;
    if (typeof toDate === "function") return toDate.call(value);
  }
  return null;
}

export function mapThread(id: string, data: Record<string, unknown>): SupportThread {
  const name = String(data.userDisplayName ?? "").trim();
  return {
    id,
    userId: String(data.userId ?? ""),
    userDisplayName: name || "CrickFlow user",
    userPhotoUrl: typeof data.userPhotoUrl === "string" ? data.userPhotoUrl : undefined,
    status: String(data.status ?? "open"),
    lastMessageAt: asDate(data.lastMessageAt),
    lastMessageText: String(data.lastMessageText ?? ""),
    lastSenderRole: String(data.lastSenderRole ?? ""),
    userUnreadCount: Number(data.userUnreadCount ?? 0),
    staffUnreadCount: Number(data.staffUnreadCount ?? 0),
  };
}

export function mapMessage(id: string, data: Record<string, unknown>): SupportMessage {
  const role = String(data.senderRole ?? "user");
  const name = String(data.senderName ?? "").trim();
  return {
    id,
    senderId: String(data.senderId ?? ""),
    senderName: name || (role === "staff" ? "CrickFlow staff" : "You"),
    senderRole: role,
    text: String(data.text ?? ""),
    createdAt: asDate(data.createdAt),
  };
}

function threadRef(userId: string) {
  return doc(getDb(), collections.supportThreads, userId);
}

export function watchSupportThread(
  userId: string,
  onNext: (thread: SupportThread | null) => void,
  onError?: (error: Error) => void,
): Unsubscribe {
  return onSnapshot(
    threadRef(userId),
    (snap) => {
      if (!snap.exists()) {
        onNext(null);
        return;
      }
      onNext(mapThread(snap.id, snap.data() as Record<string, unknown>));
    },
    (error) => onError?.(error),
  );
}

export function watchSupportMessages(
  threadId: string,
  onNext: (messages: SupportMessage[]) => void,
  onError?: (error: Error) => void,
): Unsubscribe {
  const q = query(
    collection(getDb(), collections.supportThreads, threadId, "messages"),
    orderBy("createdAt"),
  );
  return onSnapshot(
    q,
    (snap) => {
      onNext(snap.docs.map((d) => mapMessage(d.id, d.data() as Record<string, unknown>)));
    },
    (error) => onError?.(error),
  );
}

export async function sendUserSupportMessage(input: {
  userId: string;
  displayName: string;
  photoUrl?: string;
  text: string;
}) {
  const trimmed = input.text.trim();
  if (!trimmed) return;
  const displayName = input.displayName.trim().slice(0, 120) || "CrickFlow user";
  const db = getDb();
  const ref = threadRef(input.userId);
  const messageRef = doc(collection(db, collections.supportThreads, input.userId, "messages"));
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    const existingUnread = Number(snap.data()?.staffUnreadCount ?? 0);
    const now = serverTimestamp();
    tx.set(
      ref,
      {
        userId: input.userId,
        userDisplayName: displayName,
        ...(input.photoUrl ? { userPhotoUrl: input.photoUrl } : {}),
        status: "open",
        lastMessageAt: now,
        lastMessageText: trimmed.slice(0, 2000),
        lastSenderId: input.userId,
        lastSenderRole: "user",
        userUnreadCount: 0,
        staffUnreadCount: existingUnread + 1,
        updatedAt: now,
        ...(snap.exists() ? {} : { createdAt: now }),
      },
      { merge: true },
    );
    tx.set(messageRef, {
      senderId: input.userId,
      senderName: displayName,
      senderRole: "user",
      text: trimmed.slice(0, 2000),
      createdAt: now,
    });
  });
}

export async function markUserSupportRead(userId: string) {
  const ref = threadRef(userId);
  const db = getDb();
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) return;
    tx.set(ref, { userUnreadCount: 0 }, { merge: true });
  });
}
