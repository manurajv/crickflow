/**
 * Pure helpers for owner-only Series operations (ownership transfer,
 * archive / reactivate, member announcements). Kept free of Firebase so they
 * can be unit tested with `node src/series/seriesOwnerOps.test.js`.
 */

const LIFECYCLE_ACTIONS = new Set(['archive', 'reactivate']);
const ANNOUNCEMENT_AUDIENCES = new Set(['all', 'admins', 'clubAdmins', 'members']);
const MAX_ANNOUNCEMENT_RECIPIENTS = 2000;
const MAX_ANNOUNCEMENT_TITLE = 120;
const MAX_ANNOUNCEMENT_BODY = 2000;

class OwnerOpError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function seriesOwnerUid(series) {
  const superId = typeof series?.superAdminUserId === 'string'
    ? series.superAdminUserId
    : '';
  return superId || String(series?.createdBy || '');
}

function isPlatformHeld(series) {
  return series?.platformHold === true;
}

/**
 * Next status for an owner lifecycle action.
 * archive:    draft | active | suspended -> archived
 * reactivate: archived | suspended       -> active
 * A platform hold (set by CrickFlow staff) blocks both.
 */
function lifecycleNextStatus(series, action) {
  if (!LIFECYCLE_ACTIONS.has(action)) {
    throw new OwnerOpError('invalid-argument', 'action must be archive or reactivate');
  }
  if (isPlatformHeld(series)) {
    throw new OwnerOpError(
      'failed-precondition',
      'CrickFlow has put this organization on hold. Contact support to restore it.',
    );
  }
  const current = String(series?.status || 'draft');
  if (action === 'archive') {
    if (current === 'archived') {
      throw new OwnerOpError('failed-precondition', 'Already archived');
    }
    return 'archived';
  }
  if (current !== 'archived' && current !== 'suspended') {
    throw new OwnerOpError('failed-precondition', 'Only archived or suspended organizations can be reactivated');
  }
  return 'active';
}

/** Validates an ownership transfer; returns the normalized target uid. */
function validateOwnershipTransfer({ series, actorUid, targetUid, targetAdmin }) {
  const owner = seriesOwnerUid(series);
  if (!actorUid || owner !== actorUid) {
    throw new OwnerOpError('permission-denied', 'Only the owner can transfer ownership');
  }
  const target = String(targetUid || '').trim();
  if (!target) {
    throw new OwnerOpError('invalid-argument', 'Choose the new owner');
  }
  if (target === actorUid) {
    throw new OwnerOpError('invalid-argument', 'You already own this organization');
  }
  if (isPlatformHeld(series)) {
    throw new OwnerOpError('failed-precondition', 'Ownership cannot change while CrickFlow has this organization on hold');
  }
  if (!targetAdmin || targetAdmin.status !== 'active') {
    throw new OwnerOpError(
      'failed-precondition',
      'The new owner must be an active admin of this organization. Add them as an admin first.',
    );
  }
  return target;
}

function validateAnnouncement({ title, body, audience }) {
  const t = String(title || '').trim();
  const b = String(body || '').trim();
  const a = String(audience || 'all');
  if (t.length < 3 || t.length > MAX_ANNOUNCEMENT_TITLE) {
    throw new OwnerOpError('invalid-argument', `Title must be 3–${MAX_ANNOUNCEMENT_TITLE} characters`);
  }
  if (b.length < 1 || b.length > MAX_ANNOUNCEMENT_BODY) {
    throw new OwnerOpError('invalid-argument', `Message must be 1–${MAX_ANNOUNCEMENT_BODY} characters`);
  }
  if (!ANNOUNCEMENT_AUDIENCES.has(a)) {
    throw new OwnerOpError('invalid-argument', 'Unknown audience');
  }
  return { title: t, body: b, audience: a };
}

/**
 * Unique recipient uids for an announcement (sender excluded).
 * admins: owner + active series admins; clubAdmins: active club admins;
 * members: active player memberships; all: everyone above.
 */
function announcementRecipients({
  audience, ownerUid, seriesAdmins = [], clubAdmins = [], memberships = [], senderUid,
}) {
  const out = new Set();
  const addActive = (rows) => {
    for (const r of rows) {
      if (r && r.status === 'active' && typeof r.userId === 'string' && r.userId) {
        out.add(r.userId);
      }
    }
  };
  if (audience === 'all' || audience === 'admins') {
    if (ownerUid) out.add(ownerUid);
    addActive(seriesAdmins);
  }
  if (audience === 'all' || audience === 'clubAdmins') addActive(clubAdmins);
  if (audience === 'all' || audience === 'members') addActive(memberships);
  out.delete(senderUid);
  return Array.from(out).slice(0, MAX_ANNOUNCEMENT_RECIPIENTS);
}

module.exports = {
  OwnerOpError,
  seriesOwnerUid,
  isPlatformHeld,
  lifecycleNextStatus,
  validateOwnershipTransfer,
  validateAnnouncement,
  announcementRecipients,
  MAX_ANNOUNCEMENT_RECIPIENTS,
};
