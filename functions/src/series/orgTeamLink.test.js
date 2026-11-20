const assert = require('assert');
const ops = require('./orgTeamLink');

function throwsCode(fn, code) {
  try { fn(); } catch (e) { assert.strictEqual(e.code, code); return; }
  assert.fail(`expected ${code}`);
}

assert.strictEqual(ops.formatTeamCode(42), 'TM00042');
assert.strictEqual(ops.lockIsLive(null, {}), false);
assert.strictEqual(ops.lockIsLive({ clubId: 'c' }, null), false);
assert.strictEqual(ops.lockIsLive({ clubId: 'c' }, { status: 'rejected' }), false);
assert.strictEqual(ops.lockIsLive({ clubId: 'c' }, { status: 'pending' }), true);

throwsCode(() => ops.validateLinkTarget({ team: null, uid: 'u' }), 'not-found');
throwsCode(() => ops.validateLinkTarget({ team: { createdBy: 'x' }, uid: 'u' }), 'permission-denied');
throwsCode(() => ops.validateLinkTarget({
  team: { createdBy: 'u', orgLock: { clubId: 'c' } }, uid: 'u', lockClub: { status: 'approved' },
}), 'already-exists');
ops.validateLinkTarget({ team: { createdBy: 'u' }, uid: 'u' });
ops.validateLinkTarget({
  team: { createdBy: 'u', orgLock: { clubId: 'c' } }, uid: 'u', lockClub: { status: 'rejected' },
});

const t = ops.buildServerTeam({ name: 'Lions', createdBy: 'u', playerIds: ['p1'], ts: 'T' });
assert.strictEqual(t.memberCount, 1);
assert.strictEqual(t.createdBy, 'u');
assert.deepStrictEqual(ops.buildLock({ seriesId: 's', clubId: 'c', ts: 'T' }),
  { seriesId: 's', clubId: 'c', seriesName: '', lockedAt: 'T' });

console.log('orgTeamLink tests passed');
