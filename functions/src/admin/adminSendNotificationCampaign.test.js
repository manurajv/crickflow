/* Unit tests for admin notification campaign fan-out (in-memory fake). */
const assert = require('assert');
const ops = require('./adminSendNotificationCampaign');

function makeDb(seed) {
  const store = new Map(Object.entries(seed));
  let auto = 0;
  const getPath = (obj, p) => p.split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);
  function apply(cur, patch) {
    const out = { ...(cur || {}) };
    for (const [k, v] of Object.entries(patch)) {
      if (v && v.__op === 'delete') delete out[k];
      else out[k] = v;
    }
    return out;
  }
  function docRef(path) {
    return {
      id: path.split('/').pop(),
      path,
      async get() {
        const d = store.get(path);
        return { id: path.split('/').pop(), ref: docRef(path), exists: d !== undefined, data: () => d };
      },
      async set(data, opts) {
        if (opts && opts.merge) store.set(path, apply(store.get(path), data));
        else store.set(path, { ...data });
      },
      async update(patch) {
        if (!store.has(path)) throw new Error(`update missing ${path}`);
        store.set(path, apply(store.get(path), patch));
      },
      collection: (name) => colRef(`${path}/${name}`),
    };
  }
  function matches(data, filters) {
    return filters.every(({ field, op, value }) => {
      const v = getPath(data, field);
      if (op === '==') return v === value;
      if (op === 'in') return Array.isArray(value) && value.includes(v);
      if (op === 'array-contains') return Array.isArray(v) && v.includes(value);
      return false;
    });
  }
  function colRef(path) {
    const depth = path.split('/').length + 1;
    const docsIn = () => [...store.keys()]
      .filter((k) => k.startsWith(`${path}/`) && k.split('/').length === depth)
      .sort();
    function query(filters = [], startAfterId = null, limitN = null) {
      return {
        where(field, op, value) { return query([...filters, { field, op, value }], startAfterId, limitN); },
        orderBy() { return query(filters, startAfterId, limitN); },
        startAfter(id) {
          const v = typeof id === 'string' ? id : id?.id;
          return query(filters, v, limitN);
        },
        limit(n) { return query(filters, startAfterId, n); },
        async get() {
          let ids = docsIn();
          const docs = [];
          for (const k of ids) {
            const id = k.split('/').pop();
            if (startAfterId && id <= startAfterId) continue;
            const data = store.get(k);
            if (!matches(data || {}, filters)) continue;
            docs.push(await docRef(k).get());
            if (limitN && docs.length >= limitN) break;
          }
          return { docs, empty: docs.length === 0 };
        },
      };
    }
    return {
      doc: (id) => docRef(`${path}/${id || `auto${++auto}`}`),
      where(field, op, value) { return query([{ field, op, value }]); },
      orderBy() { return query([]); },
      limit(n) { return query([], null, n); },
    };
  }
  return {
    store,
    db: {
      collection: (name) => colRef(name),
      doc: (path) => docRef(path),
      batch() {
        const opsList = [];
        return {
          set(ref, data) { opsList.push(() => store.set(ref.path, { ...data })); },
          commit: async () => { for (const fn of opsList) fn(); },
        };
      },
    },
  };
}

function messagingSpy(failTokens = new Set()) {
  const sent = [];
  return {
    sent,
    async sendEach(messages) {
      const responses = messages.map((m) => {
        sent.push(m);
        const ok = !failTokens.has(m.token);
        return { success: ok, error: ok ? undefined : { message: 'failed' } };
      });
      return {
        responses,
        successCount: responses.filter((r) => r.success).length,
        failureCount: responses.filter((r) => !r.success).length,
      };
    },
  };
}

const staff = { roleId: 'superAdmin', isActive: true, accessStatus: 'active', email: 'crickflow.app@gmail.com' };
const actor = { uid: 'admin1', email: 'crickflow.app@gmail.com' };

function seedUsers(extra = {}) {
  return {
    'admin_users/admin1': staff,
    'users/u1': { accountStatus: 'active', country: 'LK', notificationPrefs: {} },
    'users/u1/private/fcm': { fcmToken: 'token-u1' },
    'users/u2': {
      accountStatus: 'active',
      country: 'IN',
      notificationPrefs: { receivePromotions: false, receiveTeamMatchNotifications: false },
    },
    'users/u2/private/fcm': { fcmToken: 'token-u2' },
    'users/u3': { accountStatus: 'suspended', country: 'LK' },
    'users/u3/private/fcm': { fcmToken: 'token-u3' },
    'users/u4': { accountStatus: 'active', country: 'LK' }, // no token
    'admin_notification_campaigns/c1': {
      title: 'Hello',
      body: 'World',
      type: 'announcement',
      audience: 'specificUsers',
      audienceIds: ['u1', 'u2', 'u3', 'u4'],
      status: 'draft',
      createdByUid: 'admin1',
    },
    ...extra,
  };
}

const notificationsFor = (store) => [...store.entries()]
  .filter(([k]) => k.startsWith('notifications/')).map(([, v]) => v);
const auditsFor = (store) => [...store.entries()]
  .filter(([k]) => k.startsWith('admin_audit_logs/')).map(([, v]) => v);

(async () => {
  // permissions
  {
    const fake = makeDb({ 'admin_users/x': { roleId: 'moderator', isActive: true, accessStatus: 'active' } });
    await assert.rejects(
      () => ops.assertCanSend(fake.db, 'x'),
      /canSendNotifications/,
    );
    const ok = makeDb({ 'admin_users/admin1': staff });
    const admin = await ops.assertCanSend(ok.db, 'admin1');
    assert.equal(admin.roleId, 'superAdmin');
  }

  // prefs
  {
    assert.equal(ops.shouldIncludeUser({ accountStatus: 'active' }, { type: 'announcement' }).ok, true);
    assert.equal(ops.shouldIncludeUser({ accountStatus: 'suspended' }, { type: 'announcement' }).ok, false);
    assert.equal(
      ops.shouldIncludeUser(
        { accountStatus: 'active', notificationPrefs: { receivePromotions: false } },
        { type: 'promotion' },
      ).reason,
      'prefs',
    );
    assert.equal(
      ops.shouldIncludeUser(
        { accountStatus: 'active', notificationPrefs: { receiveTeamMatchNotifications: false } },
        { type: 'match' },
      ).reason,
      'prefs',
    );
    assert.equal(
      ops.shouldIncludeUser(
        { accountStatus: 'active', notificationPrefs: { receiveFollowerNotifications: false } },
        { type: 'announcement', audience: 'teamFollowers' },
      ).reason,
      'prefs',
    );
  }

  // dry run does not write inbox or send FCM
  {
    const fake = makeDb(seedUsers());
    const msg = messagingSpy();
    const res = await ops.startCampaign({
      db: fake.db,
      messaging: msg,
      campaignId: 'c1',
      actor,
      dryRun: true,
    });
    assert.equal(res.dryRun, true);
    assert.equal(msg.sent.length, 0);
    assert.equal(notificationsFor(fake.store).length, 0);
    assert.ok(res.inbox >= 1); // u1 would get a push
    assert.ok(res.skippedPrefs >= 0);
    assert.ok(res.skippedNoToken >= 1); // u4
    assert.ok(res.skippedStatus >= 1); // u3 suspended
    const campaign = fake.store.get('admin_notification_campaigns/c1');
    assert.equal(campaign.status, 'draft');
    assert.ok(String(campaign.deliveryNote).includes('Dry run'));
    assert.ok(auditsFor(fake.store).some((a) => a.action === 'notificationDryRun'));
  }

  // live send to specific users: inbox + FCM, skip prefs/status, honor tokens
  {
    const fake = makeDb(seedUsers());
    const msg = messagingSpy();
    const res = await ops.startCampaign({
      db: fake.db,
      messaging: msg,
      campaignId: 'c1',
      actor,
      dryRun: false,
      reason: 'unit test',
    });
    assert.equal(res.dryRun, false);
    assert.equal(res.done, true);
    const inbox = notificationsFor(fake.store);
    const uids = inbox.map((n) => n.userId).sort();
    assert.deepEqual(uids, ['u1', 'u2', 'u4']); // u3 suspended, u2 still eligible for announcement
    assert.ok(inbox.every((n) => n.pushSent === true && n.adminCampaignId === 'c1'));
    assert.deepEqual(msg.sent.map((m) => m.token).sort(), ['token-u1', 'token-u2']);
    assert.equal(res.delivered, 2);
    assert.equal(res.skippedNoToken, 1);
    const campaign = fake.store.get('admin_notification_campaigns/c1');
    assert.equal(campaign.status, 'sent');
    assert.equal(campaign.deliveryEngine, ops.DELIVERY_ENGINE);
    assert.ok(auditsFor(fake.store).some((a) => a.action === 'notificationSendStarted'));
    assert.ok(auditsFor(fake.store).some((a) => a.action === 'notificationSent'));
  }

  // promotion prefs skip u2, and failed FCM is counted
  {
    const fake = makeDb(seedUsers({
      'admin_notification_campaigns/c1': {
        title: 'Promo',
        body: 'Buy',
        type: 'promotion',
        audience: 'specificUsers',
        audienceIds: ['u1', 'u2'],
        status: 'draft',
      },
    }));
    const msg = messagingSpy(new Set(['token-u1']));
    const res = await ops.startCampaign({
      db: fake.db,
      messaging: msg,
      campaignId: 'c1',
      actor,
      dryRun: false,
    });
    const inbox = notificationsFor(fake.store);
    assert.deepEqual(inbox.map((n) => n.userId), ['u1']);
    assert.equal(res.failed, 1);
    assert.equal(res.skippedPrefs, 1);
    assert.equal(res.delivered, 0);
  }

  // everyone + pagination across two worker ticks
  {
    const extra = {};
    for (let i = 1; i <= 5; i++) {
      extra[`users/p${i}`] = { accountStatus: 'active' };
      extra[`users/p${i}/private/fcm`] = { fcmToken: `tok-${i}` };
    }
    extra['admin_notification_campaigns/wide'] = {
      title: 'All',
      body: 'Hi',
      type: 'system',
      audience: 'everyone',
      status: 'draft',
    };
    const fake = makeDb({ 'admin_users/admin1': staff, ...extra });
    const msg = messagingSpy();
    const first = await ops.processCampaignChunk({
      db: fake.db,
      messaging: msg,
      campaign: fake.store.get('admin_notification_campaigns/wide'),
      cursor: null,
      dryRun: true,
      actorUid: 'admin1',
      limit: 2,
      maxScan: 4,
    });
    assert.equal(first.scanned, 4);
    assert.equal(first.truncated, true);
    assert.ok(first.nextCursor);
    assert.equal(msg.sent.length, 0);
  }

  // unsupported audience
  {
    const fake = makeDb(seedUsers({
      'admin_notification_campaigns/c1': {
        title: 'X', body: 'Y', type: 'system', audience: 'communityMembers', status: 'draft',
      },
    }));
    await assert.rejects(
      () => ops.startCampaign({ db: fake.db, messaging: messagingSpy(), campaignId: 'c1', actor, dryRun: true }),
      /no reliable recipient list/,
    );
  }

  // rate limit: concurrent sending
  {
    const fake = makeDb({
      'admin_users/admin1': staff,
      'admin_notification_meta/sendRate': { sendingCampaignId: 'other', hourKey: ops.hourKey(), startsThisHour: 1 },
      'admin_notification_campaigns/c1': {
        title: 'X', body: 'Y', type: 'system', audience: 'specificUsers', audienceIds: ['u1'], status: 'draft',
      },
      'users/u1': { accountStatus: 'active' },
    });
    await assert.rejects(
      () => ops.startCampaign({ db: fake.db, messaging: messagingSpy(), campaignId: 'c1', actor, dryRun: false }),
      /already sending/,
    );
  }

  // rate limit: max starts per hour
  {
    const fake = makeDb({
      'admin_users/admin1': staff,
      'admin_notification_meta/sendRate': { hourKey: ops.hourKey(), startsThisHour: ops.MAX_STARTS_PER_HOUR },
      'admin_notification_campaigns/c1': {
        title: 'X', body: 'Y', type: 'system', audience: 'specificUsers', audienceIds: ['u1'], status: 'draft',
      },
      'users/u1': { accountStatus: 'active' },
    });
    await assert.rejects(
      () => ops.startCampaign({ db: fake.db, messaging: messagingSpy(), campaignId: 'c1', actor, dryRun: false }),
      /Rate limit/,
    );
  }

  // country audience filters
  {
    const fake = makeDb(seedUsers({
      'admin_notification_campaigns/c1': {
        title: 'LK', body: 'Only', type: 'system', audience: 'country', country: 'LK', status: 'draft',
      },
    }));
    const page = await ops.resolveAudiencePage(fake.db, fake.store.get('admin_notification_campaigns/c1'), null, 20);
    assert.ok(page.uids.includes('u1'));
    assert.ok(page.uids.includes('u4'));
    assert.ok(!page.uids.includes('u2'));
  }

  // team followers audience
  {
    const fake = makeDb({
      'users/u1': { accountStatus: 'active' },
      'users/u1/private/fcm': { fcmToken: 't1' },
      'teamFollowers/teamA_u1': { teamId: 'teamA', userId: 'u1' },
      'admin_notification_campaigns/c1': {
        title: 'T', body: 'B', type: 'announcement', audience: 'teamFollowers', teamId: 'teamA', status: 'draft',
      },
    });
    const page = await ops.resolveAudiencePage(fake.db, { ...fake.store.get('admin_notification_campaigns/c1') }, null, 20);
    assert.deepEqual(page.uids, ['u1']);
  }

  // already sent cannot restart
  {
    const fake = makeDb(seedUsers({
      'admin_notification_campaigns/c1': {
        title: 'X', body: 'Y', type: 'system', audience: 'specificUsers', audienceIds: ['u1'], status: 'sent',
      },
    }));
    await assert.rejects(
      () => ops.startCampaign({ db: fake.db, messaging: messagingSpy(), campaignId: 'c1', actor, dryRun: false }),
      /already sent/,
    );
  }

  // worker ignores campaigns not armed / not v1 (legacy queued stubs stay unsent)
  {
    const fake = makeDb({
      'admin_notification_campaigns/legacy': {
        title: 'Old', body: 'Q', status: 'queued', deliveryNote: 'Mass FCM fan-out is not executed',
      },
    });
    const res = await ops.processNextChunk({ db: fake.db, messaging: messagingSpy(), campaignId: 'legacy' });
    assert.equal(res.skipped, true);
    assert.equal(notificationsFor(fake.store).length, 0);
  }

  console.log('adminSendNotificationCampaign tests passed');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
