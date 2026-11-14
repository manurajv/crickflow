/** Staff tiers stored on series_admins.role. Legacy "seriesAdmin" / missing = admin. */
export type SeriesAdminTier = "admin" | "scorer" | "viewer";

export function parseSeriesAdminTier(raw?: string | null): SeriesAdminTier {
  const r = (raw ?? "").trim();
  if (r === "scorer") return "scorer";
  if (r === "viewer") return "viewer";
  return "admin";
}

export function seriesAdminTierLabel(raw?: string | null): string {
  const t = parseSeriesAdminTier(raw);
  if (t === "scorer") return "Scorer";
  if (t === "viewer") return "Viewer";
  return "Admin";
}

export function isFullSeriesAdminTier(raw?: string | null): boolean {
  return parseSeriesAdminTier(raw) === "admin";
}

export function canScoreSeriesTier(raw?: string | null): boolean {
  const t = parseSeriesAdminTier(raw);
  return t === "admin" || t === "scorer";
}
