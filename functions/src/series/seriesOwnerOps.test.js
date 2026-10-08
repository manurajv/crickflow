/**
 * Run: node src/series/seriesOwnerOps.test.js
 */
const assert = require('assert');
const {
  OwnerOpError,
  seriesOwnerUid,
  lifecycleNextStatus,
  validateOwnershipTransfer,
  validateAnnouncement,
  announcementRecipients,
} = require('./seriesOwnerOps');

const throwsCode = (fn, code) => assert.throws(fn, (e) => e instanceof OwnerOpError && e.code === code);

// Owner resolution
assert.strictEqual(seriesOwnerUid({ superAdminUserId: 'a', createdBy: 'b' }), 'a');
assert.strictEqual(seriesOwnerUid({ superAdminUserId: null, createdBy: 'b' }), 'b');
assert.strictEqual(seriesOwnerUid({ createdBy: 'b' }), 'b');

// Lifecycle
assert.strictEqual(lifecycleNextStatus({ status: 'active' }, 'archive'), 'archived');
assert.strictEqual(lifecycleNextStatus({ status: 'suspended' }, 'archive'), 'archived');
assert.strictEqual(lifecycleNextStatus({ status: 'archived' }, 'reactivate'), 'active');
assert.strictEqual(lifecycleNextStatus({ status: 'suspended' }, 'reactivate'), 'active');
throwsCode(() => lifecycleNextStatus({ status: 'archived' }, 'archive'), 'failed-precondition');
throwsCode(() => lifecycleNextStatus({ status: 'active' }, 'reactivate'), 'failed-precondition');
throwsCode(() => lifecycleNextStatus({ status: 'suspended', platformHold: true }, 'reactivate'), 'failed-precondition');
throwsCode(() => lifecycleNextStatus({ status: 'active', platformHold: true }, 'archive'), 'failed-precondition');
throwsCode(() => lifecycleNextStatus({ status: 'active' }, 'delete'), 'invalid-argument');

// Transfer
const series = { superAdminUserId: 'owner', createdBy: 'owner' };
assert.strictEqual(
  validateOwnershipTransfer({ series, actorUid: 'owner', targetUid: ' admin1 ', targetAdmin: { status: 'active' } }),
  'admin1',
);
throwsCode(() => validateOwnershipTransfer({ series, actorUid: 'admin1', targetUid: 'x', targetAdmin: { status: 'active' } }), 'permission-denied');
throwsCode(() => validateOwnershipTransfer({ series, actorUid: 'owner', targetUid: 'owner', targetAdmin: { status: 'active' } }), 'invalid-argument');
throwsCode(() => validateOwnershipTransfer({ series, actorUid: 'owner', targetUid: 'x', targetAdmin: null }), 'failed-precondition');
throwsCode(() => validateOwnershipTransfer({ series, actorUid: 'owner', targetUid: 'x', targetAdmin: { status: 'removed' } }), 'failed-precondition');
throwsCode(() => validateOwnershipTransfer({ series: { ...series, platformHold: true }, actorUid: 'owner', targetUid: 'x', targetAdmin: { status: 'active' } }), 'failed-precondition');
// Draft without superAdminUserId: createdBy is owner
assert.strictEqual(
  validateOwnershipTransfer({ series: { createdBy: 'c' }, actorUid: 'c', targetUid: 'd', targetAdmin: { status: 'active' } }),
  'd',
);

// Announcement validation
assert.deepStrictEqual(validateAnnouncement({ title: ' Fixtures ', body: ' Out now ', audience: 'all' }), { title: 'Fixtures', body: 'Out now', audience: 'all' });
throwsCode(() => validateAnnouncement({ title: 'Hi', body: 'x' }), 'invalid-argument');
throwsCode(() => validateAnnouncement({ title: 'Hello', body: '' }), 'invalid-argument');
throwsCode(() => validateAnnouncement({ title: 'Hello', body: 'x', audience: 'public' }), 'invalid-argument');

// Recipients
const rows = {
  ownerUid: 'owner',
  seriesAdmins: [{ userId: 'a1', status: 'active' }, { userId: 'a2', status: 'removed' }],
  clubAdmins: [{ userId: 'c1', status: 'active' }, { userId: 'a1', status: 'active' }],
  memberships: [{ userId: 'm1', status: 'active' }, { userId: 'm2', status: 'suspended' }],
};
assert.deepStrictEqual(announcementRecipients({ ...rows, audience: 'all', senderUid: 'owner' }).sort(), ['a1', 'c1', 'm1']);
assert.deepStrictEqual(announcementRecipients({ ...rows, audience: 'admins', senderUid: 'a1' }).sort(), ['owner']);
assert.deepStrictEqual(announcementRecipients({ ...rows, audience: 'members', senderUid: 'owner' }), ['m1']);
assert.deepStrictEqual(announcementRecipients({ ...rows, audience: 'clubAdmins', senderUid: 'x' }).sort(), ['a1', 'c1']);

console.log('seriesOwnerOps tests passed');
