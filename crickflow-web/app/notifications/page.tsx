"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import { notificationCategoryLabel, notificationHref } from "@/lib/cricket/events";
import { formatRelativeTime } from "@/lib/cricket/format";
import { markNotificationRead, markNotificationsRead, watchNotifications } from "@/repositories";
import type { AppNotification } from "@/types/models";

export default function NotificationsPage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const [items, setItems] = useState<AppNotification[]>([]);

  useEffect(() => {
    if (!user) return;
    return watchNotifications(user.uid, setItems);
  }, [user]);

  if (loading) return <p>Loading…</p>;
  if (!user) {
    return (
      <EmptyState
        title="Sign in to view notifications"
        action={<Link href="/login">Sign in</Link>}
      />
    );
  }

  const unread = items.filter((n) => !n.read).length;

  return (
    <div>
      <h1 className="text-3xl font-bold">Notifications</h1>
      <div className="mt-1 flex items-center gap-3 text-sm text-muted-foreground">
        <p>{unread} unread</p>
        {unread > 0 ? (
          <Button
            size="sm"
            variant="outline"
            onClick={() => markNotificationsRead(items.filter((item) => !item.read).map((item) => item.id))}
          >
            Mark all read
          </Button>
        ) : null}
      </div>
      <div className="mt-6 space-y-2">
        {items.length === 0 ? (
          <EmptyState title="You're all caught up" />
        ) : (
          items.map((item) => (
            <button
              key={item.id}
              type="button"
              className="block w-full text-left"
              onClick={async () => {
                await markNotificationRead(item.id);
                const href = notificationHref(item);
                if (href) router.push(href);
              }}
            >
              <Card className={`p-4 ${item.read ? "" : "border-primary/40"}`}>
                <p className="text-xs uppercase text-muted-foreground">
                  {notificationCategoryLabel(item.category, item.type)}
                </p>
                <p className="font-semibold">{item.title}</p>
                <p className="text-sm text-muted-foreground">{item.body}</p>
                {item.createdAt ? (
                  <p className="mt-1 text-xs text-muted-foreground">{formatRelativeTime(item.createdAt)}</p>
                ) : null}
              </Card>
            </button>
          ))
        )}
      </div>
    </div>
  );
}
