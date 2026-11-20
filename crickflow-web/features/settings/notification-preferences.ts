import { doc, getDoc, setDoc } from "firebase/firestore";
import { collections } from "@/config/site";
import { getDb } from "@/lib/firebase/client";

export type NotificationPreferences = {
  receiveTeamMatchNotifications: boolean;
  receiveFollowerNotifications: boolean;
};

export const DEFAULT_NOTIFICATION_PREFERENCES: NotificationPreferences = {
  receiveTeamMatchNotifications: true,
  receiveFollowerNotifications: true,
};

function asBool(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

export function parseNotificationPreferences(data: unknown): NotificationPreferences {
  const prefs =
    data && typeof data === "object" && "notificationPrefs" in (data as object)
      ? (data as { notificationPrefs?: Record<string, unknown> }).notificationPrefs
      : (data as Record<string, unknown> | null | undefined);
  return {
    receiveTeamMatchNotifications: asBool(
      prefs?.receiveTeamMatchNotifications,
      DEFAULT_NOTIFICATION_PREFERENCES.receiveTeamMatchNotifications,
    ),
    receiveFollowerNotifications: asBool(
      prefs?.receiveFollowerNotifications,
      DEFAULT_NOTIFICATION_PREFERENCES.receiveFollowerNotifications,
    ),
  };
}

export async function getNotificationPreferences(uid: string): Promise<NotificationPreferences> {
  if (!uid) return { ...DEFAULT_NOTIFICATION_PREFERENCES };
  const snap = await getDoc(doc(getDb(), collections.users, uid));
  if (!snap.exists()) return { ...DEFAULT_NOTIFICATION_PREFERENCES };
  return parseNotificationPreferences(snap.data());
}

export async function setNotificationPreferences(
  uid: string,
  prefs: NotificationPreferences,
): Promise<void> {
  await setDoc(
    doc(getDb(), collections.users, uid),
    {
      notificationPrefs: {
        receiveTeamMatchNotifications: prefs.receiveTeamMatchNotifications,
        receiveFollowerNotifications: prefs.receiveFollowerNotifications,
      },
      updatedAt: new Date().toISOString(),
    },
    { merge: true },
  );
}
