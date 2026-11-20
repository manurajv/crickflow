/** Run: node src/match/onOrgMatchDigest.test.js */
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { syncMatchDigest, rebuildSeriesDigests } = require('./onOrgMatchDigest');

const fixture = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../../../test/fixtures/org_leaderboard_golden.json'), 'utf8'),
);

/** Tiny in-memory Firestore: matches (+ball_events) and series_match_digests. */
function fakeDb() {
  const digests = new Map();
  const matches = new Map(fixture.matches.map((m) => [m.id, m]));
  return {
    digests,
    collection(name) {
      if (name === 'series_match_digests') {
        return {
          doc: (id) => ({
            get: async () => ({ exists: digests.has(id), data: () => digests.get(id) }),
            set: async (v) => { digests.set(id, v); },
            delete: async () => { digests.delete(id); },
          }),
        };
      }
      return {
        where: (_f, _op, seriesId) => ({
          get: async () => ({
            docs: [...matches.values()]
              .filter((m) => m.seriesId === seriesId)
              .map((m) => ({ id: m.id, data: () => m })),
          }),
        }),
        doc: (id) => ({
          collection: () => ({
            orderBy: () => ({
              get: async () => ({
                docs: (fixture.ballEvents[id] || []).map((e, i) => ({ id: `e${i}`, data: () => e })),
              }),
            }),
          }),
        }),
      };
    },
  };
}

(async () => {
  const db = fakeDb();
  const m1 = fixture.matches.find((m) => m.id === 'm1');

  assert.strictEqual(await syncMatchDigest(db, 'm1', m1), 'written');
  const stored = db.digests.get('m1');
  assert.strictEqual(stored.seriesId, 's1');
  assert.strictEqual(stored.matchId, 'm1');
  assert.deepStrictEqual(stored.players, fixture.expected.digests.m1);
  assert.ok(stored.fingerprint && stored.updatedAt && stored.version === 1);

  // Stops counting (rejected / deleted) => digest removed.
  assert.strictEqual(await syncMatchDigest(db, 'm1', { ...m1, seriesOfficialStatus: 'rejected' }), 'removed');
  assert.strictEqual(db.digests.has('m1'), false);
  assert.strictEqual(await syncMatchDigest(db, 'm1', null), 'skipped');

  // Backfill covers every counted match of the series, once.
  const out = await rebuildSeriesDigests(db, 's1');
  assert.deepStrictEqual(
    [...db.digests.keys()].sort(),
    Object.keys(fixture.expected.digests).sort(),
  );
  assert.strictEqual(out.written, Object.keys(fixture.expected.digests).length);
  assert.strictEqual(out.skipped, fixture.matches.length - out.written);

  console.log('onOrgMatchDigest tests passed');
})().catch((e) => { console.error(e); process.exit(1); });
