/** Run: node src/series/orgWalkIns.test.js */
const assert = require('assert');
const w = require('./orgWalkIns');

const guest = { id: 'guest_1', name: 'Guest One', isMatchOnlyPlayer: true, isRegisteredUser: false };
const roster = { id: 'p1', name: 'Reg', playerId: 'p1', isRegisteredUser: true };
const rosterWalkIn = { id: 'p2', name: 'Roster Walkin', playerId: 'p2', isRegisteredUser: true };
const match = {
  teamAPlayingPlayers: [roster, guest],
  teamASubstitutePlayers: [rosterWalkIn],
  teamBPlayingPlayers: [{ id: 'p3', name: 'B', playerId: 'p3' }],
  teamBSubstitutePlayers: [],
  teamACaptainId: 'guest_1',
  teamAWicketKeeperId: 'p1',
  teamASquadIds: ['p1', 'guest_1'],
};

assert.strictEqual(w.isGuestSnapshot(guest), true);
assert.strictEqual(w.isGuestSnapshot({ id: 'guest_x' }), true);
assert.strictEqual(w.isGuestSnapshot(roster), false);
assert.deepStrictEqual(w.rosterPlayerIdsToCheck(match).sort(), ['p1', 'p2', 'p3']);

// Guests are always walk-ins; roster players only when their doc has no account.
assert.deepStrictEqual(w.findWalkIns(match).map((x) => x.id), ['guest_1']);
const users = new Map([['p1', 'u1'], ['p2', ''], ['p3', 'u3']]);
assert.deepStrictEqual(w.findWalkIns(match, users).map((x) => x.id), ['guest_1', 'p2']);
// Unknown profile (deleted doc) never blocks.
assert.deepStrictEqual(w.findWalkIns(match, new Map([['p2', undefined]])).map((x) => x.id), ['guest_1', 'p2']);
assert.deepStrictEqual(w.findWalkIns({ teamAPlayingPlayers: [roster] }, new Map()), []);
assert.deepStrictEqual(w.findWalkIns({}, users), []);

// Stripping.
{
  const found = w.findWalkIns(match, users);
  const { patch, removed, kept } = w.stripWalkInsPatch(match, found);
  assert.strictEqual(removed.length, 2);
  assert.strictEqual(kept.length, 0);
  assert.deepStrictEqual(patch.teamAPlayingPlayers.map((s) => s.id), ['p1']);
  assert.deepStrictEqual(patch.teamASubstitutePlayers, []);
  assert.deepStrictEqual(patch.teamASquadIds, ['p1']);
  assert.strictEqual(patch.teamACaptainId, null);
  assert.ok(!('teamAWicketKeeperId' in patch));
  assert.ok(!('teamBPlayingPlayers' in patch));
}
// A walk-in who already played stays.
{
  const played = {
    ...match,
    innings: [{ batsmen: [{ playerId: 'guest_1' }], bowlers: [], fielders: [] }],
  };
  const { patch, removed, kept } = w.stripWalkInsPatch(played, w.findWalkIns(played, users));
  assert.deepStrictEqual(kept.map((x) => x.id), ['guest_1']);
  assert.deepStrictEqual(removed.map((x) => x.id), ['p2']);
  assert.ok(!('teamAPlayingPlayers' in patch));
  assert.ok(!('teamACaptainId' in patch));
}
assert.strictEqual(w.stripWalkInsPatch(match, []).patch, null);
assert.match(w.walkInsMessage([{ name: 'A' }, { name: 'B' }]), /does not allow walk-in players: A, B/);

console.log('orgWalkIns tests passed');
