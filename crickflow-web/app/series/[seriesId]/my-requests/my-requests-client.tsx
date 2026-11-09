"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import { usePathParam } from "@/lib/use-path-param";
import { loginUrl, SIGN_IN_PROMPTS } from "@/lib/auth/guest-access";

export function SeriesMyRequestsPage() {
  const seriesId = usePathParam("seriesId", 1);
  const { user } = useAuth();
  if (!seriesId) return null;
  if (!user) {
    return (
      <EmptyState
        title="Sign in required"
        description={SIGN_IN_PROMPTS.join_org}
        action={<Link href={loginUrl(`/series/${seriesId}/my-requests`, "join_org")}>Sign in</Link>}
      />
    );
  }
  return (
    <div className="space-y-4">
      <Link href={`/series/${seriesId}?tab=overview`} className="text-sm text-primary">
        ← Overview
      </Link>
      <h1 className="text-2xl font-bold">My requests</h1>
      <p className="text-sm text-muted-foreground">
        Your join and registration status for this organization appears in notifications
        and after you submit a request from the Teams tab.
      </p>
    </div>
  );
}
