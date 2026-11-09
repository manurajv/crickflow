"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import type { Series } from "@/features/series/types";

const TABS = [
  { slug: "overview", label: "Overview" },
  { slug: "matches", label: "Matches" },
  { slug: "tournaments", label: "Tournaments" },
  { slug: "teams", label: "Teams" },
  { slug: "leaderboard", label: "Leaderboard" },
  { slug: "about", label: "About" },
] as const;

export type OrgTabSlug = (typeof TABS)[number]["slug"];

export function OrgDetailHeader({
  series,
  canManage,
  pendingApprovalCount,
}: {
  series: Series;
  canManage?: boolean;
  pendingApprovalCount?: number;
}) {
  return (
    <header className="rounded-3xl bg-scoreboard p-6 text-white sm:p-8">
      <div className="mb-3 flex flex-wrap items-center gap-2">
        <Link href="/series" className="text-sm text-white/80 underline-offset-2 hover:underline">
          ← Orgs
        </Link>
        <Badge className="bg-white/15 text-white">{series.status}</Badge>
        <Badge className="bg-white/15 text-white">{series.kind}</Badge>
      </div>
      <h1 className="text-3xl font-black sm:text-4xl">{series.name}</h1>
      {canManage && pendingApprovalCount != null ? (
        <p className="mt-3 text-sm font-semibold text-gold">
          Admin · {pendingApprovalCount} pending
        </p>
      ) : null}
    </header>
  );
}

export function OrgDetailTabs({
  seriesId,
  active,
}: {
  seriesId: string;
  active: OrgTabSlug;
}) {
  return (
    <nav
      className="flex gap-1 overflow-x-auto border-b border-border"
      aria-label="Organization sections"
    >
      {TABS.map((tab) => (
        <Link
          key={tab.slug}
          href={`/series/${seriesId}?tab=${tab.slug}`}
          className={cn(
            "shrink-0 border-b-2 px-3 py-2.5 text-sm font-medium transition",
            active === tab.slug
              ? "border-[color:var(--nav-selected)] text-[color:var(--nav-selected)]"
              : "border-transparent text-muted-foreground hover:text-foreground",
          )}
        >
          {tab.label}
        </Link>
      ))}
    </nav>
  );
}

export function parseOrgTab(raw: string | null | undefined): OrgTabSlug {
  const v = (raw || "overview").toLowerCase();
  if (TABS.some((t) => t.slug === v)) return v as OrgTabSlug;
  // legacy redirects
  if (v === "fixtures" || v === "players") return "matches";
  if (v === "clubs") return "teams";
  if (v === "approvals" || v === "admins" || v === "dashboard") return "overview";
  return "overview";
}
