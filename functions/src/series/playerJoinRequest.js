/**
 * Org team join-request helpers: 24h cooldown, canonical doc selection,
 * storage path parsing, and duplicate-merge planning. Pure / testable.
 */

const JOIN_COOLDOWN_MS = 24 * 60 * 60 * 1000;

const CLIENT_REGISTRATION_KEYS = [
  'phoneNumber', 'address', 'dateOfBirth', 'nationalId', 'passportNumber',
  'profilePhotoUrl', 'nationalIdDocUrl', 'passportDocUrl', 'customFields',
];

function playerJoinApprovalId(clubId, userId) {
  const club = String(clubId || '').replace(/[/\\]/g, '_');
  const user = String(userId || '').replace(/[/\\]/g, '_');
  return `pj_${club}_${user}`;
}

function hasClientRegistrationPayload(data) {
  if (!data || typeof data !== 'object') return false;
  return CLIENT_REGISTRATION_KEYS.some((k) => {
    const v = data[k];
    if (v == null) return false;
    if (typeof v === 'object') return Object.keys(v).length > 0;
    return String(v).trim().length > 0;
  });
}

function parseTimeMs(value) {
  if (value == null || value === '') return 0;
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value.toMillis === 'function') {
    try { return value.toMillis(); } catch (_) { /* ignore */ }
  }
  if (typeof value.toDate === 'function') {
    try { return value.toDate().getTime(); } catch (_) { /* ignore */ }
  }
  const ms = Date.parse(String(value));
  return Number.isFinite(ms) ? ms : 0;
}

function latestSubmitTime(approval) {
  if (!approval || typeof approval !== 'object') return 0;
  const meta = approval.metadata && typeof approval.metadata === 'object'
    ? approval.metadata
    : {};
  return Math.max(
    parseTimeMs(approval.submittedAt),
    parseTimeMs(approval.requestedAt),
    parseTimeMs(approval.updatedAt),
    parseTimeMs(meta.submittedAt),
    parseTimeMs(meta.clubReviewedAt),
  );
}

function formatCooldownMessage(remainingMs) {
  const ms = Math.max(0, remainingMs);
  const totalMinutes = Math.max(1, Math.ceil(ms / 60000));
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours <= 0) {
    return `You can submit another request to this team in ${minutes} minute${minutes === 1 ? '' : 's'}.`;
  }
  if (minutes === 0) {
    return `You can submit another request to this team in ${hours} hour${hours === 1 ? '' : 's'}.`;
  }
  return `You can submit another request to this team in ${hours} hour${hours === 1 ? '' : 's'} and ${minutes} minute${minutes === 1 ? '' : 's'}.`;
}

function cooldownFrom(lastSubmitMs, nowMs = Date.now()) {
  if (!lastSubmitMs) {
    return { blocked: false, remainingMs: 0, message: '', details: {} };
  }
  const elapsed = nowMs - lastSubmitMs;
  if (elapsed >= JOIN_COOLDOWN_MS) {
    return { blocked: false, remainingMs: 0, message: '', details: {} };
  }
  const remainingMs = JOIN_COOLDOWN_MS - elapsed;
  const retryAt = new Date(lastSubmitMs + JOIN_COOLDOWN_MS).toISOString();
  const message = formatCooldownMessage(remainingMs);
  return {
    blocked: true,
    remainingMs,
    message,
    details: {
      code: 'join-cooldown',
      retryAt,
      retryAfterSeconds: Math.ceil(remainingMs / 1000),
    },
  };
}

function isPlayerJoinFor(approval, { seriesId, userId, clubId } = {}) {
  if (!approval) return false;
  if (approval.targetType !== 'playerJoin') return false;
  if (seriesId && approval.seriesId !== seriesId) return false;
  if (clubId && approval.clubId !== clubId) return false;
  const requestedBy = approval.requestedBy || (approval.metadata && approval.metadata.userId);
  if (userId && requestedBy !== userId) return false;
  return true;
}

/**
 * Keep the newest request (pending preferred when times tie). Older docs are
 * duplicates to merge into the kept one.
 */
function mergeDuplicateJoinPlan(docs) {
  const list = (docs || [])
    .filter((d) => d && d.id)
    .slice()
    .sort((a, b) => {
      const tb = latestSubmitTime(b);
      const ta = latestSubmitTime(a);
      if (tb !== ta) return tb - ta;
      if (a.status === 'pending' && b.status !== 'pending') return -1;
      if (b.status === 'pending' && a.status !== 'pending') return 1;
      return String(b.id).localeCompare(String(a.id));
    });
  if (!list.length) return { keep: null, duplicates: [] };
  return { keep: list[0], duplicates: list.slice(1) };
}

function storagePathFromUrl(url) {
  const raw = String(url || '').trim();
  if (!raw) return '';
  const gs = raw.match(/^gs:\/\/[^/]+\/(.+)$/);
  if (gs) {
    try { return decodeURIComponent(gs[1]); } catch (_) { return gs[1]; }
  }
  const encodedObject = raw.match(/\/o\/([^?]+)(?:\?|$)/);
  if (encodedObject) {
    try { return decodeURIComponent(encodedObject[1]); } catch (_) { return encodedObject[1]; }
  }
  const gcs = raw.match(/storage\.googleapis\.com\/[^/]+\/(.+?)(?:\?|$)/);
  if (gcs) {
    try { return decodeURIComponent(gcs[1]); } catch (_) { return gcs[1]; }
  }
  return '';
}

function mediaUrlFields(data) {
  const d = data && typeof data === 'object' ? data : {};
  const meta = d.metadata && typeof d.metadata === 'object' ? d.metadata : {};
  return [
    d.profilePhotoUrl,
    d.nationalIdDocUrl,
    d.passportDocUrl,
    meta.profilePhotoUrl,
    meta.nationalIdDocUrl,
    meta.passportDocUrl,
  ].map((v) => String(v || '').trim()).filter(Boolean);
}

function unusedMediaUrls(previous, next) {
  const keep = new Set(mediaUrlFields(next));
  return mediaUrlFields(previous).filter((url) => !keep.has(url));
}

module.exports = {
  JOIN_COOLDOWN_MS,
  CLIENT_REGISTRATION_KEYS,
  playerJoinApprovalId,
  hasClientRegistrationPayload,
  parseTimeMs,
  latestSubmitTime,
  formatCooldownMessage,
  cooldownFrom,
  isPlayerJoinFor,
  mergeDuplicateJoinPlan,
  storagePathFromUrl,
  mediaUrlFields,
  unusedMediaUrls,
};
