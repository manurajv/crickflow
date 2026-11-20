/** Run: node src/series/seriesTeamStaff.test.js */
const assert = require('assert');
const {
  CLUB_ADMIN_STATUS,
  isEffectiveClubAdmin,
  isOpenClubAdminInvite,
  canInviteClubAdmin,
  nextClubAdminStatusOnAccept,
  assertReason,
  playerRemovalPath,
  isListedSquadMember,
} = require('./seriesTeamStaff');

assert.strictEqual(isEffectiveClubAdmin('active'), true);
assert.strictEqual(isEffectiveClubAdmin('invited'), false);
assert.strictEqual(isEffectiveClubAdmin('pending'), false);
assert.strictEqual(isEffectiveClubAdmin('cancelled'), false);
assert.ok(isOpenClubAdminInvite('invited'));
assert.ok(!isOpenClubAdminInvite('active'));

assert.ok(canInviteClubAdmin(null));
assert.ok(canInviteClubAdmin('removed'));
assert.ok(canInviteClubAdmin('declined'));
assert.ok(canInviteClubAdmin('cancelled'));
assert.ok(!canInviteClubAdmin('active'));
assert.ok(!canInviteClubAdmin('invited'));
assert.ok(!canInviteClubAdmin('pending'));

assert.strictEqual(nextClubAdminStatusOnAccept('approved'), 'active');
assert.strictEqual(nextClubAdminStatusOnAccept('pending'), 'pending');

assert.strictEqual(assertReason('  Too many no-shows  '), 'Too many no-shows');
assert.throws(() => assertReason(''), (e) => e.code === 'invalid-argument');
assert.throws(() => assertReason('   '), (e) => e.code === 'invalid-argument');

assert.deepStrictEqual(
  playerRemovalPath({ isOrgAdmin: true, reason: 'Injury' }),
  { mode: 'direct', reason: 'Injury' },
);
assert.deepStrictEqual(
  playerRemovalPath({ isOrgAdmin: false, reason: 'Injury' }),
  { mode: 'request', reason: 'Injury' },
);
assert.throws(
  () => playerRemovalPath({ isOrgAdmin: true, reason: '' }),
  (e) => e.code === 'invalid-argument',
);

assert.ok(isListedSquadMember('active'));
assert.ok(isListedSquadMember('pendingRemoval'));
assert.ok(!isListedSquadMember('removed'));

// Existing active admins stay effective; a client cannot jump invited → admin
// without going through accept.
assert.strictEqual(isEffectiveClubAdmin(CLUB_ADMIN_STATUS.invited), false);
assert.strictEqual(isEffectiveClubAdmin(CLUB_ADMIN_STATUS.active), true);

console.log('seriesTeamStaff tests passed');
