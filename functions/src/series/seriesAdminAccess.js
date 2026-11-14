/**
 * Series staff role tiers on `series_admins.role`.
 *
 * - admin (legacy: seriesAdmin, missing role): full org management
 * - scorer: start / score official matches and tournaments
 * - viewer: read-only staff tools (approvals, audit)
 *
 * Existing docs with role `seriesAdmin` or no role stay full admins.
 */

const TIERS = Object.freeze({
  admin: 'admin',
  scorer: 'scorer',
  viewer: 'viewer',
});

function parseSeriesAdminTier(raw) {
  const r = String(raw || '').trim();
  if (r === TIERS.scorer) return TIERS.scorer;
  if (r === TIERS.viewer) return TIERS.viewer;
  return TIERS.admin;
}

function isFullAdminTier(tier) {
  return parseSeriesAdminTier(tier) === TIERS.admin;
}

function canScoreTier(tier) {
  const t = parseSeriesAdminTier(tier);
  return t === TIERS.admin || t === TIERS.scorer;
}

function isActiveAdminDoc(data) {
  return Boolean(data) && data.status === 'active';
}

module.exports = {
  TIERS,
  parseSeriesAdminTier,
  isFullAdminTier,
  canScoreTier,
  isActiveAdminDoc,
};
