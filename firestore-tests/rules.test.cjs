/* eslint-disable */
// Emulator tests for ../firestore.rules.
// Run: cd firestore-tests && npm install && npm test   (needs Java 11+)
const { test, before, after } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where,
  getDocs, writeBatch, addDoc,
} = require('firebase/firestore');

let env;
const NOW = '2026-10-08T00:00:00.000Z';
const audit = (uid) => ({ action: 'x', actorUid: uid, actorEmail: `${uid}@x.test`, targetUid: 't', timestamp: NOW });

// Mirrors production admin_roles (25 keys, 2026-10-08) after allowedPanel fix.
const ALL = [
  'canViewDashboard', 'canViewProfile', 'canManageAccount', 'canManageUsers',
  'canManageOrganizations', 'canManageTeams', 'canManagePlayers',
  'canManageMatches', 'canManageTournaments', 'canManageGrounds',
  'canModerateCommunity', 'canManageDiscover', 'canManageBroadcast',
  'canSendNotifications', 'canManageAds', 'canManageCms', 'canViewReports',
  'canViewAnalytics', 'canViewLogs', 'canManageSettings', 'canAccessGlobalData',
  'canViewSystemHealth', 'canManageSupport', 'canManageAiOps', 'canManageSecurity',
];
function perms(on) {
  const m = {};
  for (const k of ALL) m[k] = on.includes(k);
  return m;
}
const ROLES = {
  superAdmin: { allowedPanel: 'superAdmin', permissions: perms(ALL) },
  moderator: {
    allowedPanel: 'superAdmin',
    permissions: perms(['canViewDashboard', 'canViewProfile', 'canManageAccount',
      'canModerateCommunity', 'canViewReports']),
  },
  tournamentAdmin: {
    allowedPanel: 'superAdmin',
    permissions: perms(['canViewDashboard', 'canViewProfile', 'canManageAccount',
      'canManageMatches', 'canManageTeams', 'canManagePlayers',
      'canManageTournaments', 'canManageGrounds', 'canViewReports']),
  },
  // Built-in fallback: support doc without the newer keys.
  support: {
    allowedPanel: 'superAdmin',
    permissions: { canViewDashboard: true, canViewProfile: true, canViewLogs: true },
  },
  viewer: { allowedPanel: 'superAdmin', permissions: perms(['canViewProfile']) },
  admin: { allowedPanel: 'none', permissions: perms(ALL.filter((p) => p !== 'canManageOrganizations')) },
};

function adminUser(roleId, extra = {}) {
  return { roleId, isActive: true, accessStatus: 'active', email: `${roleId}@x.test`, ...extra };
}
const ADMINS = {
  sa: adminUser('superAdmin'),
  mod: adminUser('moderator'),
  modSusp: adminUser('moderator', { isActive: false, accessStatus: 'suspended' }),
  modRevokedFlag: adminUser('moderator', { accessStatus: 'revoked' }),
  modNoCommunity: adminUser('moderator', { permissionOverrides: { canModerateCommunity: false } }),
  ta: adminUser('tournamentAdmin'),
  sup: adminUser('support'),
  viewer: adminUser('viewer'),
  viewerUsers: adminUser('viewer', { permissionOverrides: { canManageUsers: true } }),
  viewerOrgs: adminUser('viewer', { permissionOverrides: { canManageOrganizations: true } }),
  legacyOrg: adminUser('admin', { organizationId: 'org1' }),
};

const SERIES = {
  name: 'Series One', kind: 'series', status: 'active', description: 'd',
  superAdminUserId: 'owner', createdBy: 'owner', createdAt: NOW, updatedAt: NOW,
};

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
  env = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'demo-crickflow-rules',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host, port: Number(port),
    },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const w = (p, d) => setDoc(doc(db, p), d);
    for (const [id, r] of Object.entries(ROLES)) await w(`admin_roles/${id}`, r);
    for (const [uid, a] of Object.entries(ADMINS)) await w(`admin_users/${uid}`, a);
    await w('users/u1', { uid: 'u1', name: 'User One', displayName: 'User One' });
    await w('users/u2', { uid: 'u2', name: 'User Two', organizationId: 'org1' });
    await w('organizations/org1', { name: 'Legacy org' });
    await w('community_posts/p1', { authorId: 'u1', content: 'hi', createdAt: NOW });
    await w('community_post_reports/r1', { reporterUserId: 'u1', postId: 'p1', status: 'pending' });
    await w('opportunity_posts/o1', { authorId: 'u1', title: 'Coach', status: 'active' });
    await w('teams/t1', { name: 'Team', createdBy: 'u1' });
    await w('players/pl1', { name: 'Player', createdBy: 'u1' });
    await w('matches/m1', { title: 'Match', createdBy: 'u1', status: 'live' });
    await w('tournaments/tr1', { name: 'Cup', createdBy: 'u1' });
    await w('grounds/g1', { name: 'Ground', createdBy: 'sa', createdAt: NOW });
    await w('notifications/n1', { userId: 'u1', title: 't' });
    await w('admin_support_tickets/st1', { subject: 's' });
    await w('admin_ad_campaigns/ad1', { name: 'ad' });
    await w('admin_security_alerts/sec1', { title: 'x' });
    await w('admin_audit_logs/al1', { action: 'x' });
    await w('admin_platform_settings/global', { maintenance: false });
    await w('series/s1', SERIES);
    await w('series/s2', { ...SERIES, name: 'Held Org', status: 'suspended', platformHold: true });
    await w('series_admins/s1_sadmin', { seriesId: 's1', userId: 'sadmin', status: 'active' });
    await w('series/s1/approvals/a1', { seriesId: 's1', requestedBy: 'u1', status: 'pending' });
    await w('series_approvals/a1', { seriesId: 's1', requestedBy: 'u1', status: 'pending' });
    await w('series_clubs/c1', { seriesId: 's1', name: 'Club One', status: 'approved', createdBy: 'u1' });
    await w('series_audit_logs/l1', { seriesId: 's1', action: 'X' });
    await w('series_registrations/reg1', { seriesId: 's1', userId: 'u1', status: 'pending' });
    await w('series_competitions/sc1', { seriesId: 's1', name: 'Comp' });
    await w('series_club_rankings/r1', { seriesId: 's1', clubId: 'c1' });
    await w('series_player_rankings/r1', { seriesId: 's1', playerId: 'pl1' });
    await w('app_meta/config', { minVersion: '1' });
  });
});

after(async () => { await env?.cleanup(); });

const anon = () => env.unauthenticatedContext().firestore();
const as = (uid) => env.authenticatedContext(uid).firestore();
let modSeq = 0;
// Fresh values each call so the diff is never empty.
const modFields = () => ({ adminStatus: 'hidden', adminModerationNote: `n${++modSeq}`, updatedAt: NOW });

// ---------- Public / crickflow-web reads ----------
test('public: web reads stay open', async () => {
  const db = anon();
  await assertSucceeds(getDoc(doc(db, 'series/s1')));
  await assertSucceeds(getDocs(query(collection(db, 'series'), where('status', '==', 'active'))));
  await assertSucceeds(getDocs(query(collection(db, 'series_clubs'), where('seriesId', '==', 's1'))));
  await assertSucceeds(getDocs(query(collection(db, 'series_admins'), where('seriesId', '==', 's1'))));
  await assertSucceeds(getDocs(query(collection(db, 'series_competitions'), where('seriesId', '==', 's1'))));
  await assertSucceeds(getDocs(query(collection(db, 'series_club_rankings'), where('seriesId', '==', 's1'))));
  await assertSucceeds(getDocs(query(collection(db, 'series_player_rankings'), where('seriesId', '==', 's1'))));
  await assertSucceeds(getDoc(doc(db, 'matches/m1')));
  await assertSucceeds(getDoc(doc(db, 'tournaments/tr1')));
  await assertSucceeds(getDoc(doc(db, 'teams/t1')));
  await assertSucceeds(getDoc(doc(db, 'players/pl1')));
});

test('public: admin data is closed', async () => {
  const db = anon();
  await assertFails(getDoc(doc(db, 'admin_users/sa')));
  await assertFails(getDoc(doc(db, 'organizations/org1')));
  await assertFails(getDoc(doc(db, 'admin_audit_logs/al1')));
  await assertFails(updateDoc(doc(db, 'series/s1'), { status: 'suspended', updatedAt: NOW }));
});

// ---------- Regular signed-in user ----------
test('user: own data, no admin data', async () => {
  const db = as('u1');
  await assertSucceeds(getDoc(doc(db, 'admin_users/u1'))); // missing doc, own path
  await assertFails(getDoc(doc(db, 'admin_users/sa')));
  await assertFails(setDoc(doc(db, 'admin_users/u1'), adminUser('superAdmin')));
  await assertFails(getDoc(doc(db, 'organizations/org1')));
  await assertFails(getDoc(doc(db, 'admin_audit_logs/al1')));
  await assertFails(getDoc(doc(db, 'admin_support_tickets/st1')));
  await assertFails(updateDoc(doc(db, 'users/u2'), { accountStatus: 'banned' }));
  await assertFails(updateDoc(doc(as('u2'), 'community_posts/p1'), modFields()));
  await assertSucceeds(getDoc(doc(db, 'notifications/n1')));
  await assertSucceeds(getDoc(doc(db, 'series/s1/approvals/a1')));
  await assertSucceeds(getDoc(doc(db, 'series_registrations/reg1')));
  await assertFails(updateDoc(doc(db, 'series/s1'), { status: 'archived', updatedAt: NOW }));
  await assertFails(getDoc(doc(db, 'series_audit_logs/l1')));
});

test('user: series draft create (mobile createSeriesDraft)', async () => {
  const db = as('u1');
  await assertSucceeds(setDoc(doc(db, 'series/draft1'), {
    name: 'New Org', kind: 'club', status: 'draft', createdBy: 'u1', createdAt: NOW,
  }));
  await assertFails(setDoc(doc(db, 'series/draft2'), {
    name: 'New Org', kind: 'club', status: 'draft', createdBy: 'u1', superAdminUserId: 'other',
  }));
});

// ---------- Series owner / admins (mobile + web) ----------
test('owner: profile edits ok; status, platformHold and ownership locked', async () => {
  const db = as('owner');
  await assertSucceeds(updateDoc(doc(db, 'series/s1'), { logoUrl: 'https://x/l.png', coverImageUrl: 'https://x/c.png', updatedAt: NOW }));
  await assertSucceeds(updateDoc(doc(db, 'series/s1'), { rulesText: 'Play fair', updatedAt: NOW }));
  await assertFails(updateDoc(doc(db, 'series/s1'), { status: 'archived', updatedAt: NOW }));
  await assertFails(updateDoc(doc(db, 'series/s1'), { platformHold: true }));
  await assertFails(updateDoc(doc(db, 'series/s1'), { superAdminUserId: 'u1' }));
  await assertSucceeds(getDoc(doc(db, 'series/s1/approvals/a1')));
  await assertSucceeds(getDocs(collection(db, 'series/s1/approvals')));
  await assertSucceeds(getDoc(doc(db, 'series_audit_logs/l1')));
  await assertSucceeds(getDoc(doc(db, 'series_registrations/reg1')));
});

test('owner: cannot lift a platform suspension', async () => {
  await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'series/s2'), { superAdminUserId: 'owner2', createdBy: 'owner2' }));
  const db = as('owner2');
  await assertFails(updateDoc(doc(db, 'series/s2'), { status: 'active', updatedAt: NOW }));
  await assertFails(updateDoc(doc(db, 'series/s2'), { status: 'active', platformHold: false, updatedAt: NOW }));
  await assertSucceeds(updateDoc(doc(db, 'series/s2'), { description: 'still editable', updatedAt: NOW }));
});

test('series admin member: approvals + registrations readable', async () => {
  const db = as('sadmin');
  await assertSucceeds(getDocs(collection(db, 'series/s1/approvals')));
  await assertSucceeds(getDoc(doc(db, 'series_registrations/reg1')));
  await assertSucceeds(getDoc(doc(db, 'series_audit_logs/l1')));
  await assertFails(updateDoc(doc(db, 'series/s1'), { description: 'x', updatedAt: NOW }));
});

// ---------- Super admin ----------
test('super admin: full access', async () => {
  const db = as('sa');
  await assertSucceeds(getDoc(doc(db, 'organizations/org1')));
  await assertSucceeds(setDoc(doc(db, 'organizations/org2'), { name: 'x' }));
  await assertSucceeds(getDoc(doc(db, 'admin_users/mod')));
  await assertSucceeds(getDocs(collection(db, 'admin_users')));
  await assertSucceeds(updateDoc(doc(db, 'admin_users/mod'), { isActive: true, updatedAt: NOW }));
  await assertSucceeds(getDoc(doc(db, 'admin_audit_logs/al1')));
  await assertSucceeds(updateDoc(doc(db, 'community_posts/p1'), modFields()));
  await assertSucceeds(updateDoc(doc(db, 'users/u1'), { accountStatus: 'active' }));
  await assertSucceeds(getDoc(doc(db, 'admin_support_tickets/st1')));
  await assertSucceeds(getDoc(doc(db, 'admin_security_alerts/sec1')));
  await assertSucceeds(getDoc(doc(db, 'series/s1/approvals/a1')));
  await assertSucceeds(getDoc(doc(db, 'series_audit_logs/l1')));
  await assertSucceeds(getDoc(doc(db, 'admin_platform_settings/global')));
});

test('super admin: org moderation batch (Orgs & Series screen)', async () => {
  const db = as('sa');
  const b = writeBatch(db);
  b.update(doc(db, 'series/s1'), { status: 'suspended', platformHold: true, updatedAt: NOW });
  b.set(doc(db, 'series_audit_logs/mod1'), { seriesId: 's1', action: 'ENTITY_SUSPENDED', actorUserId: 'sa', timestamp: NOW });
  b.set(doc(db, 'admin_audit_logs/mod1'), { action: 'org.entity_suspended', actorUid: 'sa', actorEmail: 'sa@x.test', targetUid: 's1', timestamp: NOW });
  await assertSucceeds(b.commit());
  await assertFails(updateDoc(doc(db, 'series/s1'), { status: 'active', name: 'Renamed' }));
  await assertSucceeds(updateDoc(doc(db, 'series/s1'), { status: 'active', platformHold: false, updatedAt: NOW }));
  await assertSucceeds(updateDoc(doc(db, 'series_clubs/c1'), { status: 'suspended', updatedAt: NOW }));
  await assertSucceeds(updateDoc(doc(db, 'series_clubs/c1'), { status: 'approved', updatedAt: NOW }));
  await assertFails(updateDoc(doc(db, 'series_clubs/c1'), { status: 'approved', name: 'x' }));
});

// ---------- Staff roles ----------
test('moderator: community moderation only', async () => {
  const db = as('mod');
  await assertSucceeds(updateDoc(doc(db, 'community_posts/p1'), modFields()));
  await assertSucceeds(getDoc(doc(db, 'community_post_reports/r1')));
  await assertSucceeds(updateDoc(doc(db, 'community_post_reports/r1'), { status: 'resolved' }));
  await assertSucceeds(updateDoc(doc(db, 'opportunity_posts/o1'), { isPinned: true, updatedAt: NOW }));
  await assertFails(updateDoc(doc(db, 'teams/t1'), { adminFeatured: true }));
  await assertFails(updateDoc(doc(db, 'users/u1'), { accountStatus: 'banned' }));
  await assertFails(getDoc(doc(db, 'admin_users/sa')));
  await assertSucceeds(getDoc(doc(db, 'admin_users/mod')));
  await assertFails(getDoc(doc(db, 'admin_audit_logs/al1')));
  await assertFails(getDoc(doc(db, 'admin_support_tickets/st1')));
  await assertFails(updateDoc(doc(db, 'series/s1'), { status: 'suspended', platformHold: true, updatedAt: NOW }));
  await assertFails(getDoc(doc(db, 'organizations/org1')));
  await assertSucceeds(getDoc(doc(db, 'admin_roles/moderator')));
  await assertSucceeds(addDoc(collection(db, 'admin_audit_logs'), { action: 'community.hide', actorUid: 'mod', actorEmail: 'm@x.test', targetUid: 'p1', timestamp: NOW }));
});

test('moderator: delete a community post', async () => {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'community_posts/p2'), { authorId: 'u1', content: 'x' }));
  await assertFails(deleteDoc(doc(as('ta'), 'community_posts/p2')));
  await assertSucceeds(deleteDoc(doc(as('mod'), 'community_posts/p2')));
});

test('suspended / revoked / overridden staff are denied', async () => {
  await assertFails(updateDoc(doc(as('modSusp'), 'community_posts/p1'), modFields()));
  await assertFails(updateDoc(doc(as('modRevokedFlag'), 'community_posts/p1'), modFields()));
  await assertFails(updateDoc(doc(as('modNoCommunity'), 'community_posts/p1'), modFields()));
  await assertSucceeds(getDoc(doc(as('modSusp'), 'admin_users/modSusp')));
});

test('tournamentAdmin: cricket data', async () => {
  const db = as('ta');
  await assertSucceeds(updateDoc(doc(db, 'teams/t1'), { adminFeatured: true }));
  await assertSucceeds(updateDoc(doc(db, 'players/pl1'), { adminVerified: true }));
  await assertSucceeds(updateDoc(doc(db, 'matches/m1'), { adminFeatured: true }));
  await assertSucceeds(updateDoc(doc(db, 'tournaments/tr1'), { adminFeatured: true }));
  await assertSucceeds(getDoc(doc(db, 'grounds/g1')));
  await assertSucceeds(setDoc(doc(db, 'grounds/g2'), { name: 'New', createdBy: 'ta', createdAt: NOW }));
  await assertFails(updateDoc(doc(db, 'community_posts/p1'), modFields()));
  await assertFails(updateDoc(doc(db, 'users/u1'), { accountStatus: 'banned' }));
});

test('support: tickets + logs via built-in defaults', async () => {
  const db = as('sup');
  await assertSucceeds(getDoc(doc(db, 'admin_support_tickets/st1')));
  await assertSucceeds(setDoc(doc(db, 'admin_support_tickets/st2'), { subject: 'new' }));
  await assertSucceeds(getDoc(doc(db, 'admin_audit_logs/al1')));
  await assertSucceeds(getDoc(doc(db, 'notifications/n1')));
  await assertFails(updateDoc(doc(db, 'community_posts/p1'), modFields()));
  await assertFails(getDoc(doc(db, 'admin_ad_campaigns/ad1')));
  await assertFails(getDoc(doc(db, 'admin_security_alerts/sec1')));
});

test('viewer: profile only; overrides grant exact permissions', async () => {
  const v = as('viewer');
  await assertSucceeds(getDoc(doc(v, 'admin_users/viewer')));
  await assertFails(getDoc(doc(v, 'admin_users/sa')));
  await assertFails(updateDoc(doc(v, 'teams/t1'), { adminVerified: true }));
  await assertFails(getDoc(doc(v, 'admin_support_tickets/st1')));
  await assertFails(getDoc(doc(v, 'series_audit_logs/l1')));
  await assertSucceeds(getDoc(doc(v, 'admin_platform_settings/global')));
  const vu = as('viewerUsers');
  await assertSucceeds(getDoc(doc(vu, 'admin_users/sa')));
  await assertSucceeds(updateDoc(doc(vu, 'users/u1'), { accountStatus: 'active' }));
  await assertFails(updateDoc(doc(vu, 'admin_users/viewer'), { roleId: 'superAdmin' }));
  const vo = as('viewerOrgs');
  await assertSucceeds(getDoc(doc(vo, 'series_audit_logs/l1')));
  await assertSucceeds(updateDoc(doc(vo, 'series_clubs/c1'), { status: 'suspended', updatedAt: NOW }));
  await assertFails(getDoc(doc(vo, 'organizations/org1')));
});

test('legacy org admin (retired role) gets nothing', async () => {
  const db = as('legacyOrg');
  await assertSucceeds(addDoc(collection(db, 'admin_audit_logs'), audit('legacyOrg'))); // still an active admin record pre-revocation
  await assertFails(addDoc(collection(as('modSusp'), 'admin_audit_logs'), audit('modSusp')));
  await assertFails(updateDoc(doc(db, 'users/u2'), { accountStatus: 'banned' }));
  await assertFails(getDoc(doc(db, 'organizations/org1')));
  await assertFails(updateDoc(doc(db, 'community_posts/p1'), modFields()));
  await assertFails(updateDoc(doc(db, 'teams/t1'), { adminVerified: true }));
  await assertFails(getDoc(doc(db, 'admin_users/sa')));
  await assertFails(getDoc(doc(db, 'grounds/g1')));
});

test('series flows used by mobile + web: queries, club create/logo, approvals', async () => {
  const owner = as('owner');
  await assertSucceeds(getDocs(query(collection(owner, 'series/s1/approvals'), where('status', '==', 'pending'))));
  await assertSucceeds(getDocs(query(collection(owner, 'series_approvals'), where('seriesId', '==', 's1'), where('status', '==', 'pending'))));
  await assertSucceeds(getDocs(query(collection(owner, 'series_admins'), where('seriesId', '==', 's1'), where('userId', '==', 'sadmin'))));
  const u1 = as('u1');
  await assertSucceeds(setDoc(doc(u1, 'series_clubs/c2'), { seriesId: 's1', name: 'Club Two', createdBy: 'u1', status: 'pending' }));
  await assertSucceeds(updateDoc(doc(u1, 'series_clubs/c2'), { logoUrl: 'https://x/c.png', updatedAt: NOW }));
  await assertFails(updateDoc(doc(u1, 'series_clubs/c2'), { status: 'approved' }));
  await assertFails(updateDoc(doc(as('sa'), 'series_clubs/c2'), { status: 'approved', updatedAt: NOW })); // pending → approval flow only
  await assertSucceeds(setDoc(doc(u1, 'series_approvals/new1'), { seriesId: 's1', requestedBy: 'u1', status: 'pending', targetType: 'club', targetId: 'c2' }));
  await assertFails(getDocs(query(collection(as('u2'), 'series_approvals'), where('seriesId', '==', 's1'))));
});
