/** Run: node src/match/onOrgMatchSquad.test.js */
const assert = require('assert');
const { enforceOrgWalkIns } = require('./onOrgMatchSquad');

function fakeFirestore({ policy, players = {}, tournaments = {} }) {
  const updates = [];
  const docRef = (col, id) => ({
    col, id,
    get: async () => {
      if (col === 'series') {
        return { exists: true, data: () => ({ competitionPolicy: policy }) };
      }
      if (col === 'tournaments' && tournaments[id]) {
        return { exists: true, data: () => tournaments[id] };
      }
      return { exists: false, data: () => undefined };
    },
    update: async (patch) => updates.push({ col, id, patch }),
  });
  return {
    updates,
    collection: (col) => ({ doc: (id) => docRef(col, id) }),
    getAll: async (...refs) => refs.map((r) => ({
      id: r.id,
      exists: r.id in players,
      data: () => ({ userId: players[r.id] }),
    })),
  };
}

const reg = { id: 'p1', name: 'Reg', playerId: 'p1' };
const guest = { id: 'guest_1', name: 'Guest', isMatchOnlyPlayer: true, isRegisteredUser: false };
const base = {
  seriesId: 's1', seriesOfficialStatus: 'approved', status: 'scheduled',
  teamAPlayingPlayers: [reg], teamASubstitutePlayers: [], teamBPlayingPlayers: [], teamBSubstitutePlayers: [],
};

(async () => {
  const withGuest = { ...base, teamAPlayingPlayers: [reg, guest], teamACaptainId: 'guest_1' };

  // Not allowed: guest rolled back, captain slot cleared.
  let fs = fakeFirestore({ policy: { allowWalkIns: false }, players: { p1: 'u1' } });
  let removed = await enforceOrgWalkIns('m1', base, withGuest, fs);
  assert.deepStrictEqual(removed.map((w) => w.id), ['guest_1']);
  assert.strictEqual(fs.updates.length, 1);
  assert.deepStrictEqual(fs.updates[0].patch.teamAPlayingPlayers.map((s) => s.id), ['p1']);
  assert.strictEqual(fs.updates[0].patch.teamACaptainId, null);
  assert.deepStrictEqual(fs.updates[0].patch.orgWalkInsRemoved, ['Guest']);

  // Roster player without an account is also a walk-in.
  fs = fakeFirestore({ policy: { allowWalkIns: false }, players: { p1: '' } });
  removed = await enforceOrgWalkIns('m1', base, { ...base, teamAPlayingPlayers: [reg] }, fs);
  assert.strictEqual(removed, null, 'unchanged squads are ignored');
  removed = await enforceOrgWalkIns('m1', { ...base, teamAPlayingPlayers: [] }, base, fs);
  assert.deepStrictEqual(removed.map((w) => w.id), ['p1']);

  // A tournament match without seriesId of its own follows the tournament's org.
  const tMatch = { ...base, seriesId: undefined, seriesOfficialStatus: undefined, tournamentId: 't1' };
  const tWithGuest = { ...tMatch, teamAPlayingPlayers: [reg, guest] };
  fs = fakeFirestore({
    policy: { allowWalkIns: false },
    players: { p1: 'u1' },
    tournaments: { t1: { seriesId: 's1', seriesOfficialStatus: 'approved' } },
  });
  removed = await enforceOrgWalkIns('m1', tMatch, tWithGuest, fs);
  assert.deepStrictEqual(removed.map((w) => w.id), ['guest_1']);
  // ...but not a plain tournament, a rejected org tournament or an unknown one.
  for (const tournaments of [{ t1: {} }, { t1: { seriesId: 's1', seriesOfficialStatus: 'rejected' } }, {}]) {
    fs = fakeFirestore({ policy: { allowWalkIns: false }, players: { p1: 'u1' }, tournaments });
    assert.strictEqual(await enforceOrgWalkIns('m1', tMatch, tWithGuest, fs), null);
    assert.strictEqual(fs.updates.length, 0);
  }

  // Allowed (default): nothing happens.
  fs = fakeFirestore({ policy: {}, players: {} });
  assert.strictEqual(await enforceOrgWalkIns('m1', base, withGuest, fs), null);
  fs = fakeFirestore({ policy: { allowWalkIns: true } });
  assert.strictEqual(await enforceOrgWalkIns('m1', base, withGuest, fs), null);
  assert.strictEqual(fs.updates.length, 0);

  // Non-org, finished or rejected matches are ignored.
  fs = fakeFirestore({ policy: { allowWalkIns: false } });
  assert.strictEqual(await enforceOrgWalkIns('m1', { ...base, seriesId: undefined }, { ...withGuest, seriesId: undefined }, fs), null);
  assert.strictEqual(await enforceOrgWalkIns('m1', base, { ...withGuest, status: 'completed' }, fs), null);
  assert.strictEqual(await enforceOrgWalkIns('m1', base, { ...withGuest, seriesOfficialStatus: 'rejected' }, fs), null);

  // Already played: stays.
  const played = { ...withGuest, innings: [{ batsmen: [{ playerId: 'guest_1' }], bowlers: [] }] };
  fs = fakeFirestore({ policy: { allowWalkIns: false }, players: { p1: 'u1' } });
  assert.strictEqual(await enforceOrgWalkIns('m1', base, played, fs), null);
  assert.strictEqual(fs.updates.length, 0);

  console.log('onOrgMatchSquad tests passed');
})().catch((e) => { console.error(e); process.exit(1); });
