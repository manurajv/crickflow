/** Run: node src/series/seriesPlayerIdentity.test.js */
const assert = require('assert');
const {
  officialIdentityFromProfile,
  applyOfficialIdentity,
} = require('./seriesRegistration');

const spoofed = {
  fullName: 'Hacker Alias',
  displayName: 'Hacker Alias',
  crickFlowPlayerId: 'FAKE-999',
  phoneNumber: '0770000000',
};

const profile = {
  displayName: 'Real Player',
  name: 'Legacy Name',
  playerId: 'CF-1001',
};

const identity = officialIdentityFromProfile(profile);
assert.strictEqual(identity.fullName, 'Real Player');
assert.strictEqual(identity.crickFlowPlayerId, 'CF-1001');

const stored = applyOfficialIdentity(spoofed, profile);
assert.strictEqual(stored.fullName, 'Real Player');
assert.strictEqual(stored.displayName, 'Real Player');
assert.strictEqual(stored.crickFlowPlayerId, 'CF-1001');
assert.strictEqual(stored.phoneNumber, '0770000000', 'non-identity fields kept');
assert.notStrictEqual(stored.fullName, spoofed.fullName);
assert.notStrictEqual(stored.crickFlowPlayerId, spoofed.crickFlowPlayerId);

const fromCfAlias = officialIdentityFromProfile({ name: 'Only Name', cfPlayerId: 'CF-2' });
assert.strictEqual(fromCfAlias.fullName, 'Only Name');
assert.strictEqual(fromCfAlias.crickFlowPlayerId, 'CF-2');

assert.deepStrictEqual(officialIdentityFromProfile(null), { fullName: '', crickFlowPlayerId: '' });
assert.strictEqual(applyOfficialIdentity(spoofed, {}).fullName, '');
assert.strictEqual(applyOfficialIdentity(spoofed, {}).crickFlowPlayerId, '');

console.log('seriesPlayerIdentity tests passed');
