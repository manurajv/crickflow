import type { Match } from "@/types/models";

/**
 * Same rule as the app (lib/domain/scoring/match_staleness.dart): an
 * unfinished match (draft, scheduled, toss done, live, innings break) whose
 * later of scheduled/started time — or creation time — is more than 30 days
 * ago leaves Live / Upcoming lists. Display only; nothing is written.
 * Completed and abandoned matches are never stale.
 */
export const STALE_MATCH_AGE_MS = 30 * 24 * 60 * 60 * 1000;

const OPEN_STATUSES = new Set(["draft", "scheduled", "tossCompleted", "live", "inningsBreak"]);

export function matchStaleAnchor(match: Pick<Match, "scheduledAt" | "startedAt" | "createdAt">): Date | null {
  const scheduled = match.scheduledAt ?? null;
  const started = match.startedAt ?? null;
  if (scheduled && started) return scheduled > started ? scheduled : started;
  return scheduled ?? started ?? match.createdAt ?? null;
}

export function isStaleUnfinishedMatch(
  match: Pick<Match, "status" | "scheduledAt" | "startedAt" | "createdAt">,
  now: Date = new Date(),
): boolean {
  if (!OPEN_STATUSES.has(String(match.status))) return false;
  const anchor = matchStaleAnchor(match);
  if (!anchor) return false;
  return now.getTime() - anchor.getTime() > STALE_MATCH_AGE_MS;
}

/** Drops stale unfinished matches (for Live / Upcoming lists). */
export function withoutStaleMatches<T extends Pick<Match, "status" | "scheduledAt" | "startedAt" | "createdAt">>(
  matches: T[],
  now: Date = new Date(),
): T[] {
  return matches.filter((m) => !isStaleUnfinishedMatch(m, now));
}
