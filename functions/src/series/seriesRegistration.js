/**
 * Pure helpers for org player-registration settings, required fields,
 * and private document URL checks (unit-tested, no Firebase).
 */

const MAX_CUSTOM_FIELDS = 20;
const MAX_CUSTOM_LABEL = 80;

function asBool(v, defaultValue = false) {
  if (v === undefined || v === null) return defaultValue;
  return !!v;
}

function sanitizeCustomRequiredFields(list) {
  if (!Array.isArray(list)) return [];
  const out = [];
  const seen = new Set();
  for (const raw of list) {
    const label = String(raw || '').trim().slice(0, MAX_CUSTOM_LABEL);
    if (label.length < 2) continue;
    const key = label.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(label);
    if (out.length >= MAX_CUSTOM_FIELDS) break;
  }
  return out;
}

function clampPoints(v, fallback) {
  const n = Number(v);
  if (!Number.isFinite(n) || n < 0 || n > 100) return fallback;
  return Math.floor(n);
}

/**
 * Canonical org settings object written to series.settings.
 */
function normalizeSeriesSettings(settings) {
  const src = settings && typeof settings === 'object' ? settings : {};
  const ranking = src.rankingRules && typeof src.rankingRules === 'object'
    ? src.rankingRules
    : {};
  const maxSquad = Number(src.maxSquadSize);
  return {
    maxSquadSize: Number.isFinite(maxSquad) && maxSquad >= 1 && maxSquad <= 50
      ? Math.floor(maxSquad)
      : 20,
    requireFullName: src.requireFullName !== false,
    requireCrickFlowPlayerId: src.requireCrickFlowPlayerId !== false,
    requireDateOfBirth: asBool(src.requireDateOfBirth),
    requireNationalId: asBool(src.requireNationalId),
    requirePassport: asBool(src.requirePassport),
    requireNationalIdDocument: asBool(src.requireNationalIdDocument),
    requirePassportDocument: asBool(src.requirePassportDocument),
    requirePhoneNumber: asBool(src.requirePhoneNumber),
    requireAddress: asBool(src.requireAddress),
    requireProfilePhoto: asBool(src.requireProfilePhoto),
    customRequiredFields: sanitizeCustomRequiredFields(src.customRequiredFields),
    rankingRules: {
      winPoints: clampPoints(ranking.winPoints, 2),
      lossPoints: clampPoints(ranking.lossPoints, 0),
      tiePoints: clampPoints(ranking.tiePoints, 1),
      noResultPoints: clampPoints(ranking.noResultPoints, 1),
      bonusPointsEnabled: asBool(ranking.bonusPointsEnabled),
      useNetRunRate: ranking.useNetRunRate !== false,
      useRunDifference: asBool(ranking.useRunDifference),
    },
  };
}

function customFieldValue(data, key) {
  if (!data || !key) return '';
  if (data[key] != null && String(data[key]).trim()) return String(data[key]).trim();
  const custom = data.customFields && typeof data.customFields === 'object'
    ? data.customFields
    : {};
  return String(custom[key] || '').trim();
}

/**
 * @returns {string[]} missing field keys
 */
function missingRegistrationFields(settings, data) {
  const s = settings && typeof settings === 'object' ? settings : {};
  const d = data && typeof data === 'object' ? data : {};
  const missing = [];
  if (s.requireFullName !== false && !String(d.fullName || d.displayName || '').trim()) {
    missing.push('fullName');
  }
  if (s.requireCrickFlowPlayerId && !String(d.crickFlowPlayerId || '').trim()) {
    missing.push('crickFlowPlayerId');
  }
  if (s.requireDateOfBirth && !d.dateOfBirth) missing.push('dateOfBirth');
  if (s.requirePhoneNumber && !String(d.phoneNumber || '').trim()) {
    missing.push('phoneNumber');
  }
  if (s.requireAddress && !String(d.address || '').trim()) {
    missing.push('address');
  }
  if (s.requireProfilePhoto && !String(d.profilePhotoUrl || '').trim()) {
    missing.push('profilePhotoUrl');
  }
  if (s.requireNationalId && !String(d.nationalId || '').trim()) {
    missing.push('nationalId');
  }
  if (s.requirePassport && !String(d.passportNumber || '').trim()) {
    missing.push('passportNumber');
  }
  if (s.requireNationalIdDocument && !String(d.nationalIdDocUrl || '').trim()) {
    missing.push('nationalIdDocUrl');
  }
  if (s.requirePassportDocument && !String(d.passportDocUrl || '').trim()) {
    missing.push('passportDocUrl');
  }
  for (const key of s.customRequiredFields || []) {
    if (!customFieldValue(d, key)) missing.push(key);
  }
  return missing;
}

function decodeUrlPath(url) {
  try {
    const raw = String(url || '');
    if (!raw) return '';
    return decodeURIComponent(raw);
  } catch (_) {
    return String(url || '');
  }
}

/**
 * Registration photos/ID docs must live under this org and this subject user.
 * Accepts the private club path, the no-club path, and legacy series/{id}/(photo|doc)_uid_ files.
 */
function isAllowedRegistrationMediaUrl(url, { seriesId, subjectUserId, clubId } = {}) {
  if (!url) return true;
  if (!seriesId || !subjectUserId) return false;
  const path = decodeUrlPath(url);
  if (!path.includes(`/series/${seriesId}/`) && !path.includes(`series/${seriesId}/`)) {
    return false;
  }
  const uid = String(subjectUserId);
  const club = clubId ? String(clubId) : '';
  const clubPath = club
    ? `series/${seriesId}/clubs/${club}/registrations/${uid}/`
    : null;
  const noClubPath = `series/${seriesId}/registrations/${uid}/`;
  const legacyPhoto = `series/${seriesId}/photo_${uid}_`;
  const legacyDoc = `series/${seriesId}/doc_${uid}_`;
  if (clubPath && path.includes(clubPath)) return true;
  if (path.includes(noClubPath)) return true;
  if (path.includes(legacyPhoto) || path.includes(legacyDoc)) return true;
  return false;
}

function invalidRegistrationMediaUrls(data, ctx) {
  const d = data && typeof data === 'object' ? data : {};
  const bad = [];
  for (const key of ['profilePhotoUrl', 'nationalIdDocUrl', 'passportDocUrl']) {
    const url = String(d[key] || '').trim();
    if (url && !isAllowedRegistrationMediaUrl(url, ctx)) bad.push(key);
  }
  return bad;
}

module.exports = {
  MAX_CUSTOM_FIELDS,
  normalizeSeriesSettings,
  sanitizeCustomRequiredFields,
  missingRegistrationFields,
  isAllowedRegistrationMediaUrl,
  invalidRegistrationMediaUrls,
};
