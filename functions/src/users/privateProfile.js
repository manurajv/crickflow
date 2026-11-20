'use strict';

const PRIVATE_COLLECTION = 'private';
const PRIVATE_PROFILE_DOC = 'profile';

function nonEmpty(value) {
  if (value == null) return null;
  const text = String(value).trim();
  return text.length === 0 ? null : text;
}

function mergePrivateUserProfile(parent, privateData) {
  const out = { ...(parent || {}) };
  if (!privateData) return out;
  const email = nonEmpty(privateData.email);
  if (email) out.email = email;
  const phone = nonEmpty(privateData.phoneNumber) || nonEmpty(privateData.mobile);
  const mobile = nonEmpty(privateData.mobile) || nonEmpty(privateData.phoneNumber);
  if (phone) out.phoneNumber = phone;
  if (mobile) out.mobile = mobile;
  const dob = privateData.dob || privateData.dateOfBirth;
  if (dob) {
    out.dob = dob;
    out.dateOfBirth = dob;
  }
  return out;
}

async function loadPrivateUserProfile(db, uid) {
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection(PRIVATE_COLLECTION)
    .doc(PRIVATE_PROFILE_DOC)
    .get();
  return snap.exists ? snap.data() : null;
}

async function mergeUserDataWithPrivateProfile(db, uid, userData) {
  try {
    const privateData = await loadPrivateUserProfile(db, uid);
    return mergePrivateUserProfile(userData || {}, privateData);
  } catch (error) {
    console.warn('private profile merge skipped', uid, error && error.message);
    return userData || {};
  }
}

async function writePrivateUserProfile(db, uid, { email, phoneNumber, mobile, dateOfBirth }) {
  const phone = nonEmpty(phoneNumber) || nonEmpty(mobile);
  const dob = dateOfBirth || null;
  await db
    .collection('users')
    .doc(uid)
    .collection(PRIVATE_COLLECTION)
    .doc(PRIVATE_PROFILE_DOC)
    .set(
      {
        email: email || '',
        phoneNumber: phone,
        mobile: phone,
        dob,
        dateOfBirth: dob,
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
}

module.exports = {
  PRIVATE_COLLECTION,
  PRIVATE_PROFILE_DOC,
  mergePrivateUserProfile,
  loadPrivateUserProfile,
  mergeUserDataWithPrivateProfile,
  writePrivateUserProfile,
};
