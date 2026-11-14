/**
 * Run: node src/series/seriesAdminAccess.test.js
 */
const assert = require('assert');
const {
  TIERS,
  parseSeriesAdminTier,
  isFullAdminTier,
  canScoreTier,
  isActiveAdminDoc,
} = require('./seriesAdminAccess');

assert.strictEqual(parseSeriesAdminTier(undefined), TIERS.admin);
assert.strictEqual(parseSeriesAdminTier(''), TIERS.admin);
assert.strictEqual(parseSeriesAdminTier('seriesAdmin'), TIERS.admin);
assert.strictEqual(parseSeriesAdminTier('admin'), TIERS.admin);
assert.strictEqual(parseSeriesAdminTier('scorer'), TIERS.scorer);
assert.strictEqual(parseSeriesAdminTier('viewer'), TIERS.viewer);
assert.strictEqual(parseSeriesAdminTier(' unknown '), TIERS.admin);

assert.strictEqual(isFullAdminTier('seriesAdmin'), true);
assert.strictEqual(isFullAdminTier('admin'), true);
assert.strictEqual(isFullAdminTier('scorer'), false);
assert.strictEqual(isFullAdminTier('viewer'), false);

assert.strictEqual(canScoreTier('admin'), true);
assert.strictEqual(canScoreTier('seriesAdmin'), true);
assert.strictEqual(canScoreTier('scorer'), true);
assert.strictEqual(canScoreTier('viewer'), false);

assert.strictEqual(isActiveAdminDoc({ status: 'active' }), true);
assert.strictEqual(isActiveAdminDoc({ status: 'removed' }), false);
assert.strictEqual(isActiveAdminDoc(null), false);

console.log('seriesAdminAccess.test.js ok');
