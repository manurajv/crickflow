"use client";

import { useEffect, useState } from "react";
import { toast } from "sonner";
import { AppLink as Link } from "@/components/shared/app-link";
import { Button } from "@/components/ui/button";
import {
  DEFAULT_NOTIFICATION_PREFERENCES,
  getNotificationPreferences,
  setNotificationPreferences,
  type NotificationPreferences,
} from "@/features/settings/notification-preferences";

export function NotificationPreferencesCard({ uid }: { uid: string }) {
  const [prefs, setPrefs] = useState<NotificationPreferences>(DEFAULT_NOTIFICATION_PREFERENCES);
  const [loading, setLoading] = useState(true);
  const [savingKey, setSavingKey] = useState<keyof NotificationPreferences | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    getNotificationPreferences(uid)
      .then((next) => {
        if (!cancelled) setPrefs(next);
      })
      .catch(() => {
        if (!cancelled) toast.error("Could not load notification settings.");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [uid]);

  async function toggle(key: keyof NotificationPreferences, value: boolean) {
    const previous = prefs;
    const next = { ...prefs, [key]: value };
    setPrefs(next);
    setSavingKey(key);
    try {
      await setNotificationPreferences(uid, next);
    } catch (error) {
      setPrefs(previous);
      toast.error(error instanceof Error ? error.message : "Could not save notification settings.");
    } finally {
      setSavingKey(null);
    }
  }

  return (
    <section>
      <h2 className="font-semibold">Notifications</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        Control alerts for your teams and followed matches. These are the same preferences as in the
        CrickFlow app.
      </p>
      {loading ? (
        <p className="mt-3 text-sm text-muted-foreground">Loading notification settings…</p>
      ) : (
        <div className="mt-3 divide-y divide-border rounded-xl border border-border">
          <PreferenceToggle
            title="Receive Team Match Notifications"
            description="Match start, wickets, results, and team updates for your teams"
            checked={prefs.receiveTeamMatchNotifications}
            disabled={savingKey === "receiveTeamMatchNotifications"}
            onChange={(value) => toggle("receiveTeamMatchNotifications", value)}
          />
          <PreferenceToggle
            title="Follow Match Notifications"
            description="Alerts for matches you follow as a spectator"
            checked={prefs.receiveFollowerNotifications}
            disabled={savingKey === "receiveFollowerNotifications"}
            onChange={(value) => toggle("receiveFollowerNotifications", value)}
          />
        </div>
      )}
      <Button className="mt-3" variant="outline" asChild>
        <Link href="/notifications">Open notifications</Link>
      </Button>
    </section>
  );
}

function PreferenceToggle({
  title,
  description,
  checked,
  disabled,
  onChange,
}: {
  title: string;
  description: string;
  checked: boolean;
  disabled: boolean;
  onChange: (value: boolean) => void;
}) {
  return (
    <label className="flex cursor-pointer items-start justify-between gap-4 p-4">
      <span>
        <span className="block font-medium">{title}</span>
        <span className="mt-1 block text-sm text-muted-foreground">{description}</span>
      </span>
      <input
        type="checkbox"
        className="mt-1 h-5 w-5 shrink-0 rounded border-border accent-primary"
        checked={checked}
        disabled={disabled}
        onChange={(event) => onChange(event.target.checked)}
        aria-label={title}
      />
    </label>
  );
}
