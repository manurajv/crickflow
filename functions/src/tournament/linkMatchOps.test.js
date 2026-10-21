const assert = require('assert');
const { validateLink, canManageTournament, shouldApplyStandings } = require('./linkMatchOps');

const tournament = { createdBy: 'owner', organizerId: 'owner', status: 'ongoing', teamIds: ['a', 'b', 'c'] };
const match = { teamAId: 'a', teamBId: 'b', status: 'completed' };
const base = { tournamentId: 't1', tournament, match, uid: 'owner', memberRole: null };

const throwsCode = (fn, code) => assert.throws(fn, (e) => e.code === code, `expected ${code}`);

assert.deepStrictEqual(validateLink(base), { tournamentId: 't1', matchType: 'tournament' });
assert.ok(canManageTournament(tournament, 'x', 'admin'), 'admin member can manage');
assert.ok(!canManageTournament(tournament, 'x', 'scorer'), 'scorer cannot manage');
throwsCode(() => validateLink({ ...base, uid: 'x' }), 'permission-denied');
validateLink({ ...base, uid: 'x', memberRole: 'admin' });
throwsCode(() => validateLink({ ...base, match: { ...match, tournamentId: 't1' } }), 'already-exists');
throwsCode(() => validateLink({ ...base, match: { ...match, tournamentId: 't2' } }), 'failed-precondition');
throwsCode(() => validateLink({ ...base, match: { ...match, teamBId: 'z' } }), 'failed-precondition');
throwsCode(() => validateLink({ ...base, match: { ...match, teamBId: null } }), 'failed-precondition');
throwsCode(() => validateLink({ ...base, match: null }), 'not-found');
throwsCode(() => validateLink({ ...base, tournament: null }), 'not-found');
throwsCode(() => validateLink({ ...base, tournament: { ...tournament, status: 'completed' } }), 'failed-precondition');
assert.ok(shouldApplyStandings({ status: 'completed' }));
assert.ok(!shouldApplyStandings({ status: 'live' }));
// Register mode: match created inside the tournament.
validateLink({ ...base, match: { ...match, tournamentId: 't1' }, registerOnly: true });
throwsCode(
  () => validateLink({ ...base, match, registerOnly: true }),
  'failed-precondition',
);
throwsCode(
  () => validateLink({ ...base, uid: 'x', match: { ...match, tournamentId: 't1' }, registerOnly: true }),
  'permission-denied',
);
console.log('linkMatchOps tests passed');

// Org tournaments refuse quick matches; normal org matches of the same org are fine.
{
  const orgT = { createdBy: 'u', teamIds: ['a', 'b'], seriesId: 's1', seriesOfficialStatus: 'approved' };
  let code = null;
  try {
    validateLink({ tournamentId: 'T', tournament: orgT, match: { teamAId: 'a', teamBId: 'b', matchMode: 'quick', status: 'completed' }, uid: 'u' });
  } catch (e) { code = e.code; }
  if (code !== 'failed-precondition') throw new Error('quick match should be refused for org tournaments, got ' + code);
  validateLink({ tournamentId: 'T', tournament: orgT, match: { teamAId: 'a', teamBId: 'b', tournamentId: 'T', seriesId: 's1', matchMode: 'normal' }, uid: 'u', registerOnly: true });
  console.log('linkMatchOps org tests passed');
}
