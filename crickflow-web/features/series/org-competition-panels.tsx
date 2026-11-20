"use client";

import { useMemo, useState, type ReactNode } from "react";
import { EntityCard, MatchCard } from "@/components/shared/cards";
import { FilterChip } from "@/components/shared/filter-chip";
import { EmptyState } from "@/components/shared/states";
import type { Match, Tournament } from "@/types/models";
import {
  ORG_STANDALONE_FILTER,
  ORG_STATUS_LABEL,
  groupOrgMatches,
  groupOrgTournaments,
  listedOrgMatches,
  orgBucketCounts,
  orgMatchBucket,
  orgTournamentBucket,
  type OrgStatusFilter,
  visibleOrgMatches,
  visibleOrgTournaments,
} from "@/lib/cricket/org-competition-lists";

const STATUS_ORDER: OrgStatusFilter[] = ["all", "live", "upcoming", "completed"];

function StatusChips({
  selected,
  counts,
  onChange,
  trailing,
}: {
  selected: OrgStatusFilter;
  counts: Record<OrgStatusFilter, number>;
  onChange: (f: OrgStatusFilter) => void;
  trailing?: ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      {STATUS_ORDER.map((f) => (
        <FilterChip
          key={f}
          active={selected === f}
          live={f === "live"}
          onClick={() => onChange(f)}
        >
          {`${ORG_STATUS_LABEL[f]} (${counts[f]})`}
        </FilterChip>
      ))}
      {trailing}
    </div>
  );
}

export function OrgMatchesPanel({
  matches,
  tournaments,
  isAdmin,
  uid,
  startForm,
}: {
  matches: Match[];
  tournaments: Tournament[];
  isAdmin: boolean;
  uid?: string | null;
  startForm?: ReactNode;
}) {
  const [status, setStatus] = useState<OrgStatusFilter>("all");
  const [tournament, setTournament] = useState<string>("");
  const visible = useMemo(
    () => visibleOrgMatches(matches, { isAdmin, uid }),
    [matches, isAdmin, uid],
  );
  const listed = useMemo(
    () => listedOrgMatches(visible).filter((m) => !tournament || (tournament === ORG_STANDALONE_FILTER ? !m.tournamentId : m.tournamentId === tournament)),
    [visible, tournament],
  );
  const counts = useMemo(() => orgBucketCounts(listed, orgMatchBucket), [listed]);
  const sections = useMemo(
    () => groupOrgMatches(visible, { status, tournamentFilter: tournament || undefined }),
    [visible, status, tournament],
  );
  const approvedTours = useMemo(
    () =>
      tournaments
        .filter((t) => t.seriesOfficialStatus === "approved")
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name)),
    [tournaments],
  );

  return (
    <div className="space-y-4" data-testid="org-matches-list">
      <StatusChips
        selected={status}
        counts={counts}
        onChange={setStatus}
        trailing={
          approvedTours.length > 0 ? (
            <select
              className="rounded-full border border-border bg-background px-3 py-1.5 text-sm"
              value={tournament}
              onChange={(e) => setTournament(e.target.value)}
              aria-label="Filter by tournament"
            >
              <option value="">All competitions</option>
              <option value={ORG_STANDALONE_FILTER}>Standalone matches</option>
              {approvedTours.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
          ) : null
        }
      />
      {!sections.length ? (
        <EmptyState
          title={visible.length ? "No matches in this filter" : "No matches yet"}
          description={visible.length ? "Try another status or tournament." : "Official org matches will appear here."}
        />
      ) : (
        sections.map((section) => (
          <section key={section.bucket} className="space-y-3">
            <h3 className="text-sm font-semibold text-muted-foreground">
              {section.title} ({section.items.length})
            </h3>
            {section.items.map((m) => (
              <MatchCard key={m.id} match={m} />
            ))}
          </section>
        ))
      )}
      {startForm}
    </div>
  );
}

export function OrgTournamentsPanel({
  tournaments,
  isAdmin,
  uid,
  startForm,
}: {
  tournaments: Tournament[];
  isAdmin: boolean;
  uid?: string | null;
  startForm?: ReactNode;
}) {
  const [status, setStatus] = useState<OrgStatusFilter>("all");
  const visible = useMemo(
    () => visibleOrgTournaments(tournaments, { isAdmin, uid }),
    [tournaments, isAdmin, uid],
  );
  const counts = useMemo(() => orgBucketCounts(visible, orgTournamentBucket), [visible]);
  const sections = useMemo(() => groupOrgTournaments(visible, { status }), [visible, status]);

  return (
    <div className="space-y-4" data-testid="org-tournaments-list">
      <StatusChips selected={status} counts={counts} onChange={setStatus} />
      {!sections.length ? (
        <EmptyState
          title={visible.length ? "No tournaments in this filter" : "No tournaments yet"}
          description={visible.length ? "Try another status." : "Official org tournaments will appear here."}
        />
      ) : (
        sections.map((section) => (
          <section key={section.bucket} className="space-y-3">
            <h3 className="text-sm font-semibold text-muted-foreground">
              {section.title} ({section.items.length})
            </h3>
            {section.items.map((t) => (
              <EntityCard
                key={t.id}
                href={`/tournaments/${t.id}`}
                title={t.name}
                subtitle={String(t.status)}
                meta={t.startDate ? t.startDate.toLocaleDateString() : undefined}
              />
            ))}
          </section>
        ))
      )}
      {startForm}
    </div>
  );
}

/** Visible listed counts for overview tiles (same rules as the tab All chips). */
export function orgOverviewCounts(
  matches: Match[],
  tournaments: Tournament[],
  opts: { isAdmin: boolean; uid?: string | null },
) {
  const listed = listedOrgMatches(visibleOrgMatches(matches, opts));
  const tours = visibleOrgTournaments(tournaments, opts);
  return { matchCount: listed.length, tournamentCount: tours.length };
}
