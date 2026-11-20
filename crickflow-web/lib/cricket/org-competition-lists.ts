import { isStaleUnfinishedMatch } from "@/lib/cricket/match-staleness";
import type { Match, Tournament } from "@/types/models";

/** Same chips as the app org Matches / Tournaments tabs. */
export type OrgStatusFilter = "all" | "live" | "upcoming" | "completed";

export type OrgBucket = "live" | "upcoming" | "completed";

/** Matches of one org tournament, or only standalone matches. */
export const ORG_STANDALONE_FILTER = "__standalone__";

export const ORG_STATUS_LABEL: Record<OrgStatusFilter, string> = {
  all: "All",
  live: "Live",
  upcoming: "Upcoming",
  completed: "Completed",
};

export const ORG_SECTION_TITLE: Record<OrgBucket, string> = {
  live: "Live now",
  upcoming: "Upcoming",
  completed: "Completed",
};

export interface OrgSection<T> {
  bucket: OrgBucket;
  title: string;
  items: T[];
}

const LIVE_STATUSES = new Set(["live", "inningsBreak", "tossCompleted"]);
const DONE_STATUSES = new Set(["completed", "abandoned"]);
const TOUR_UPCOMING = new Set(["upcoming", "draft"]);
const TOUR_DONE = new Set(["completed", "cancelled"]);

export function orgItemVisible(input: {
  officialStatus?: string | null;
  createdBy?: string | null;
  isAdmin: boolean;
  uid?: string | null;
}): boolean {
  const official = input.officialStatus ?? "";
  if (official === "approved") return true;
  if (official === "pendingApproval") {
    return input.isAdmin || Boolean(input.uid && input.createdBy && input.uid === input.createdBy);
  }
  return false;
}

export function visibleOrgMatches(
  matches: Match[],
  opts: { isAdmin: boolean; uid?: string | null },
): Match[] {
  return matches.filter(
    (m) =>
      m.matchMode !== "quick" &&
      orgItemVisible({
        officialStatus: m.seriesOfficialStatus,
        createdBy: m.createdBy,
        isAdmin: opts.isAdmin,
        uid: opts.uid,
      }),
  );
}

export function visibleOrgTournaments(
  tournaments: Array<Tournament & { seriesOfficialStatus?: string | null }>,
  opts: { isAdmin: boolean; uid?: string | null },
): Array<Tournament & { seriesOfficialStatus?: string | null }> {
  return tournaments.filter((t) =>
    orgItemVisible({
      officialStatus: t.seriesOfficialStatus,
      createdBy: t.createdBy ?? t.organizerId,
      isAdmin: opts.isAdmin,
      uid: opts.uid,
    }),
  );
}

export function listedOrgMatches(matches: Match[], now?: Date): Match[] {
  return matches.filter((m) => !isStaleUnfinishedMatch(m, now));
}

export function orgMatchBucket(match: Match): OrgBucket {
  const status = String(match.status);
  if (DONE_STATUSES.has(status)) return "completed";
  if (LIVE_STATUSES.has(status)) return "live";
  return "upcoming";
}

export function orgTournamentBucket(t: Pick<Tournament, "status">): OrgBucket {
  const status = String(t.status);
  if (status === "live") return "live";
  if (TOUR_DONE.has(status)) return "completed";
  if (TOUR_UPCOMING.has(status) || !status) return "upcoming";
  return "upcoming";
}

export function matchPassesTournamentFilter(m: Match, filter?: string | null): boolean {
  if (!filter) return true;
  const tid = m.tournamentId ?? "";
  if (filter === ORG_STANDALONE_FILTER) return tid === "";
  return tid === filter;
}

function matchWhen(m: Match): number {
  return (m.scheduledAt ?? m.startedAt ?? m.completedAt ?? m.createdAt ?? new Date(0)).getTime();
}

function matchDone(m: Match): number {
  return (m.completedAt ?? m.startedAt ?? m.scheduledAt ?? m.createdAt ?? new Date(0)).getTime();
}

function tournamentStart(t: Tournament): number {
  return (t.startDate ?? t.createdAt ?? new Date(0)).getTime();
}

function tournamentEnd(t: Tournament): number {
  return (t.endDate ?? t.startDate ?? t.createdAt ?? new Date(0)).getTime();
}

function matchSearchText(m: Match): string {
  return `${m.teamAName ?? ""} ${m.teamBName ?? ""} ${m.title ?? ""}`.toLowerCase();
}

/**
 * Live → Upcoming → Completed. Live: most recent first. Upcoming: soonest
 * first. Completed: latest result first. Empty sections are dropped.
 * Stale unfinished matches are omitted (same 30-day rule as the app).
 */
export function groupOrgMatches(
  matches: Match[],
  opts: { status?: OrgStatusFilter; tournamentFilter?: string | null; query?: string; now?: Date } = {},
): OrgSection<Match>[] {
  const status = opts.status ?? "all";
  const q = (opts.query ?? "").trim().toLowerCase();
  const live: Match[] = [];
  const upcoming: Match[] = [];
  const done: Match[] = [];
  for (const m of matches) {
    if (!matchPassesTournamentFilter(m, opts.tournamentFilter)) continue;
    if (isStaleUnfinishedMatch(m, opts.now)) continue;
    if (q && !matchSearchText(m).includes(q)) continue;
    switch (orgMatchBucket(m)) {
      case "live":
        live.push(m);
        break;
      case "upcoming":
        upcoming.push(m);
        break;
      case "completed":
        done.push(m);
        break;
    }
  }
  live.sort((a, b) => matchDone(b) - matchDone(a));
  upcoming.sort((a, b) => matchWhen(a) - matchWhen(b));
  done.sort((a, b) => matchDone(b) - matchDone(a));
  const want = (b: OrgBucket) => status === "all" || status === b;
  const sections: OrgSection<Match>[] = [];
  if (want("live") && live.length) sections.push({ bucket: "live", title: ORG_SECTION_TITLE.live, items: live });
  if (want("upcoming") && upcoming.length) {
    sections.push({ bucket: "upcoming", title: ORG_SECTION_TITLE.upcoming, items: upcoming });
  }
  if (want("completed") && done.length) {
    sections.push({ bucket: "completed", title: ORG_SECTION_TITLE.completed, items: done });
  }
  return sections;
}

export function groupOrgTournaments(
  tournaments: Tournament[],
  opts: { status?: OrgStatusFilter; query?: string } = {},
): OrgSection<Tournament>[] {
  const status = opts.status ?? "all";
  const q = (opts.query ?? "").trim().toLowerCase();
  const live: Tournament[] = [];
  const upcoming: Tournament[] = [];
  const done: Tournament[] = [];
  for (const t of tournaments) {
    if (q && !t.name.toLowerCase().includes(q)) continue;
    switch (orgTournamentBucket(t)) {
      case "live":
        live.push(t);
        break;
      case "upcoming":
        upcoming.push(t);
        break;
      case "completed":
        done.push(t);
        break;
    }
  }
  live.sort((a, b) => tournamentStart(b) - tournamentStart(a));
  upcoming.sort((a, b) => tournamentStart(a) - tournamentStart(b));
  done.sort((a, b) => tournamentEnd(b) - tournamentEnd(a));
  const want = (b: OrgBucket) => status === "all" || status === b;
  const sections: OrgSection<Tournament>[] = [];
  if (want("live") && live.length) sections.push({ bucket: "live", title: ORG_SECTION_TITLE.live, items: live });
  if (want("upcoming") && upcoming.length) {
    sections.push({ bucket: "upcoming", title: ORG_SECTION_TITLE.upcoming, items: upcoming });
  }
  if (want("completed") && done.length) {
    sections.push({ bucket: "completed", title: ORG_SECTION_TITLE.completed, items: done });
  }
  return sections;
}

export function orgBucketCounts<T>(items: T[], bucketOf: (item: T) => OrgBucket): Record<OrgStatusFilter, number> {
  let live = 0;
  let upcoming = 0;
  let done = 0;
  for (const i of items) {
    switch (bucketOf(i)) {
      case "live":
        live += 1;
        break;
      case "upcoming":
        upcoming += 1;
        break;
      case "completed":
        done += 1;
        break;
    }
  }
  return { all: live + upcoming + done, live, upcoming, completed: done };
}
