/** Run: node src/series/orgMatchDigest.test.js */
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const d = require('./orgMatchDigest');

const fixture = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../../../test/fixtures/org_leaderboard_golden.json'), 'utf8'),
);

// 1. Parity with the app: every finished org match digests to what the Dart
//    engines compute from the same matches and ball events.
const expected = fixture.expected.digests;
const counted = fixture.matches.filter(d.isDigestMatch);
assert.deepStrictEqual(
  counted.map((m) => m.id).sort(),
  Object.keys(expected).sort(),
  'same matches count as the app counts',
);
for (const match of counted) {
  const got = d.buildMatchDigest(match, fixture.ballEvents[match.id] || []);
  assert.deepStrictEqual(got.players, expected[match.id], `digest of ${match.id}`);
}

// 2. Which matches are digested.
const byId = Object.fromEntries(fixture.matches.map((m) => [m.id, m]));
assert.strictEqual(d.isDigestMatch(byId.m1), true);
assert.strictEqual(d.isDigestMatch(byId.m4), true, 'abandoned matches count for the table');
for (const id of ['x_pending', 'x_quick', 'x_noclub', 'x_live']) {
  assert.strictEqual(d.isDigestMatch(byId[id]), false, id);
}
assert.strictEqual(d.isDigestMatch(null), false);

// 3. Fielding source: events win, innings fielders are the fallback.
assert.strictEqual(d.buildMatchDigest(byId.m1, fixture.ballEvents.m1).fieldingSource, 'events');
assert.strictEqual(d.buildMatchDigest(byId.m3, []).fieldingSource, 'innings');

// 4. Maidens: split overs and short overs are not maidens.
const over = (bowlers, runs) =>
  bowlers.map((b, i) => ({
    inningsNumber: 1, overNumber: 0, sequence: i, bowlerId: b, runs: runs[i] || 0,
    isLegalDelivery: true, countsInOver: true, countsToBowler: true, eventType: 'runs',
  }));
assert.deepStrictEqual(d.maidenOversFromEvents(over(['a', 'a', 'a', 'a', 'a', 'a'], []), {}), { a: 1 });
assert.deepStrictEqual(d.maidenOversFromEvents(over(['a', 'a', 'a', 'a', 'a', 'b'], []), {}), {});
assert.deepStrictEqual(d.maidenOversFromEvents(over(['a', 'a', 'a', 'a', 'a'], []), {}), {});
assert.deepStrictEqual(d.maidenOversFromEvents(over(['a', 'a', 'a', 'a', 'a', 'a'], [0, 0, 1]), {}), {});
const byes = over(['a', 'a', 'a', 'a', 'a', 'a'], [0, 2]);
byes[1].eventType = 'bye';
assert.deepStrictEqual(d.maidenOversFromEvents(byes, {}), { a: 1 }, 'byes are not charged to the bowler');
assert.deepStrictEqual(
  d.maidenOversFromEvents(over(['a', 'a', 'a', 'a', 'a', 'a', 'a', 'a'], []), { ballsPerOver: 8 }),
  { a: 1 },
);

// 5. The fingerprint changes when something that affects the digest changes.
const fp = d.digestFingerprint(byId.m1);
assert.strictEqual(fp, d.digestFingerprint({ ...byId.m1, updatedAt: 'x', scorerIds: ['z'] }));
assert.notStrictEqual(fp, d.digestFingerprint({ ...byId.m1, seriesOfficialStatus: 'rejected' }));
assert.notStrictEqual(fp, d.digestFingerprint({ ...byId.m1, innings: [] }));

console.log('orgMatchDigest tests passed');
