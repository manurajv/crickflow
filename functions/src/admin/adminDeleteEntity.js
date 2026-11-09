/**
 * Admin panel: permanent, cascading delete of a team / tournament /
 * organization (series) / match (t43).
 *
 * - Callable `adminDeleteEntity({ type, id, reason })`, platform staff only
 *   (Super Admin, or a staff role with the matching permission; mirrors
 *   `hasAdminPermission` in firestore.rules).
 * - Deletes the main doc with all subcollections, the docs that only exist for
 *   it, and its Storage folder, then removes references so nobody can open it.
 * - Notifies the owners / admins (Priority in-app notification; the normal
 *   onNotificationCreated pipeline sends the push).
 *
 * Career stats policy: completed (or started) matches are never deleted as a
 * side effect of deleting a tournament or an organization. They are detached
 * (tournamentId / seriesId removed) and stay in players' history, so career
 * stats that were already counted from them remain correct. Matches that never
 * started are deleted. Deleting ONE completed match directly is allowed, but
 * stats already counted from it are not reversed (the confirm dialog says so).
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

const TYPES = {
  team: { collection: 'teams', permission: 'canManageTeams', label: 'team', storage: 'teams' },
  tournament: {
    collection: 'tournaments', permission: 'canManageTournaments', label: 'tournament', storage: 'tournaments',
  },
  series: {
    collection: 'series', permission: 'canManageOrganizations', label: 'organization', storage: 'series',
  },
  match: { collection: 'matches', permission: 'canManageMatches', label: 'match', storage: 'matches' },
};

/** Mirrors builtinAdminRolePermissions in firestore.rules. */
const BUILTIN_ROLE_PERMISSIONS = {
  moderator: ['canViewDashboard', 'canViewProfile', 'canManageAccount', 'canModerateCommunity', 'canViewReports'],
  tournamentAdmin: [
    'canViewDashboard', 'canViewProfile', 'canManageAccount', 'canManageMatches', 'canManageTeams',
    'canManagePlayers', 'canManageTournaments', 'canManageGrounds', 'canViewReports',
  ],
  support: [
    'canViewDashboard', 'canViewProfile', 'canManageAccount', 'canViewReports', 'canViewLogs',
    'canViewAnalytics', 'canViewSystemHealth', 'canManageSupport',
  ],
  viewer: ['canViewProfile'],
};

/** Pure: same decision as hasAdminPermission() in firestore.rules. */
function adminHasPermission(adminUser, roleDoc, permission) {
  if (!adminUser || adminUser.isActive !== true) return false;
  if ((adminUser.accessStatus || 'active') !== 'active') return false;
  const roleId = typeof adminUser.roleId === 'string' ? adminUser.roleId : '';
  if (roleId === 'superAdmin') return true;
  if (!roleId || roleId === 'admin') return false;
  const overrides = adminUser.permissionOverrides || {};
  if (Object.prototype.hasOwnProperty.call(overrides, permission)) return overrides[permission] === true;
  const rolePerms = (roleDoc && roleDoc.permissions) || {};
  if (Object.prototype.hasOwnProperty.call(rolePerms, permission)) return rolePerms[permission] === true;
  return (BUILTIN_ROLE_PERMISSIONS[roleId] || []).includes(permission);
}

const NOT_STARTED = new Set(['draft', 'scheduled', 'tossCompleted', 'upcoming', 'created', 'pending']);

/** Pure: 'delete' for matches that never started, else 'detach' (keeps career stats valid). */
function matchFateOnParentDelete(match) {
  const status = String(match?.status || 'scheduled');
  return NOT_STARTED.has(status) && match?.statsProcessed !== true ? 'delete' : 'detach';
}

function uniq(ids, exclude) {
  const out = [];
  for (const id of ids) {
    if (typeof id !== 'string' || !id || id === exclude || out.includes(id)) continue;
    out.push(id);
  }
  return out;
}

/** Pure: who is told that a team was removed. */
function teamRecipients(team, leaderUserIds = [], actorUid) {
  return uniq([team?.createdBy, ...leaderUserIds], actorUid);
}

/** Pure: tournament owner / organizer / admins. */
function tournamentRecipients(t, members = [], actorUid) {
  const admins = members
    .filter((m) => ['owner', 'admin', 'organizer'].includes(m.role))
    .map((m) => m.userId);
  return uniq([t?.organizerId, t?.createdBy, ...admins], actorUid);
}

/** Pure: org owner and active org admins. */
function seriesRecipients(s, admins = [], actorUid) {
  const active = admins.filter((a) => (a.status || 'active') === 'active').map((a) => a.userId);
  return uniq([s?.superAdminUserId, s?.ownerUserId, s?.createdBy, ...active], actorUid);
}

/** Pure: in-app notification doc (Priority tab). */
function buildRemovalNotification({ userId, type, id, name, reason, actorUid, ts, extra = {} }) {
  const label = TYPES[type]?.label || type;
  const title = `${label.charAt(0).toUpperCase()}${label.slice(1)} removed`;
  const what = name ? `"${name}"` : `Your ${label}`;
  const why = reason ? ` Reason: ${String(reason).slice(0, 300)}` : '';
  return {
    userId,
    title,
    body: `${what} was removed by CrickFlow and is no longer available.${why}`,
    type: 'admin_content_removed',
    category: 'system',
    priority: true,
    removedEntityType: type,
    removedEntityId: id,
    ...(type === 'team' ? { removedTeamId: id } : {}),
    ...extra,
    addedByUserId: actorUid || 'system',
    createdAt: ts,
    read: false,
    isRead: false,
  };
}

// ---------------------------------------------------------------------------
// I/O helpers (db is a Firestore-like object; FieldValue and storage injected
// so the executor runs against an in-memory fake in unit tests).

async function deleteWhere(ctx, collection, field, value, report) {
  const snap = await ctx.db.collection(collection).where(field, '==', value).get();
  for (const d of snap.docs) {
    await ctx.recursiveDelete(d.ref);
  }
  if (snap.docs.length) report.deleted[collection] = (report.deleted[collection] || 0) + snap.docs.length;
  return snap.docs;
}

async function deleteDocIfExists(ctx, collection, id, report) {
  const ref = ctx.db.collection(collection).doc(id);
  const snap = await ref.get();
  if (!snap.exists) return false;
  await ctx.recursiveDelete(ref);
  report.deleted[collection] = (report.deleted[collection] || 0) + 1;
  return true;
}

async function deleteStorageFolder(ctx, prefix, report) {
  if (!ctx.storage) return;
  try {
    const n = await ctx.storage.deletePrefix(`${prefix}/`);
    if (n) report.storageFilesDeleted = (report.storageFilesDeleted || 0) + n;
  } catch (err) {
    report.warnings.push(`storage ${prefix}: ${err.message}`);
  }
}

async function notifyAll(ctx, recipients, payload, report) {
  for (const userId of recipients) {
    await ctx.db.collection('notifications').doc().set(buildRemovalNotification({ ...payload, userId }));
    report.notified.push(userId);
  }
}

async function userIdForPlayer(ctx, playerId) {
  if (!playerId) return null;
  const snap = await ctx.db.collection('players').doc(playerId).get();
  if (!snap.exists) return playerId; // player doc id == uid for registered users
  return snap.data().userId || null;
}

async function cascadeTeam(ctx, id, data, opts, report) {
  const leaders = [];
  for (const pid of [data.captainId, data.viceCaptainId]) {
    const uid = await userIdForPlayer(ctx, pid);
    if (uid) leaders.push(uid);
  }
  const recipients = opts.notify === false ? [] : teamRecipients(data, leaders, ctx.actorUid);

  // Roster membership: players keep their profile, they just leave the team.
  const byIds = await ctx.db.collection('players').where('teamIds', 'array-contains', id).get();
  const byLegacy = await ctx.db.collection('players').where('teamId', '==', id).get();
  const seen = new Set();
  const memberUserIds = [];
  for (const d of [...byIds.docs, ...byLegacy.docs]) {
    if (seen.has(d.id)) continue;
    seen.add(d.id);
    const p = d.data();
    const update = { teamIds: ctx.fv.arrayRemove(id), updatedAt: ctx.ts };
    if (p.teamId === id) {
      const rest = (p.teamIds || []).filter((t) => t !== id);
      update.teamId = rest.length ? rest[0] : ctx.fv.delete();
    }
    if (p.rosterChangeTeamId === id) update.rosterChangeTeamId = ctx.fv.delete();
    await d.ref.update(update);
    if (p.userId) memberUserIds.push(p.userId);
  }
  report.playersUpdated = seen.size;

  for (const uid of uniq([data.createdBy, ...memberUserIds])) {
    const ref = ctx.db.collection('users').doc(uid).collection('teamNotificationPrefs').doc(id);
    const s = await ref.get();
    if (s.exists) await ref.delete();
  }
  await deleteWhere(ctx, 'teamFollowers', 'teamId', id, report);
  await deleteWhere(ctx, 'team_roster_reports', 'teamId', id, report);

  // Tournaments that listed the team.
  const tours = await ctx.db.collection('tournaments').where('teamIds', 'array-contains', id).get();
  for (const t of tours.docs) {
    await t.ref.update({ teamIds: ctx.fv.arrayRemove(id), updatedAt: ctx.ts });
  }
  report.tournamentsUpdated = tours.docs.length;
  await deleteWhere(ctx, 'tournament_team_requests', 'teamId', id, report);

  // Org team: the club entry loses its linked team (org keeps its history).
  const clubId = data.orgLock?.clubId;
  if (clubId) {
    const clubRef = ctx.db.collection('series_clubs').doc(clubId);
    const club = await clubRef.get();
    if (club.exists && club.data().linkedTeamId === id) {
      await clubRef.update({ linkedTeamId: ctx.fv.delete(), updatedAt: ctx.ts });
    }
  }

  await ctx.recursiveDelete(ctx.db.collection('teams').doc(id)); // + join_requests, profileViews
  await deleteStorageFolder(ctx, `teams/${id}`, report);
  await notifyAll(ctx, recipients, {
    type: 'team', id, name: data.name, reason: opts.reason, actorUid: ctx.actorUid, ts: ctx.ts,
    extra: { teamName: data.name || '' },
  }, report);
}

async function detachOrDeleteMatches(ctx, docs, { field, removedField }, report) {
  for (const d of docs) {
    const m = d.data();
    if (matchFateOnParentDelete(m) === 'delete') {
      await ctx.recursiveDelete(d.ref);
      await deleteStorageFolder(ctx, `matches/${d.id}`, report);
      report.matchesDeleted = (report.matchesDeleted || 0) + 1;
    } else {
      const update = { [field]: ctx.fv.delete(), [removedField]: m[field], updatedAt: ctx.ts };
      if (field === 'seriesId') update.seriesOfficialStatus = ctx.fv.delete();
      await d.ref.update(update);
      report.matchesKept = (report.matchesKept || 0) + 1;
    }
  }
}

const TOURNAMENT_COLLECTIONS = [
  'tournament_groups', 'tournament_rounds', 'tournament_points_tables', 'tournament_officials',
  'tournament_sponsors', 'tournament_team_requests',
];

async function cascadeTournament(ctx, id, data, opts, report) {
  const members = await ctx.db.collection('tournament_members').where('tournamentId', '==', id).get();
  const recipients = opts.notify === false
    ? []
    : tournamentRecipients(data, members.docs.map((d) => d.data()), ctx.actorUid);

  const linked = await ctx.db.collection('matches').where('tournamentId', '==', id).get();
  const seen = new Set(linked.docs.map((d) => d.id));
  const docs = [...linked.docs];
  for (const mid of data.matchIds || []) {
    if (seen.has(mid)) continue;
    const s = await ctx.db.collection('matches').doc(mid).get();
    if (s.exists && s.data().tournamentId === id) docs.push(s);
  }
  await detachOrDeleteMatches(ctx, docs, { field: 'tournamentId', removedField: 'removedTournamentId' }, report);

  for (const c of TOURNAMENT_COLLECTIONS) await deleteWhere(ctx, c, 'tournamentId', id, report);
  for (const d of members.docs) await ctx.recursiveDelete(d.ref);
  if (members.docs.length) report.deleted.tournament_members = members.docs.length;
  await deleteDocIfExists(ctx, 'tournament_rules', id, report);
  await deleteDocIfExists(ctx, 'tournament_analytics', id, report);
  await deleteWhere(ctx, 'community_posts', 'tournamentId', id, report);

  await ctx.recursiveDelete(ctx.db.collection('tournaments').doc(id));
  await deleteStorageFolder(ctx, `tournaments/${id}`, report);
  await notifyAll(ctx, recipients, {
    type: 'tournament', id, name: data.name, reason: opts.reason, actorUid: ctx.actorUid, ts: ctx.ts,
    extra: { tournamentName: data.name || '' },
  }, report);
}

const SERIES_COLLECTIONS = [
  'series_admins', 'series_clubs', 'series_club_admins', 'series_registrations', 'series_memberships',
  'series_approvals', 'series_competitions', 'series_club_rankings', 'series_player_rankings',
  'series_audit_logs', 'series_match_digests',
];

async function cascadeSeries(ctx, id, data, opts, report) {
  const admins = await ctx.db.collection('series_admins').where('seriesId', '==', id).get();
  const recipients = opts.notify === false
    ? []
    : seriesRecipients(data, admins.docs.map((d) => d.data()), ctx.actorUid);

  // Org tournaments go with the org (their started matches are kept).
  const tours = await ctx.db.collection('tournaments').where('seriesId', '==', id).get();
  for (const t of tours.docs) {
    await cascadeTournament(ctx, t.id, t.data(), { ...opts, notify: false }, report);
  }
  report.tournamentsDeleted = tours.docs.length;

  const matches = await ctx.db.collection('matches').where('seriesId', '==', id).get();
  await detachOrDeleteMatches(ctx, matches.docs, { field: 'seriesId', removedField: 'removedSeriesId' }, report);

  // Org teams become normal teams again; their owners are told.
  const locked = await ctx.db.collection('teams').where('orgLock.seriesId', '==', id).get();
  const teamOwners = [];
  for (const t of locked.docs) {
    await t.ref.update({ orgLock: ctx.fv.delete(), updatedAt: ctx.ts });
    if (t.data().createdBy) teamOwners.push({ uid: t.data().createdBy, name: t.data().name });
  }
  report.teamsUnlocked = locked.docs.length;

  for (const c of SERIES_COLLECTIONS) await deleteWhere(ctx, c, 'seriesId', id, report);
  await ctx.recursiveDelete(ctx.db.collection('series').doc(id)); // announcements, approvals, ...
  await deleteStorageFolder(ctx, `series/${id}`, report);

  const payload = {
    type: 'series', id, name: data.name, reason: opts.reason, actorUid: ctx.actorUid, ts: ctx.ts,
    extra: { seriesId: id, seriesName: data.name || '' },
  };
  await notifyAll(ctx, recipients, payload, report);
  if (opts.notify !== false) {
    for (const o of teamOwners) {
      if (o.uid === ctx.actorUid || recipients.includes(o.uid)) continue;
      await ctx.db.collection('notifications').doc().set({
        ...buildRemovalNotification({ ...payload, userId: o.uid }),
        body: `"${data.name || 'The organization'}" was removed by CrickFlow. `
          + `Your team "${o.name || ''}" is now a normal team you fully manage.`,
      });
      report.notified.push(o.uid);
    }
  }
}

async function cascadeMatch(ctx, id, data, opts, report) {
  const recipients = opts.notify === false ? [] : uniq([data.createdBy], ctx.actorUid);
  if (data.tournamentId) {
    const tRef = ctx.db.collection('tournaments').doc(data.tournamentId);
    const t = await tRef.get();
    if (t.exists) await tRef.update({ matchIds: ctx.fv.arrayRemove(id), updatedAt: ctx.ts });
  }
  await deleteDocIfExists(ctx, 'series_match_digests', id, report);
  await ctx.recursiveDelete(ctx.db.collection('matches').doc(id)); // ball_events, overlay, ...
  await deleteStorageFolder(ctx, `matches/${id}`, report);
  report.statsReversed = false;
  await notifyAll(ctx, recipients, {
    type: 'match', id, name: data.title, reason: opts.reason, actorUid: ctx.actorUid, ts: ctx.ts,
    extra: { matchId: id },
  }, report);
}

const CASCADES = { team: cascadeTeam, tournament: cascadeTournament, series: cascadeSeries, match: cascadeMatch };

/** Runs the cascade. Exported for tests (in-memory fake db). */
async function runAdminDelete(ctx, { type, id, reason }) {
  const def = TYPES[type];
  if (!def) throw new HttpsError('invalid-argument', 'Unknown type');
  if (!id || typeof id !== 'string' || id.includes('/')) throw new HttpsError('invalid-argument', 'Bad id');
  const ref = ctx.db.collection(def.collection).doc(id);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', `This ${def.label} no longer exists`);
  const data = snap.data();
  const report = { type, id, name: data.name || data.title || '', deleted: {}, notified: [], warnings: [] };
  await CASCADES[type](ctx, id, data, { reason }, report);
  return report;
}

async function assertStaff(db, uid, permission) {
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required');
  const adminSnap = await db.collection('admin_users').doc(uid).get();
  const admin = adminSnap.exists ? adminSnap.data() : null;
  let role = null;
  if (admin?.roleId && admin.roleId !== 'superAdmin') {
    const r = await db.collection('admin_roles').doc(admin.roleId).get();
    role = r.exists ? r.data() : null;
  }
  if (!adminHasPermission(admin, role, permission)) {
    throw new HttpsError('permission-denied', 'Platform staff permission required');
  }
  return admin;
}

function storageAdapter() {
  const bucket = getStorage().bucket();
  return {
    async deletePrefix(prefix) {
      const [files] = await bucket.getFiles({ prefix });
      await Promise.all(files.map((f) => f.delete({ ignoreNotFound: true })));
      return files.length;
    },
  };
}

exports.adminDeleteEntity = onCall({ timeoutSeconds: 300, memory: '512MiB' }, async (request) => {
  const db = getFirestore();
  const { type, id } = request.data || {};
  const reason = typeof request.data?.reason === 'string' ? request.data.reason.trim().slice(0, 500) : '';
  const def = TYPES[type];
  if (!def) throw new HttpsError('invalid-argument', 'type must be team, tournament, series or match');
  const uid = request.auth?.uid;
  const admin = await assertStaff(db, uid, def.permission);
  const ts = new Date().toISOString();
  const ctx = {
    db,
    fv: { arrayRemove: (...v) => FieldValue.arrayRemove(...v), delete: () => FieldValue.delete() },
    recursiveDelete: (ref) => db.recursiveDelete(ref),
    storage: storageAdapter(),
    actorUid: uid,
    ts,
  };
  const report = await runAdminDelete(ctx, { type, id: String(id || ''), reason });
  await db.collection('admin_audit_logs').add({
    action: `${type}_deleted_permanently`,
    actorUid: uid,
    actorEmail: admin?.email || request.auth?.token?.email || '',
    targetType: type,
    targetId: report.id,
    targetName: report.name,
    reason,
    metadata: {
      deleted: report.deleted,
      notified: report.notified.length,
      matchesKept: report.matchesKept || 0,
      matchesDeleted: report.matchesDeleted || 0,
      teamsUnlocked: report.teamsUnlocked || 0,
    },
    timestamp: ts,
  });
  return report;
});

module.exports.adminHasPermission = adminHasPermission;
module.exports.matchFateOnParentDelete = matchFateOnParentDelete;
module.exports.teamRecipients = teamRecipients;
module.exports.tournamentRecipients = tournamentRecipients;
module.exports.seriesRecipients = seriesRecipients;
module.exports.buildRemovalNotification = buildRemovalNotification;
module.exports.runAdminDelete = runAdminDelete;
module.exports.TYPES = TYPES;
