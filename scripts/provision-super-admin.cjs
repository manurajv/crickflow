/**
 * One-shot: seed admin_roles + create Super Admin for a given UID
 * using the Firebase CLI refresh token (same login as `firebase` CLI).
 */
const fs = require('fs');
const path = require('path');
const https = require('https');

const PROJECT = 'crickflow-b06bc';
const UID = process.argv[2] || 'ghMkd0xdUEP96kPvsScbPNUfzu13';
const EMAIL = process.argv[3] || 'manurajv@gmail.com';
const NAME = process.argv[4] || 'Manuraj Vimukthi';

// Public Firebase CLI OAuth client (used by firebase-tools)
const CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'jEQ6QTSQwu0e2RZ95U3u1mAz';

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

function request(method, url, headers, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = https.request(
      {
        method,
        hostname: u.hostname,
        path: u.pathname + u.search,
        headers,
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          let parsed = data;
          try {
            parsed = JSON.parse(data);
          } catch (_) {}
          if (res.statusCode >= 400) {
            reject(
              new Error(
                `${method} ${url} → ${res.statusCode}: ${typeof parsed === 'string' ? parsed : JSON.stringify(parsed)}`,
              ),
            );
          } else {
            resolve(parsed);
          }
        });
      },
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

function toFirestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') return { integerValue: String(value) };
  if (typeof value === 'string') return { stringValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (typeof value === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(value)) {
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(value) };
}

function toDoc(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) fields[k] = toFirestoreValue(v);
  return { fields };
}

async function getAccessToken() {
  const cfgPath = path.join(
    process.env.USERPROFILE || process.env.HOME,
    '.config',
    'configstore',
    'firebase-tools.json',
  );
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const refreshToken = cfg.tokens?.refresh_token;
  if (!refreshToken) throw new Error('No Firebase CLI refresh token found. Run: firebase login');

  const body = new URLSearchParams({
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  }).toString();

  const token = await request(
    'POST',
    'https://oauth2.googleapis.com/token',
    {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(body),
    },
    body,
  );
  if (!token.access_token) throw new Error('Failed to refresh access token');
  return token.access_token;
}

async function upsertDoc(accessToken, collection, docId, data) {
  const base = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
  const url = `${base}/${collection}/${docId}`;
  const body = JSON.stringify(toDoc(data));
  await request(
    'PATCH',
    url,
    {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
    },
    body,
  );
  console.log(`  ✓ ${collection}/${docId}`);
}

async function main() {
  console.log(`Project: ${PROJECT}`);
  console.log(`Super Admin UID: ${UID} (${EMAIL})`);
  const accessToken = await getAccessToken();

  console.log('\nSeeding admin_roles…');
  for (const [id, doc] of Object.entries(ROLES)) {
    await upsertDoc(accessToken, 'admin_roles', id, doc);
  }

  console.log('\nCreating admin_users…');
  await upsertDoc(accessToken, 'admin_users', UID, {
    email: EMAIL,
    displayName: NAME,
    photoUrl:
      'https://lh3.googleusercontent.com/a/ACg8ocIf0erVI8J7QRuabY4AvBc9ByYtHFvgh0jlK22tlE-RRQKNCMML=s96-c',
    roleId: 'superAdmin',
    organizationId: null,
    organizationName: null,
    permissionOverrides: {},
    isActive: true,
    claimsVersion: 0,
    updatedAt: new Date().toISOString(),
  });

  console.log('\nDone. Sign in to Super Admin with Google (manurajv@gmail.com).');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
