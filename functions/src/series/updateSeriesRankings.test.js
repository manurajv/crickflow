/**
 * Run: node src/series/updateSeriesRankings.test.js
 */
const assert = require('assert');
const {
  isOfficialSeriesMatch,
} = require('./updateSeriesRankings');

assert.strictEqual(isOfficialSeriesMatch({}), false);
assert.strictEqual(isOfficialSeriesMatch({ seriesId: 's1' }), false);
assert.strictEqual(
  isOfficialSeriesMatch({
    seriesId: 's1',
    seriesOfficialStatus: 'pendingApproval',
  }),
  false,
);
assert.strictEqual(
  isOfficialSeriesMatch({
    seriesId: 's1',
    seriesOfficialStatus: 'approved',
  }),
  true,
);
assert.strictEqual(
  isOfficialSeriesMatch({
    seriesId: 's1',
    seriesOfficialStatus: 'approved',
    seriesRankingsProcessed: true,
  }),
  false,
  'must not double-count',
);
assert.strictEqual(
  isOfficialSeriesMatch({
    seriesId: 's1',
    seriesOfficialStatus: 'rejected',
  }),
  false,
);
assert.strictEqual(
  isOfficialSeriesMatch({
    seriesId: 's1',
    seriesOfficialStatus: 'draft',
  }),
  false,
);

console.log('updateSeriesRankings.test.js: all assertions passed');
