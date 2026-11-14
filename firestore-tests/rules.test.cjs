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
  getDocs, writeBatch, addDoc, arrayUnion, arrayRemove,
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
    await w('series/s1/announcements/an1', { seriesId: 's1', title: 'Fixtures out', body: 'b', createdBy: 'owner', createdAt: NOW });
    await w('series_admins/s1_sadmin', { seriesId: 's1', userId: 'sadmin', status: 'active' });
    await w('series/s1/approvals/a1', { seriesId: 's1', requestedBy: 'u1', status: 'pending' });
    await w('series_approvals/a1', { seriesId: 's1', requestedBy: 'u1', status: 'pending' });
    await w('series_clubs/c1', { seriesId: 's1', name: 'Club One', status: 'approved', createdBy: 'u1' });
    await w('series_audit_logs/l1', { seriesId: 's1', action: 'X' });
    await w('series_registrations/reg1', { seriesId: 's1', userId: 'u1', status: 'pending' });
    await w('series_competitions/sc1', { seriesId: 's1', name: 'Comp' });
    await w('series_club_rankings/r1', { seriesId: 's1', clubId: 'c1' });
    await w('series_player_rankings/r1', { seriesId: 's1', playerId: 'pl1' });
    await w('series_match_digests/m1', { seriesId: 's1', matchId: 'm1', players: {} });
    await w('matches/m_org', { seriesId: 's1', seriesOfficialStatus: 'approved', status: 'completed' });
    await w('app_meta/config', { minVersion: '1' });
  });
});

after(async () => { await env?.cleanup(); });

const anon = () => env.unauthenticatedContext().firestore();
const as = (uid) => env.authenticatedContext(uid).firestore();
let modSeq = 0;
// Fresh values each call so the diff is never empty.
const modFields = () => ({ adminStatus: 'hidden', adminModerationNote: `n${++modSeq}`, updatedAt: NOW });

test('series_match_digests are server-written only', async () => {
  for (const db of [anon(), as('u1'), as('owner')]) {
    await assertFails(setDoc(doc(db, 'series_match_digests/m_new'), { seriesId: 's1', players: {} }));
    await assertFails(updateDoc(doc(db, 'series_match_digests/m1'), { players: { x: 1 } }));
    await assertFails(deleteDoc(doc(db, 'series_match_digests/m1')));
  }
});

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
  // Org leaderboard on web: digests plus the org's matches, no sign-in needed.
  await assertSucceeds(getDocs(query(collection(db, 'series_match_digests'), where('seriesId', '==', 's1'))));
  await assertSucceeds(getDocs(query(collection(db, 'matches'), where('seriesId', '==', 's1'))));
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

test('org permissions: proposeAccess validated, proposals cannot bypass the callables', async () => {
  const owner = as('owner');
  await assertSucceeds(updateDoc(doc(owner, 'series/s1'), {
    competitionPolicy: { proposeAccess: 'everyone', membersCanRequest: true, matchRequestsNeedApproval: true },
    updatedAt: NOW,
  }));
  await assertSucceeds(updateDoc(doc(owner, 'series/s1'), { competitionPolicy: { proposeAccess: 'admins' }, updatedAt: NOW }));
  await assertSucceeds(updateDoc(doc(owner, 'series/s1'), { competitionPolicy: { membersCanRequest: false }, updatedAt: NOW }));
  await assertSucceeds(updateDoc(doc(owner, 'series/s1'), {
    competitionPolicy: {
      matchProposeAccess: 'everyone', tournamentProposeAccess: 'admins',
      matchTeamAdminsNeedApproval: false, matchPlayersNeedApproval: true,
      tournamentTeamAdminsNeedApproval: true, tournamentPlayersNeedApproval: true,
      allowWalkIns: false,
    },
    updatedAt: NOW,
  }));
  await assertFails(updateDoc(doc(owner, 'series/s1'), { competitionPolicy: { matchProposeAccess: 'nobody' }, updatedAt: NOW }));
  await assertFails(updateDoc(doc(owner, 'series/s1'), { competitionPolicy: { tournamentProposeAccess: true }, updatedAt: NOW }));
  await assertFails(updateDoc(doc(owner, 'series/s1'), { competitionPolicy: { allowWalkIns: 'no' }, updatedAt: NOW }));
  await assertFails(updateDoc(doc(owner, 'series/s1'), { competitionPolicy: { matchPlayersNeedApproval: 1 }, updatedAt: NOW }));
  await assertFails(updateDoc(doc(as('u1'), 'series/s1'), { competitionPolicy: { allowWalkIns: true }, updatedAt: NOW }));
  await assertFails(updateDoc(doc(owner, 'series/s1'), { competitionPolicy: { proposeAccess: 'nobody' }, updatedAt: NOW }));
  await assertFails(updateDoc(doc(owner, 'series/s1'), { competitionPolicy: { proposeAccess: true }, updatedAt: NOW }));
  await assertFails(updateDoc(doc(owner, 'series/s1'), { competitionPolicy: 'open', updatedAt: NOW }));
  await assertFails(updateDoc(doc(as('u1'), 'series/s1'), { competitionPolicy: { proposeAccess: 'everyone' }, updatedAt: NOW }));
  await assertFails(updateDoc(doc(as('sadmin'), 'series/s1'), { competitionPolicy: { proposeAccess: 'everyone' }, updatedAt: NOW }));

  const draft = (uid) => ({ seriesId: 's1', createdBy: uid, status: 'pendingApproval', type: 'singleMatch' });
  // A team admin / player cannot write a proposal row themselves.
  await assertFails(setDoc(doc(as('u1'), 'series_competitions/x1'), draft('u1')));
  await assertFails(setDoc(doc(as('u2'), 'series_competitions/x2'), draft('u2')));
  // Owner and org admins still can.
  await assertSucceeds(setDoc(doc(as('owner'), 'series_competitions/x3'), draft('owner')));
  await assertSucceeds(setDoc(doc(as('sadmin'), 'series_competitions/x4'), draft('sadmin')));
  // Approved rows can never be written by clients.
  await assertFails(setDoc(doc(as('owner'), 'series_competitions/x5'), { ...draft('owner'), status: 'approved' }));
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

test('announcements: signed-in read, callable-only writes', async () => {
  await assertSucceeds(getDocs(collection(as('u2'), 'series/s1/announcements')));
  await assertFails(getDocs(collection(anon(), 'series/s1/announcements')));
  await assertFails(setDoc(doc(as('owner'), 'series/s1/announcements/x'), { title: 'x' }));
});

test('org-locked teams: details/roster only via functions; stats still writable', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'teams/locked1'), {
      name: 'Lock', createdBy: 'towner', playerIds: ['towner'],
      orgLock: { seriesId: 's1', clubId: 'c1' },
    });
    await setDoc(doc(db, 'teams/free1'), { name: 'Free', createdBy: 'towner', playerIds: ['towner'] });
    await setDoc(doc(db, 'players/lp1'), {
      name: 'P', userId: 'lp1', teamIds: ['locked1'], teamId: 'locked1', rosterChangeTeamId: 'locked1',
    });
    await setDoc(doc(db, 'players/walk1'), { name: 'W' });
  });
  const o = as('towner');
  const p = as('lp1');
  await assertFails(updateDoc(doc(o, 'teams/locked1'), { name: 'X' }));
  await assertFails(updateDoc(doc(o, 'teams/locked1'), { playerIds: ['towner', 'x'] }));
  await assertFails(updateDoc(doc(o, 'teams/locked1'), { orgLock: null }));
  await assertSucceeds(updateDoc(doc(o, 'teams/locked1'), { stats: { matchesPlayed: 1 }, updatedAt: NOW }));
  await assertFails(deleteDoc(doc(o, 'teams/locked1')));
  await assertSucceeds(updateDoc(doc(o, 'teams/free1'), { name: 'Y' }));
  await assertFails(updateDoc(doc(o, 'teams/free1'), { orgLock: { clubId: 'z' } }));
  await assertFails(setDoc(doc(o, 'teams/new1'), { name: 'n', createdBy: 'towner', orgLock: {} }));
  await assertSucceeds(updateDoc(doc(p, 'players/lp1'), { name: 'P2' }));
  await assertFails(updateDoc(doc(p, 'players/lp1'), { teamIds: [], rosterChangeTeamId: 'locked1' }));
  await assertFails(setDoc(doc(o, 'players/walk2'), { name: 'W', teamIds: ['locked1'], teamId: 'locked1' }));
  await assertSucceeds(setDoc(doc(o, 'players/walk3'), { name: 'W', teamIds: ['free1'], teamId: 'free1' }));
  await assertFails(updateDoc(doc(o, 'players/walk1'), { teamIds: ['locked1'], teamId: 'locked1', rosterChangeTeamId: 'locked1' }));
  await assertFails(setDoc(doc(p, 'teams/locked1/join_requests/lp1'), {
    userId: 'lp1', status: 'pending', playerId: 'lp1', playerName: 'P',
  }));
});

// t43: a user whose player is already on an org-locked team (org admin, super
// admin, anyone) creates a NORMAL team exactly like a normal user.
test('normal team create: org members / org admins / super admins are normal users outside the org', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'teams/orgT'), {
      name: 'Org team', createdBy: 'orgadm', playerIds: ['orgadm'], captainId: 'orgadm',
      orgLock: { seriesId: 's1', clubId: 'c1' },
    });
    for (const uid of ['orgadm', 'sa', 'u1']) {
      await setDoc(doc(db, `players/${uid}`), uid === 'u1'
        ? { name: uid, userId: uid }
        : { name: uid, userId: uid, teamIds: ['orgT'], teamId: 'orgT', rosterChangeTeamId: 'orgT' });
    }
    await setDoc(doc(db, 'series_admins/s1_orgadm'), { seriesId: 's1', userId: 'orgadm', status: 'active' });
  });
  for (const uid of ['orgadm', 'sa', 'u1']) {
    const db = as(uid);
    const teamId = `normal_${uid}`;
    // One atomic batch: team doc + owner on roster + player membership.
    const b = writeBatch(db);
    b.set(doc(db, `teams/${teamId}`), {
      name: `Team ${uid}`, createdBy: uid, playerIds: [uid], memberCount: 1, captainId: uid,
      teamCode: `TM9${uid.length}`, createdAt: NOW, updatedAt: NOW,
    });
    const isNew = uid === 'u1';
    b.set(doc(db, `players/${uid}`), {
      teamIds: arrayUnion(teamId), teamId, rosterChangeTeamId: teamId, updatedAt: NOW,
    }, { merge: true });
    await assertSucceeds(b.commit());
    // Later owner edits (logo, QR, captain) still work.
    await assertSucceeds(updateDoc(doc(db, `teams/${teamId}`), { qrUrl: 'q', logoUrl: 'l', teamProfileImageUrl: 'l', updatedAt: NOW }));
    // The org team membership is untouched and still can't be dropped by the client.
    if (!isNew) {
      const snap = await getDoc(doc(db, `players/${uid}`));
      if (!snap.data().teamIds.includes('orgT')) throw new Error('org team membership lost');
      await assertFails(updateDoc(doc(db, `players/${uid}`), {
        teamIds: [teamId], teamId, rosterChangeTeamId: teamId, updatedAt: NOW,
      }));
      // Only platform staff (special permission) may touch org team details.
      if (uid === 'orgadm') await assertFails(updateDoc(doc(db, 'teams/orgT'), { name: 'renamed' }));
    }
    // Leaving the normal team again is fine.
    await assertSucceeds(updateDoc(doc(db, `players/${uid}`), {
      teamIds: arrayRemove(teamId), rosterChangeTeamId: teamId, updatedAt: NOW,
    }));
  }
  // A normal team owner can add a player who also plays for an org team.
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'teams/normal_u1'), { name: 'U1 team', createdBy: 'u1', playerIds: ['u1'] });
  });
  {
    const db = as('u1');
    const b = writeBatch(db);
    b.update(doc(db, 'players/orgadm'), {
      teamIds: arrayUnion('normal_u1'), teamId: 'normal_u1', rosterChangeTeamId: 'normal_u1', updatedAt: NOW,
    });
    b.update(doc(db, 'teams/normal_u1'), { playerIds: ['u1', 'orgadm'], memberCount: 2, updatedAt: NOW });
    await assertSucceeds(b.commit());
  }
  // Still blocked: joining an org team from the client, even with a normal team as cover.
  await assertFails(updateDoc(doc(as('u1'), 'players/u1'), {
    teamIds: arrayUnion('orgT', 'normal_u1'), rosterChangeTeamId: 'normal_u1', updatedAt: NOW,
  }));
  await assertFails(setDoc(doc(as('u1'), 'players/walkX'), { name: 'W', teamIds: ['free1', 'orgT'] }));
});

// Series staff role tiers: scorer/viewer can read staff tools, only full admins write competitions.
test('series admin role tiers: scorer and viewer reads vs full-admin writes', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'series_admins/s1_scorer1'), {
      seriesId: 's1', userId: 'scorer1', status: 'active', role: 'scorer',
    });
    await setDoc(doc(db, 'series_admins/s1_viewer1'), {
      seriesId: 's1', userId: 'viewer1', status: 'active', role: 'viewer',
    });
    await setDoc(doc(db, 'series_admins/s1_fulladm'), {
      seriesId: 's1', userId: 'fulladm', status: 'active', role: 'admin',
    });
    await setDoc(doc(db, 'series_registrations/reg1/private/identity'), {
      nationalId: 'secret',
    });
  });
  const scorer = as('scorer1');
  const viewer = as('viewer1');
  const full = as('fulladm');
  const outsider = as('u2');

  await assertSucceeds(getDoc(doc(scorer, 'series/s1/approvals/a1')));
  await assertSucceeds(getDoc(doc(viewer, 'series/s1/approvals/a1')));
  await assertSucceeds(getDoc(doc(scorer, 'series_audit_logs/l1')));
  await assertSucceeds(getDoc(doc(viewer, 'series_registrations/reg1')));
  await assertFails(getDoc(doc(outsider, 'series/s1/approvals/a1')));

  // PII stays full-admin / owner only.
  await assertFails(getDoc(doc(scorer, 'series_registrations/reg1/private/identity')));
  await assertSucceeds(getDoc(doc(full, 'series_registrations/reg1/private/identity')));

  const draft = {
    seriesId: 's1', createdBy: 'scorer1', status: 'draft', type: 'match',
  };
  await assertFails(setDoc(doc(scorer, 'series_competitions/scorerDraft'), { ...draft, createdBy: 'scorer1' }));
  await assertFails(setDoc(doc(viewer, 'series_competitions/viewerDraft'), { ...draft, createdBy: 'viewer1' }));
  await assertSucceeds(setDoc(doc(full, 'series_competitions/fullDraft'), {
    seriesId: 's1', createdBy: 'fulladm', status: 'draft', type: 'match',
  }));
  // Legacy series_admins doc without role remains a full admin.
  await assertSucceeds(setDoc(doc(as('sadmin'), 'series_competitions/legacyDraft'), {
    seriesId: 's1', createdBy: 'sadmin', status: 'draft', type: 'match',
  }));
});


// Player registration documents: identity readable by the player, submitting
// team admin, and full org admins — not staff viewers or outsiders.
test('series registration identity is limited to player, team admins, and org admins', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'series_club_admins/s1_c1_cadm'), {
      seriesId: 's1', clubId: 'c1', userId: 'cadm', status: 'active',
    });
    await setDoc(doc(db, 'series_club_admins/s1_otherClub_othercadm'), {
      seriesId: 's1', clubId: 'otherClub', userId: 'othercadm', status: 'active',
    });
    await setDoc(doc(db, 'series_registrations/regDocs'), {
      seriesId: 's1', clubId: 'c1', userId: 'player1', createdBy: 'cadm', status: 'pending',
    });
    await setDoc(doc(db, 'series_registrations/regDocs/private/identity'), {
      nationalId: 'NIC-99', nationalIdDocUrl: 'https://example/doc.jpg',
    });
  });

  await assertSucceeds(getDoc(doc(as('player1'), 'series_registrations/regDocs/private/identity')));
  await assertSucceeds(getDoc(doc(as('cadm'), 'series_registrations/regDocs/private/identity')));
  await assertSucceeds(getDoc(doc(as('owner'), 'series_registrations/regDocs/private/identity')));
  await assertSucceeds(getDoc(doc(as('fulladm'), 'series_registrations/regDocs/private/identity')));
  await assertFails(getDoc(doc(as('othercadm'), 'series_registrations/regDocs/private/identity')));
  await assertFails(getDoc(doc(as('scorer1'), 'series_registrations/regDocs/private/identity')));
  await assertFails(getDoc(doc(as('viewer1'), 'series_registrations/regDocs/private/identity')));
  await assertFails(getDoc(doc(as('u2'), 'series_registrations/regDocs/private/identity')));
  await assertSucceeds(getDoc(doc(as('cadm'), 'series_registrations/regDocs')));
  await assertSucceeds(getDoc(doc(as('player1'), 'series_registrations/regDocs')));
});
