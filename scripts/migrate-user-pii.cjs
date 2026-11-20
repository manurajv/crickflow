#!/usr/bin/env node
/**
 * Additive copy of email / phone / DoB from users/{uid} onto
 * users/{uid}/private/profile.
 *
 * Default is dry-run. Pass --apply to write. Never prints PII.
 *
 * Parent fields are left in place so the current Play Store app keeps working.
 */
'use strict';

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const PROJECT = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'crickflow-b06bc';
const APPLY = process.argv.includes('--apply');
const PAGE = 400;

function nonEmpty(value) {
  if (value == null) return '';
  if (value && typeof value.toDate === 'function') {
    return value.toDate().toISOString();
  }
  return String(value).trim();
}

function piiFromUser(data) {
  if (!data) return { email: '', phone: '', dob: '' };
  return {
    email: nonEmpty(data.email),
    phone: nonEmpty(data.phoneNumber) || nonEmpty(data.mobile),
    dob: nonEmpty(data.dob) || nonEmpty(data.dateOfBirth),
  };
}

function hasPii(p) {
  return Boolean(p.email || p.phone || p.dob);
}

function payloadFromParent(data) {
  const p = piiFromUser(data);
  return {
    email: p.email,
    phoneNumber: p.phone || null,
    mobile: p.phone || null,
    dob: p.dob || null,
    dateOfBirth: p.dob || null,
    updatedAt: new Date().toISOString(),
  };
}

function needsCopy(parent, existing) {
  const src = piiFromUser(parent);
  if (!hasPii(src)) return false;
  const dest = piiFromUser(existing);
  return src.email !== dest.email || src.phone !== dest.phone || src.dob !== dest.dob;
}

(async () => {
  initializeApp({ projectId: PROJECT, credential: applicationDefault() });
  const db = getFirestore();
  let scanned = 0;
  let withParentPii = 0;
  let alreadySynced = 0;
  let wouldCopy = 0;
  let copied = 0;
  let errors = 0;
  let cursor = null;

  for (;;) {
    let query = db.collection('users').orderBy('__name__').limit(PAGE);
    if (cursor) query = query.startAfter(cursor);
    const snap = await query.get();
    if (snap.empty) break;
    for (const docSnap of snap.docs) {
      scanned += 1;
      const parent = docSnap.data() || {};
      const src = piiFromUser(parent);
      if (!hasPii(src)) continue;
      withParentPii += 1;
      try {
        const privateRef = docSnap.ref.collection('private').doc('profile');
        const privateSnap = await privateRef.get();
        const existing = privateSnap.exists ? privateSnap.data() : null;
        if (!needsCopy(parent, existing)) {
          alreadySynced += 1;
          continue;
        }
        wouldCopy += 1;
        if (APPLY) {
          await privateRef.set(payloadFromParent(parent), { merge: true });
          copied += 1;
        }
      } catch (error) {
        errors += 1;
        console.error('error uid=' + docSnap.id + ' code=' + (error.code || error.message));
      }
    }
    cursor = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE) break;
  }

  console.log(APPLY ? 'MODE=apply (additive copy, parent fields kept)' : 'MODE=dry-run (no writes)');
  console.log('scanned=' + scanned);
  console.log('withParentPii=' + withParentPii);
  console.log('alreadySynced=' + alreadySynced);
  console.log('wouldCopy=' + wouldCopy);
  if (APPLY) console.log('copied=' + copied);
  console.log('errors=' + errors);
  process.exit(errors ? 1 : 0);
})().catch((error) => {
  console.error('FAIL ' + (error && error.message ? error.message : error));
  process.exit(1);
});
