/**
 * Run: node src/series/seriesCompetitionOps.test.js
 */
const assert = require('assert');
const ops = require('./seriesCompetitionOps');

function throwsCode(fn, code) {
  try {
    fn();
  } catch (e) {
    assert.strictEqual(e.code, code, `expected ${code}, got ${e.code}: ${e.message}`);
    return;
  }
  assert.fail(`expected ${code}`);
}

// Policy defaults: approval needed, members cannot request.
assert.deepStrictEqual(ops.resolvePolicy({}), ops.DEFAULT_POLICY);
assert.strictEqual(ops.resolvePolicy({ competitionPolicy: { matchRequestsNeedApproval: false } }).matchRequestsNeedApproval, false);
throwsCode(() => ops.sanitizePolicy({ membersCanRequest: 'yes' }), 'invalid-argument');
assert.deepStrictEqual(ops.sanitizePolicy({ membersCanRequest: true, junk: 1 }), {
  tournamentRequestsNeedApproval: true, matchRequestsNeedApproval: true, membersCanRequest: true,
});

// Access matrix.
const pol = ops.resolvePolicy({});
assert.deepStrictEqual(ops.decideAccess({ kind: 'tournament', isAdmin: true, isOwner: true, policy: pol }), { role: 'superAdmin', autoApprove: true });
assert.deepStrictEqual(ops.decideAccess({ kind: 'match', isAdmin: true, isOwner: false, policy: pol }), { role: 'seriesAdmin', autoApprove: true });
assert.deepStrictEqual(ops.decideAccess({ kind: 'match', isTeamAdmin: true, policy: pol }), { role: 'clubAdmin', autoApprove: false });
assert.deepStrictEqual(
  ops.decideAccess({ kind: 'match', isTeamAdmin: true, policy: { ...pol, matchRequestsNeedApproval: false } }),
  { role: 'clubAdmin', autoApprove: true },
);
throwsCode(() => ops.decideAccess({ kind: 'match', isMember: true, policy: pol }), 'permission-denied');
assert.strictEqual(ops.decideAccess({ kind: 'tournament', isMember: true, policy: { ...pol, membersCanRequest: true } }).autoApprove, false);
throwsCode(() => ops.decideAccess({ kind: 'tournament', policy: pol }), 'permission-denied');

// Tournament link validation.
throwsCode(() => ops.validateTournamentLink({ tournament: null, seriesId: 's', uid: 'u' }), 'not-found');
throwsCode(() => ops.validateTournamentLink({ tournament: { createdBy: 'x' }, seriesId: 's', uid: 'u' }), 'permission-denied');
throwsCode(() => ops.validateTournamentLink({ tournament: { createdBy: 'u', seriesId: 'other', seriesOfficialStatus: 'approved' }, seriesId: 's', uid: 'u' }), 'failed-precondition');
throwsCode(() => ops.validateTournamentLink({ tournament: { organizerId: 'u', seriesId: 's', seriesOfficialStatus: 'pendingApproval' }, seriesId: 's', uid: 'u' }), 'already-exists');
ops.validateTournamentLink({ tournament: { createdBy: 'u', seriesId: 'other', seriesOfficialStatus: 'rejected' }, seriesId: 's', uid: 'u' });

// Match teams.
const clubs = [
  { id: 'c1', status: 'approved', linkedTeamId: 't1', name: 'One' },
  { id: 'c2', status: 'approved', linkedTeamId: 't2', name: 'Two' },
  { id: 'c3', status: 'pending', linkedTeamId: 't3' },
  { id: 'c4', status: 'approved', name: 'Unlinked' },
];
assert.deepStrictEqual(ops.resolveMatchTeams({ match: { teamAId: 't1', teamBId: 't2' }, clubs }).map((c) => c.id), ['c1', 'c2']);
throwsCode(() => ops.resolveMatchTeams({ match: { teamAId: 't1', teamBId: 't3' }, clubs }), 'failed-precondition');
throwsCode(() => ops.resolveMatchTeams({ match: { teamAId: 't1', teamBId: 'x' }, clubs }), 'failed-precondition');
assert.strictEqual(ops.requesterOwnsSide({ isAdmin: false, sideClubIds: ['c1', 'c2'], myClubIds: ['c2'] }), true);
assert.strictEqual(ops.requesterOwnsSide({ isAdmin: false, sideClubIds: ['c1', 'c2'], myClubIds: ['c9'] }), false);
assert.strictEqual(ops.canRegisterMatch({ createdBy: 'u' }, 'u'), true);
assert.strictEqual(ops.canRegisterMatch({ createdBy: 'x', scorerIds: ['u'] }, 'u'), true);
assert.strictEqual(ops.canRegisterMatch({ createdBy: 'x' }, 'u'), false);

// Tournament teams.
throwsCode(() => ops.resolveTournamentTeams({ teamClubIds: ['c3'], clubs }), 'failed-precondition');
throwsCode(() => ops.resolveTournamentTeams({ teamClubIds: ['c4'], clubs }), 'failed-precondition');
const rows = ops.resolveTournamentTeams({ teamClubIds: ['c1', 'c2', 'c1'], clubs });
assert.strictEqual(rows.length, 2);
const patch = ops.tournamentTeamsPatch({ teamIds: ['t1'], pointsTable: [{ teamId: 't1', teamName: 'One' }] }, rows);
assert.deepStrictEqual(patch.teamIds, ['t1', 't2']);
assert.strictEqual(patch.pointsTable.length, 2);

// Rankings trust only an approved competition row.
const m = { id: 'm1', seriesId: 's', tournamentId: 'T' };
assert.strictEqual(ops.competitionCoversMatch({ status: 'approved', seriesId: 's', matchId: 'm1' }, m), true);
assert.strictEqual(ops.competitionCoversMatch({ status: 'approved', seriesId: 's', tournamentId: 'T' }, m), true);
assert.strictEqual(ops.competitionCoversMatch({ status: 'pendingApproval', seriesId: 's', matchId: 'm1' }, m), false);
assert.strictEqual(ops.competitionCoversMatch({ status: 'approved', seriesId: 'x', matchId: 'm1' }, m), false);
assert.strictEqual(ops.competitionCoversMatch({ status: 'approved', seriesId: 's', matchId: 'm2' }, m), false);
assert.strictEqual(ops.competitionCoversMatch(null, m), false);

console.log('seriesCompetitionOps tests passed');
