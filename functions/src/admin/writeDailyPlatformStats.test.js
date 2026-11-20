'use strict';

const assert = require('assert');
const {
  writeDailyPlatformStatsFn,
  colomboDateId,
  COLLECTION,
} = require('./writeDailyPlatformStats');

class FakeQuery {
  constructor(docs) {
    this._docs = docs;
    this._filters = [];
  }
  where(field, op, value) {
    const next = new FakeQuery(this._docs);
    next._filters = [...this._filters, { field, op, value }];
    return next;
  }
  count() {
    const q = this;
    return {
      async get() {
        let docs = q._docs;
        for (const f of q._filters) {
          docs = docs.filter((d) => {
            if (f.op === '==') return d[f.field] === f.value;
            return true;
          });
        }
        return { data: () => ({ count: docs.length }) };
      },
    };
  }
}

class FakeDoc {
  constructor(store, id) {
    this._store = store;
    this.id = id;
  }
  async set(data, opts) {
    const prev = (opts && opts.merge && this._store[this.id]) || {};
    this._store[this.id] = { ...prev, ...data };
  }
}

class FakeDb {
  constructor(collections) {
    this._collections = collections;
  }
  collection(name) {
    const col = this._collections[name] || { docs: [], store: {} };
    if (!this._collections[name]) this._collections[name] = col;
    const q = new FakeQuery(col.docs);
    q.doc = (id) => new FakeDoc(col.store, id);
    q.set = undefined;
    // allow db.collection(name).doc(id)
    const wrapper = Object.assign(q, {
      doc: (id) => new FakeDoc(col.store, id),
    });
    return wrapper;
  }
}

async function run() {
  const id = colomboDateId(new Date('2026-11-16T18:30:00.000Z')); // 00:00 IST next day? 18:30Z is 00:00 IST on 17th
  assert.strictEqual(id, '2026-11-17');
  const sameDay = colomboDateId(new Date('2026-11-16T12:00:00.000Z')); // 17:30 IST
  assert.strictEqual(sameDay, '2026-11-16');

  const db = new FakeDb({
    users: { docs: [{}, {}, {}], store: {} },
    teams: { docs: [{}, {}], store: {} },
    matches: { docs: [{ status: 'live' }, { status: 'completed' }, { status: 'live' }], store: {} },
    players: { docs: [{}], store: {} },
    tournaments: { docs: [], store: {} },
    grounds: { docs: [{}, {}], store: {} },
    series: { docs: [{}], store: {} },
    [COLLECTION]: { docs: [], store: {} },
  });

  const result = await writeDailyPlatformStatsFn(db, new Date('2026-11-16T12:00:00.000Z'));
  assert.strictEqual(result.id, '2026-11-16');
  assert.strictEqual(result.users, 3);
  assert.strictEqual(result.teams, 2);
  assert.strictEqual(result.matches, 3);
  assert.strictEqual(result.liveMatches, 2);
  assert.strictEqual(result.players, 1);
  assert.strictEqual(result.series, 1);
  assert.strictEqual(result.source, 'v1');
  const saved = db._collections[COLLECTION].store['2026-11-16'];
  assert.ok(saved);
  assert.strictEqual(saved.users, 3);
  assert.strictEqual(saved.liveMatches, 2);
  assert.strictEqual(saved.date, '2026-11-16');

  console.log('writeDailyPlatformStats tests passed');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
