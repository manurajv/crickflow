/* eslint-disable */
// Emulator tests for ../storage.rules registration document paths.
const { test, before, after } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc } = require('firebase/firestore');
const { ref, uploadBytes, getBytes, deleteObject } = require('firebase/storage');

let env;
const jpeg = Buffer.from(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wAAAAD/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAb/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAG/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=',
  'base64',
);
const meta = { contentType: 'image/jpeg' };

function auth(uid) {
  return env.authenticatedContext(uid);
}

before(async () => {
  const [fshost, fsport] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
  const [sthost, stport] = (process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199').split(':');
  env = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'demo-crickflow-rules',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: fshost,
      port: Number(fsport),
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'storage.rules'), 'utf8'),
      host: sthost,
      port: Number(stport),
    },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'series/s1'), {
      name: 'Series One', status: 'active', superAdminUserId: 'owner', createdBy: 'owner',
    });
    await setDoc(doc(db, 'series_admins/s1_fulladm'), {
      seriesId: 's1', userId: 'fulladm', status: 'active', role: 'admin',
    });
    await setDoc(doc(db, 'series_admins/s1_scorer1'), {
      seriesId: 's1', userId: 'scorer1', status: 'active', role: 'scorer',
    });
    await setDoc(doc(db, 'series_club_admins/s1_c1_cadm'), {
      seriesId: 's1', clubId: 'c1', userId: 'cadm', status: 'active',
    });
    await setDoc(doc(db, 'series_club_admins/s1_c2_othercadm'), {
      seriesId: 's1', clubId: 'c2', userId: 'othercadm', status: 'active',
    });
  });
});

after(async () => { await env?.cleanup(); });

const clubPath = 'series/s1/clubs/c1/registrations/player1/doc_player1_1.jpg';
const noClubPath = 'series/s1/registrations/player1/photo_player1_1.jpg';
const logoPath = 'series/s1/logo_owner.jpg';

test('registration documents are not world-readable', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), clubPath), jpeg, meta);
    await uploadBytes(ref(ctx.storage(), logoPath), jpeg, meta);
  });
  await assertFails(getBytes(ref(auth('u2').storage(), clubPath)));
  await assertSucceeds(getBytes(ref(auth('u2').storage(), logoPath)));
});

test('player, team admin, and org admin can read/write club registration docs', async () => {
  const path = 'series/s1/clubs/c1/registrations/player1/doc_cadm_2.jpg';
  await assertSucceeds(uploadBytes(ref(auth('player1').storage(), path), jpeg, meta));
  await assertSucceeds(getBytes(ref(auth('player1').storage(), path)));
  await assertSucceeds(getBytes(ref(auth('cadm').storage(), path)));
  await assertSucceeds(getBytes(ref(auth('fulladm').storage(), path)));
  await assertSucceeds(getBytes(ref(auth('owner').storage(), path)));
  await assertFails(getBytes(ref(auth('othercadm').storage(), path)));
  await assertFails(getBytes(ref(auth('scorer1').storage(), path)));
  await assertFails(getBytes(ref(auth('u2').storage(), path)));
});

test('player can upload to their no-club path and delete on failed submit', async () => {
  await assertSucceeds(uploadBytes(ref(auth('player1').storage(), noClubPath), jpeg, meta));
  await assertSucceeds(getBytes(ref(auth('player1').storage(), noClubPath)));
  await assertFails(getBytes(ref(auth('u2').storage(), noClubPath)));
  await assertSucceeds(deleteObject(ref(auth('player1').storage(), noClubPath)));
});

test('outsiders cannot upload into another player registration folder', async () => {
  const path = 'series/s1/clubs/c1/registrations/player1/doc_u2_9.jpg';
  await assertFails(uploadBytes(ref(auth('u2').storage(), path), jpeg, meta));
});

// t47: team logo is uploaded BEFORE the team doc exists (atomic create). A
// missing team doc must not break the rule (firestore.get on a missing doc
// errors in Storage rules; use firestore.exists first).
test('team images: logo upload before the team doc exists (outside and inside orgs)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'teams/orgTeamS'), {
      name: 'Org team', createdBy: 'orgmem', orgLock: { seriesId: 's1', clubId: 'c1' },
    });
    await setDoc(doc(db, 'players/orgmem'), {
      name: 'M', userId: 'orgmem', teamIds: ['orgTeamS'], teamId: 'orgTeamS', rosterChangeTeamId: 'orgTeamS',
    });
    await setDoc(doc(db, 'teams/existingT'), { name: 'Existing', createdBy: 'tcreator' });
  });
  for (const uid of ['plain', 'orgmem', 'owner', 'fulladm']) {
    const st = auth(uid).storage();
    // New normal team (doc not written yet): creator uploads, then can undo.
    const r = ref(st, `teams/newteam_${uid}/profile_${uid}.jpg`);
    await assertSucceeds(uploadBytes(r, jpeg, meta));
    await assertSucceeds(deleteObject(r));
    await assertSucceeds(uploadBytes(r, jpeg, meta));
    // Someone else's file name in the same new folder is refused.
    await assertFails(uploadBytes(ref(st, `teams/newteam_${uid}/profile_someoneelse.jpg`), jpeg, meta));
  }
  // Org-team create (CreateTeamScreen?seriesId=...) uses the same pre-doc upload.
  await assertSucceeds(uploadBytes(ref(auth('owner').storage(), 'teams/neworgteam/profile_owner.jpg'), jpeg, meta));
  // Existing team: creator only.
  await assertSucceeds(uploadBytes(ref(auth('tcreator').storage(), 'teams/existingT/profile_tcreator.jpg'), jpeg, meta));
  await assertFails(uploadBytes(ref(auth('plain').storage(), 'teams/existingT/profile_plain.jpg'), jpeg, meta));
  await assertFails(uploadBytes(ref(auth('orgmem').storage(), 'teams/existingT/profile_orgmem.jpg'), jpeg, meta));
  await assertSucceeds(uploadBytes(ref(auth('orgmem').storage(), 'teams/orgTeamS/profile_orgmem.jpg'), jpeg, meta));
  // Invite QR: creator of an existing team only; never for a team that doesn't exist.
  const png = { contentType: 'image/png' };
  await assertSucceeds(uploadBytes(ref(auth('tcreator').storage(), 'teams/existingT/invite_qr.png'), jpeg, png));
  await assertFails(uploadBytes(ref(auth('plain').storage(), 'teams/existingT/invite_qr.png'), jpeg, png));
  await assertFails(uploadBytes(ref(auth('plain').storage(), 'teams/nosuchteam/invite_qr.png'), jpeg, png));
  // Signed out: nothing.
  await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(), 'teams/x/profile_anon.jpg'), jpeg, meta));
});
