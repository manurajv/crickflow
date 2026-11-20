/* Unit tests for adminDeleteEntity (in-memory Firestore fake). */
const assert = require('assert');
const ops = require('./adminDeleteEntity');

// ---------------- tiny Firestore fake ----------------
function makeDb(seed) {
  const store = new Map(Object.entries(seed)); // path -> data
  let auto = 0;
  const getPath = (obj, p) => p.split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);
  const apply = (cur, patch) => {
    const out = { ...cur };
    for (const [k, v] of Object.entries(patch)) {
      if (v && v.__op === 'delete') delete out[k];
      else if (v && v.__op === 'arrayRemove') out[k] = (out[k] || []).filter((x) => !v.values.includes(x));
      else out[k] = v;
    }
    return out;
  };
  function docRef(path) {
    return {
      id: path.split('/').pop(),
      path,
      async get() {
        const d = store.get(path);
        return { id: path.split('/').pop(), ref: docRef(path), exists: d !== undefined, data: () => d };
      },
      async set(data) { store.set(path, { ...data }); },
      async update(patch) {
        if (!store.has(path)) throw new Error(`update missing ${path}`);
        store.set(path, apply(store.get(path), patch));
      },
      async delete() { store.delete(path); },
      collection: (name) => colRef(`${path}/${name}`),
    };
  }
  function colRef(path) {
    const depth = path.split('/').length + 1;
    const docsIn = () => [...store.keys()].filter((k) => k.startsWith(`${path}/`) && k.split('/').length === depth);
    return {
      doc: (id) => docRef(`${path}/${id || `auto${++auto}`}`),
      where(field, op, value) {
        return {
          async get() {
            const docs = [];
            for (const k of docsIn()) {
              const v = getPath(store.get(k), field);
              const hit = op === '==' ? v === value : Array.isArray(v) && v.includes(value);
              if (hit) docs.push(await docRef(k).get());
            }
            return { docs, empty: docs.length === 0 };
          },
        };
      },
    };
  }
  return {
    store,
    db: { collection: (name) => colRef(name) },
    recursiveDelete: async (ref) => {
      for (const k of [...store.keys()]) if (k === ref.path || k.startsWith(`${ref.path}/`)) store.delete(k);
    },
  };
}
const fv = { arrayRemove: (...values) => ({ __op: 'arrayRemove', values }), delete: () => ({ __op: 'delete' }) };
function ctxFor(fake, actorUid = 'staff') {
  const deletedPrefixes = [];
  return {
    ctx: {
      db: fake.db, fv, recursiveDelete: fake.recursiveDelete, actorUid, ts: 'T',
      storage: { deletePrefix: async (p) => { deletedPrefixes.push(p); return 1; } },
    },
    deletedPrefixes,
  };
}
const notificationsFor = (store) => [...store.entries()]
  .filter(([k]) => k.startsWith('notifications/')).map(([, v]) => v);

(async () => {
  // ---------------- permissions mirror the rules ----------------
  const sa = { roleId: 'superAdmin', isActive: true, accessStatus: 'active' };
  assert.ok(ops.adminHasPermission(sa, null, 'canManageTeams'));
  assert.ok(!ops.adminHasPermission({ ...sa, isActive: false }, null, 'canManageTeams'));
  assert.ok(!ops.adminHasPermission({ ...sa, accessStatus: 'suspended' }, null, 'canManageTeams'));
  const ta = { roleId: 'tournamentAdmin', isActive: true };
  assert.ok(ops.adminHasPermission(ta, null, 'canManageTournaments'));
  assert.ok(!ops.adminHasPermission(ta, null, 'canManageOrganizations'));
  assert.ok(!ops.adminHasPermission({ ...ta, permissionOverrides: { canManageTeams: false } }, null, 'canManageTeams'));
  assert.ok(ops.adminHasPermission({ roleId: 'viewer', isActive: true, permissionOverrides: { canManageOrganizations: true } }, null, 'canManageOrganizations'));
  assert.ok(!ops.adminHasPermission({ roleId: 'admin', isActive: true }, null, 'canManageTeams'));
  assert.ok(!ops.adminHasPermission(null, null, 'canManageTeams'));
  assert.ok(!ops.adminHasPermission({ roleId: 'moderator', isActive: true }, { permissions: { canManageTeams: false } }, 'canManageTeams'));

  // ---------------- pure helpers ----------------
  assert.strictEqual(ops.matchFateOnParentDelete({ status: 'scheduled' }), 'delete');
  assert.strictEqual(ops.matchFateOnParentDelete({ status: 'completed', statsProcessed: true }), 'detach');
  assert.strictEqual(ops.matchFateOnParentDelete({ status: 'live' }), 'detach');
  assert.deepStrictEqual(ops.teamRecipients({ createdBy: 'o' }, ['o', 'c', 'staff'], 'staff'), ['o', 'c']);
  assert.deepStrictEqual(
    ops.tournamentRecipients({ organizerId: 'o', createdBy: 'o' }, [{ role: 'admin', userId: 'a' }, { role: 'scorer', userId: 's' }]),
    ['o', 'a'],
  );
  assert.deepStrictEqual(
    ops.seriesRecipients({ superAdminUserId: 'own' }, [{ userId: 'a1' }, { userId: 'a2', status: 'removed' }]),
    ['own', 'a1'],
  );
  const n = ops.buildRemovalNotification({ userId: 'u', type: 'team', id: 't', name: 'Lions', reason: 'spam', ts: 'T' });
  assert.strictEqual(n.priority, true);
  assert.strictEqual(n.type, 'admin_content_removed');
  assert.match(n.body, /"Lions" was removed/);
  assert.match(n.body, /Reason: spam/);

  // ---------------- team cascade ----------------
  {
    const fake = makeDb({
      'teams/t1': { name: 'Lions', createdBy: 'owner', captainId: 'pc', viceCaptainId: 'pv', playerIds: ['owner', 'pc'] },
      'teams/t1/join_requests/x': { status: 'pending' },
      'teams/t1/profileViews/v': { lastViewedAt: 'T' },
      'teams/t2': { name: 'Other', createdBy: 'x' },
      'players/owner': { userId: 'owner', teamIds: ['t1', 't2'], teamId: 't1', rosterChangeTeamId: 't1' },
      'players/pc': { userId: 'cap', teamIds: ['t1'], teamId: 't1' },
      'players/pv': { userId: 'vice', teamIds: ['t2'] },
      'users/owner/teamNotificationPrefs/t1': { muted: true },
      'teamFollowers/t1_f': { teamId: 't1', userId: 'f' },
      'tournaments/tr': { name: 'Cup', teamIds: ['t1', 't2'] },
      'tournament_team_requests/tr_t1': { tournamentId: 'tr', teamId: 't1' },
    });
    const { ctx, deletedPrefixes } = ctxFor(fake);
    const report = await ops.runAdminDelete(ctx, { type: 'team', id: 't1', reason: 'abuse' });
    const s = fake.store;
    assert.ok(!s.has('teams/t1') && !s.has('teams/t1/join_requests/x') && !s.has('teams/t1/profileViews/v'));
    assert.ok(s.has('teams/t2'));
    assert.deepStrictEqual(s.get('players/owner').teamIds, ['t2']);
    assert.strictEqual(s.get('players/owner').teamId, 't2');
    assert.ok(!('rosterChangeTeamId' in s.get('players/owner')));
    assert.deepStrictEqual(s.get('players/pc').teamIds, []);
    assert.ok(!('teamId' in s.get('players/pc')));
    assert.ok(!s.has('users/owner/teamNotificationPrefs/t1'));
    assert.ok(!s.has('teamFollowers/t1_f'));
    assert.ok(!s.has('tournament_team_requests/tr_t1'));
    assert.deepStrictEqual(s.get('tournaments/tr').teamIds, ['t2']);
    assert.deepStrictEqual(deletedPrefixes, ['teams/t1/']);
    const notes = notificationsFor(s);
    assert.deepStrictEqual(notes.map((x) => x.userId).sort(), ['cap', 'owner', 'vice']);
    assert.ok(notes.every((x) => x.removedTeamId === 't1' && x.priority === true));
    assert.strictEqual(report.playersUpdated, 2);
  }

  // ---------------- tournament cascade keeps played matches ----------------
  {
    const fake = makeDb({
      'tournaments/tr': { name: 'Cup', organizerId: 'org', matchIds: ['m1', 'm2', 'm3'] },
      'tournament_members/tr_org': { tournamentId: 'tr', userId: 'org', role: 'owner' },
      'tournament_members/tr_a': { tournamentId: 'tr', userId: 'adm', role: 'admin' },
      'tournament_groups/g': { tournamentId: 'tr' },
      'tournament_points_tables/p': { tournamentId: 'tr' },
      'tournament_rules/tr': { overs: 20 },
      'community_posts/cp': { tournamentId: 'tr' },
      'community_posts/cp/comments/c': { text: 'hi' },
      'matches/m1': { tournamentId: 'tr', status: 'completed', statsProcessed: true },
      'matches/m1/ball_events/b': { runs: 4 },
      'matches/m2': { tournamentId: 'tr', status: 'scheduled' },
      'matches/m3': { tournamentId: 'tr', status: 'live' },
    });
    const { ctx } = ctxFor(fake);
    const report = await ops.runAdminDelete(ctx, { type: 'tournament', id: 'tr' });
    const s = fake.store;
    assert.ok(!s.has('tournaments/tr') && !s.has('tournament_groups/g') && !s.has('tournament_points_tables/p'));
    assert.ok(!s.has('tournament_rules/tr') && !s.has('tournament_members/tr_a'));
    assert.ok(!s.has('community_posts/cp') && !s.has('community_posts/cp/comments/c'));
    assert.ok(!s.has('matches/m2'), 'unplayed match deleted');
    assert.ok(s.has('matches/m1') && s.has('matches/m1/ball_events/b'), 'completed match kept for career stats');
    assert.ok(!('tournamentId' in s.get('matches/m1')));
    assert.strictEqual(s.get('matches/m1').removedTournamentId, 'tr');
    assert.ok(!('tournamentId' in s.get('matches/m3')));
    assert.strictEqual(report.matchesKept, 2);
    assert.strictEqual(report.matchesDeleted, 1);
    assert.deepStrictEqual(notificationsFor(s).map((x) => x.userId).sort(), ['adm', 'org']);
  }

  // ---------------- organization cascade ----------------
  {
    const fake = makeDb({
      'series/s1': { name: 'League', superAdminUserId: 'own' },
      'series/s1/announcements/a': { title: 'x' },
      'series_admins/s1_a': { seriesId: 's1', userId: 'adm', status: 'active' },
      'series_clubs/c1': { seriesId: 's1', linkedTeamId: 'tl' },
      'series_registrations/r': { seriesId: 's1' },
      'series_match_digests/mo': { seriesId: 's1' },
      'teams/tl': { name: 'Club team', createdBy: 'towner', orgLock: { seriesId: 's1', clubId: 'c1' } },
      'tournaments/st': { name: 'Org Cup', seriesId: 's1', organizerId: 'own' },
      'matches/mo': { seriesId: 's1', seriesOfficialStatus: 'approved', status: 'completed', statsProcessed: true },
      'matches/mu': { seriesId: 's1', status: 'draft' },
      'series/s2': { name: 'Other' },
    });
    const { ctx } = ctxFor(fake, 'own');
    await ops.runAdminDelete(ctx, { type: 'series', id: 's1' });
    const s = fake.store;
    for (const k of ['series/s1', 'series/s1/announcements/a', 'series_admins/s1_a', 'series_clubs/c1',
      'series_registrations/r', 'series_match_digests/mo', 'tournaments/st', 'matches/mu']) {
      assert.ok(!s.has(k), `${k} should be deleted`);
    }
    assert.ok(s.has('series/s2'));
    assert.ok(s.has('teams/tl') && !('orgLock' in s.get('teams/tl')), 'org team unlocked, not deleted');
    assert.ok(s.has('matches/mo') && !('seriesId' in s.get('matches/mo')));
    const notes = notificationsFor(s);
    // actor (own) is not notified; org admin + team owner are.
    assert.deepStrictEqual(notes.map((x) => x.userId).sort(), ['adm', 'towner']);
  }

  // ---------------- match + errors ----------------
  {
    const fake = makeDb({
      'tournaments/tr': { matchIds: ['m1', 'm2'] },
      'matches/m1': { tournamentId: 'tr', createdBy: 'scorer', title: 'A v B', status: 'completed' },
      'matches/m1/ball_events/b': { runs: 1 },
    });
    const { ctx } = ctxFor(fake);
    const r = await ops.runAdminDelete(ctx, { type: 'match', id: 'm1' });
    assert.ok(!fake.store.has('matches/m1') && !fake.store.has('matches/m1/ball_events/b'));
    assert.deepStrictEqual(fake.store.get('tournaments/tr').matchIds, ['m2']);
    assert.deepStrictEqual(r.notified, ['scorer']);
    await assert.rejects(ops.runAdminDelete(ctx, { type: 'match', id: 'm1' }), (e) => e.code === 'not-found');
    await assert.rejects(ops.runAdminDelete(ctx, { type: 'user', id: 'x' }), (e) => e.code === 'invalid-argument');
    await assert.rejects(ops.runAdminDelete(ctx, { type: 'team', id: 'a/b' }), (e) => e.code === 'invalid-argument');
  }

  console.log('adminDeleteEntity tests passed');
})().catch((e) => { console.error(e); process.exit(1); });
