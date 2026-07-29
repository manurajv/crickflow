/**
 * Seeds additive admin_roles (+ optional super admin user).
 * Does NOT touch mobile users collection.
 *
 * Usage:
 *   node scripts/seed-admin-roles.mjs
 *   node scripts/seed-admin-roles.mjs --email you@example.com --password 'YourSecurePass!' --name "Platform Owner"
 *
 * Requires Application Default Credentials, e.g.:
 *   gcloud auth application-default login --project crickflow-b06bc
 */
const path = require('path');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

const PROJECT_ID = 'crickflow-b06bc';

const ALL_PERMS = [
  'canManageUsers',
  'canManageMatches',
  'canManageTeams',
  'canManagePlayers',
  'canManageTournaments',
  'canSendNotifications',
  'canManageAds',
  'canModerateCommunity',
  'canManageBroadcast',
  'canViewAnalytics',
  'canManageCms',
  'canViewReports',
  'canManageSettings',
  'canViewLogs',
  'canManageOrganizations',
  'canAccessGlobalData',
  'canManageDiscover',
  'canViewDashboard',
  'canViewProfile',
  'canManageAccount',
];

function permMap(enabled) {
  const set = new Set(enabled);
  const out = {};
  for (const p of ALL_PERMS) out[p] = set.has(p);
  return out;
}

const ROLES = {
  superAdmin: {
    label: 'Super Admin',
    description: 'Platform owner — full access',
    allowedPanel: 'superAdmin',
    isSystem: true,
    permissions: permMap(ALL_PERMS),
  },
  admin: {
    label: 'Admin',
    description: 'Organization administrator',
    allowedPanel: 'organizationAdmin',
    isSystem: true,
    permissions: permMap([
      'canViewDashboard',
      'canViewProfile',
      'canManageAccount',
      'canManageUsers',
      'canManageMatches',
      'canManageTeams',
      'canManagePlayers',
      'canManageTournaments',
      'canSendNotifications',
      'canModerateCommunity',
      'canManageBroadcast',
      'canViewAnalytics',
      'canViewReports',
      'canManageSettings',
      'canManageDiscover',
    ]),
  },
  moderator: {
    label: 'Moderator',
    description: 'Community moderation (no panel access yet)',
    allowedPanel: 'none',
    isSystem: true,
    permissions: permMap([
      'canViewDashboard',
      'canViewProfile',
      'canManageAccount',
      'canModerateCommunity',
      'canViewReports',
    ]),
  },
  tournamentAdmin: {
    label: 'Tournament Admin',
    description: 'Tournament-scoped admin (no panel access yet)',
    allowedPanel: 'none',
    isSystem: true,
    permissions: permMap([
      'canViewDashboard',
      'canViewProfile',
      'canManageAccount',
      'canManageMatches',
      'canManageTeams',
      'canManagePlayers',
      'canManageTournaments',
      'canViewReports',
    ]),
  },
  support: {
    label: 'Support',
    description: 'Support / read-heavy (no panel access yet)',
    allowedPanel: 'none',
    isSystem: true,
    permissions: permMap([
      'canViewDashboard',
      'canViewProfile',
      'canManageAccount',
      'canViewReports',
      'canViewLogs',
      'canViewAnalytics',
    ]),
  },
  viewer: {
    label: 'Viewer',
    description: 'No administration access',
    allowedPanel: 'none',
    isSystem: true,
    permissions: permMap(['canViewProfile']),
  },
};

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : null;
}

async function main() {
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();

  console.log('Seeding admin_roles…');
  for (const [id, doc] of Object.entries(ROLES)) {
    await db.collection('admin_roles').doc(id).set(doc, { merge: true });
    console.log(`  ✓ admin_roles/${id}`);
  }

  const email = arg('email');
  const password = arg('password');
  const name = arg('name') || 'Platform Owner';

  if (!email) {
    console.log('\nRoles seeded. To create a Super Admin user, re-run with:');
    console.log(
      `  node scripts/seed-admin-roles.mjs --email you@example.com --password 'SecurePass!' --name "Your Name"`,
    );
    return;
  }

  let user;
  try {
    user = await admin.auth().getUserByEmail(email);
    console.log(`\nAuth user already exists: ${user.uid}`);
    if (password) {
      await admin.auth().updateUser(user.uid, { password, displayName: name });
      console.log('  ✓ password / displayName updated');
    }
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    if (!password) {
      throw new Error('User not found — pass --password to create them');
    }
    user = await admin.auth().createUser({
      email,
      password,
      displayName: name,
      emailVerified: true,
    });
    console.log(`\nCreated Auth user: ${user.uid}`);
  }

  await db.collection('admin_users').doc(user.uid).set(
    {
      email,
      displayName: name,
      roleId: 'superAdmin',
      organizationId: null,
      organizationName: null,
      permissionOverrides: {},
      isActive: true,
      claimsVersion: 0,
      updatedAt: new Date().toISOString(),
    },
    { merge: true },
  );
  console.log(`  ✓ admin_users/${user.uid} → roleId=superAdmin`);
  console.log('\nDone. Sign in at the Super Admin panel with that email/password.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
