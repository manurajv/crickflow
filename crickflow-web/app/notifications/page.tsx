"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/shared/states";
import { PageHeader, LoadingPage } from "@/components/shared/page-shell";
import { useAuth } from "@/features/auth/auth-provider";
import { notificationCategoryLabel, notificationHref } from "@/lib/cricket/events";
import { formatRelativeTime } from "@/lib/cricket/format";
import { markNotificationsRead, watchNotifications } from "@/repositories";
import type { AppNotification } from "@/types/models";
import {
  filterNotificationsByTab,
  relatedNotificationIds,
  unreadNotificationCounts,
  type NotificationTab,
} from "@/lib/cricket/notification-priority";
import { cn } from "@/lib/utils";

export default function NotificationsPage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const [items, setItems] = useState<AppNotification[]>([]);
  const [tab, setTab] = useState<NotificationTab>("priority");

  useEffect(() => {
    if (!user) return;
    return watchNotifications(user.uid, setItems);
  }, [user]);

  const unread = useMemo(() => unreadNotificationCounts(items), [items]);
  const list = useMemo(() => filterNotificationsByTab(items, tab), [items, tab]);

  if (loading) return <LoadingPage title="Loading notifications" />;
  if (!user) {
    return (
      <EmptyState
        title="Sign in to view notifications"
        action={<Link href="/login">Sign in</Link>}
      />
    );
  }

  return (
    <div>
      <PageHeader
        title="Notifications"
        eyebrow="Updates"
        description="Priority requests and general activity — same split as the app."
        actions={
          unread.priority + unread.general > 0 ? (
            <Button
              size="sm"
              variant="outline"
              onClick={() =>
                markNotificationsRead(items.filter((item) => !item.read).map((item) => item.id))
              }
            >
              Mark all read
            </Button>
          ) : null
        }
      />
      <div className="mb-4 flex gap-2 border-b border-border">
        {(
          [
            ["priority", "Priority", unread.priority],
            ["general", "General", unread.general],
          ] as const
        ).map(([key, label, count]) => (
          <button
            key={key}
            type="button"
            onClick={() => setTab(key)}
            className={cn(
              "border-b-2 px-4 py-2 text-sm font-medium",
              tab === key
                ? "border-[color:var(--nav-selected)] text-[color:var(--nav-selected)]"
                : "border-transparent text-muted-foreground",
            )}
          >
            {label}
            {count > 0 ? (
              <span className="ml-2 rounded-full bg-primary px-1.5 py-0.5 text-[10px] text-primary-foreground">
                {count}
              </span>
            ) : null}
          </button>
        ))}
      </div>
      <div className="space-y-2">
        {list.length === 0 ? (
          <EmptyState
            title={tab === "priority" ? "No priority alerts" : "You're all caught up"}
            description={
              tab === "priority"
                ? "Join requests and approvals that need a response appear here."
                : undefined
            }
          />
        ) : (
          list.map((item) => (
            <button
              key={item.id}
              type="button"
              className="block w-full text-left"
              onClick={async () => {
                const related = relatedNotificationIds(item, items);
                const ids = related.length ? related : item.read ? [] : [item.id];
                if (ids.length) await markNotificationsRead(ids);
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
                  <p className="mt-1 text-xs text-muted-foreground">
                    {formatRelativeTime(item.createdAt)}
                  </p>
                ) : null}
              </Card>
            </button>
          ))
        )}
      </div>
    </div>
  );
}
