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

// Policy defaults: approval needed, only team admins, walk-ins allowed.
assert.deepStrictEqual(ops.resolvePolicy({}), ops.DEFAULT_POLICY);
{
  const d = ops.resolvePolicy({});
  assert.strictEqual(d.matchProposeAccess, 'teamAdmins');
  assert.strictEqual(d.tournamentProposeAccess, 'teamAdmins');
  assert.strictEqual(d.matchTeamAdminsNeedApproval, true);
  assert.strictEqual(d.tournamentPlayersNeedApproval, true);
  assert.strictEqual(d.allowWalkIns, true);
}
throwsCode(() => ops.sanitizePolicy({ membersCanRequest: 'yes' }), 'invalid-argument');

// Legacy single settings seed both kinds and both roles.
{
  const legacy = ops.resolvePolicy({ competitionPolicy: { membersCanRequest: true, matchRequestsNeedApproval: false } });
  assert.strictEqual(legacy.matchProposeAccess, 'everyone', 'legacy orgs keep players allowed');
  assert.strictEqual(legacy.tournamentProposeAccess, 'everyone');
  assert.strictEqual(legacy.matchTeamAdminsNeedApproval, false);
  assert.strictEqual(legacy.matchPlayersNeedApproval, false);
  assert.strictEqual(legacy.tournamentTeamAdminsNeedApproval, true);
  assert.strictEqual(legacy.allowWalkIns, true);
  assert.strictEqual(ops.resolvePolicy({ competitionPolicy: { membersCanRequest: false } }).matchProposeAccess, 'teamAdmins');
  assert.strictEqual(ops.resolvePolicy({ competitionPolicy: { proposeAccess: 'admins', membersCanRequest: true } }).tournamentProposeAccess, 'admins', 'proposeAccess wins over membersCanRequest');
  assert.strictEqual(ops.resolvePolicy({ competitionPolicy: { proposeAccess: 'junk' } }).matchProposeAccess, 'teamAdmins');
}

// Separate settings per kind and per role win over the legacy ones.
{
  const p = ops.resolvePolicy({
    competitionPolicy: {
      proposeAccess: 'teamAdmins',
      matchProposeAccess: 'everyone',
      tournamentProposeAccess: 'admins',
      matchTeamAdminsNeedApproval: false,
      matchPlayersNeedApproval: true,
      tournamentTeamAdminsNeedApproval: true,
      allowWalkIns: false,
    },
  });
  assert.strictEqual(p.matchProposeAccess, 'everyone');
  assert.strictEqual(p.tournamentProposeAccess, 'admins');
  assert.strictEqual(p.matchTeamAdminsNeedApproval, false);
  assert.strictEqual(p.matchPlayersNeedApproval, true);
  assert.strictEqual(p.tournamentPlayersNeedApproval, true, 'unset role falls back to legacy default');
  assert.strictEqual(p.allowWalkIns, false);
  // Legacy mirrors for older app builds: most permissive access, any approval.
  assert.strictEqual(p.proposeAccess, 'everyone');
  assert.strictEqual(p.membersCanRequest, true);
  assert.strictEqual(p.matchRequestsNeedApproval, true);
  const q = ops.resolvePolicy({ competitionPolicy: { matchTeamAdminsNeedApproval: false, matchPlayersNeedApproval: false } });
  assert.strictEqual(q.matchRequestsNeedApproval, false);
}

// sanitizePolicy: validation, legacy input, merge onto the existing policy.
throwsCode(() => ops.sanitizePolicy({ proposeAccess: 'nobody' }), 'invalid-argument');
throwsCode(() => ops.sanitizePolicy({ proposeAccess: true }), 'invalid-argument');
throwsCode(() => ops.sanitizePolicy({ matchProposeAccess: 'nobody' }), 'invalid-argument');
throwsCode(() => ops.sanitizePolicy({ tournamentProposeAccess: 1 }), 'invalid-argument');
throwsCode(() => ops.sanitizePolicy({ allowWalkIns: 'no' }), 'invalid-argument');
throwsCode(() => ops.sanitizePolicy({ matchPlayersNeedApproval: 'no' }), 'invalid-argument');
throwsCode(() => ops.sanitizePolicy(null), 'invalid-argument');
{
  const legacyOnly = ops.sanitizePolicy({ membersCanRequest: true, junk: 1 });
  assert.strictEqual(legacyOnly.matchProposeAccess, 'everyone');
  assert.strictEqual(legacyOnly.tournamentProposeAccess, 'everyone');
  assert.ok(!('junk' in legacyOnly));
  assert.strictEqual(ops.sanitizePolicy({ proposeAccess: 'admins' }).membersCanRequest, false);
  assert.strictEqual(ops.sanitizePolicy({ proposeAccess: 'everyone', membersCanRequest: false }).matchProposeAccess, 'everyone');

  const split = ops.sanitizePolicy({
    matchProposeAccess: 'everyone',
    tournamentProposeAccess: 'admins',
    matchPlayersNeedApproval: false,
    allowWalkIns: false,
  });
  assert.strictEqual(split.matchProposeAccess, 'everyone');
  assert.strictEqual(split.tournamentProposeAccess, 'admins');
  assert.strictEqual(split.matchPlayersNeedApproval, false);
  assert.strictEqual(split.matchTeamAdminsNeedApproval, true);
  assert.strictEqual(split.allowWalkIns, false);
  assert.strictEqual(split.proposeAccess, 'everyone');

  // New build sending legacy mirrors + per-kind keys: per-kind wins.
  const both = ops.sanitizePolicy({ ...split, proposeAccess: 'everyone', membersCanRequest: true, matchRequestsNeedApproval: true });
  assert.strictEqual(both.tournamentProposeAccess, 'admins');
  assert.strictEqual(both.matchPlayersNeedApproval, false);

  // Partial / legacy edits merge onto the existing org policy.
  const next = ops.sanitizePolicy({ matchRequestsNeedApproval: false }, split);
  assert.strictEqual(next.tournamentProposeAccess, 'admins', 'untouched kind kept');
  assert.strictEqual(next.allowWalkIns, false, 'walk-in setting kept by an older client');
  assert.strictEqual(next.matchTeamAdminsNeedApproval, false);
  assert.strictEqual(next.matchProposeAccess, 'everyone');
  assert.strictEqual(ops.sanitizePolicy({ allowWalkIns: true }, split).matchProposeAccess, 'everyone');
}

// Access matrix.
const pol = ops.resolvePolicy({});
assert.deepStrictEqual(ops.decideAccess({ kind: 'tournament', isAdmin: true, isOwner: true, policy: pol }), { role: 'superAdmin', autoApprove: true });
assert.deepStrictEqual(ops.decideAccess({ kind: 'match', isAdmin: true, isOwner: false, policy: pol }), { role: 'seriesAdmin', autoApprove: true });
assert.deepStrictEqual(ops.decideAccess({ kind: 'match', isTeamAdmin: true, policy: pol }), { role: 'clubAdmin', autoApprove: false });
throwsCode(() => ops.decideAccess({ kind: 'match', isMember: true, policy: pol }), 'permission-denied');
throwsCode(() => ops.decideAccess({ kind: 'tournament', policy: pol }), 'permission-denied');
{
  const mk = (competitionPolicy) => ops.resolvePolicy({ competitionPolicy });
  // Team admins only (default): players denied, team admins allowed.
  throwsCode(() => ops.decideAccess({ kind: 'match', isMember: true, policy: mk({}) }), 'permission-denied');
  assert.strictEqual(ops.decideAccess({ kind: 'tournament', isTeamAdmin: true, policy: mk({}) }).role, 'clubAdmin');
  // Everyone in the team.
  const all = mk({ proposeAccess: 'everyone' });
  assert.strictEqual(ops.decideAccess({ kind: 'match', isMember: true, policy: all }).role, 'seriesPlayer');
  assert.strictEqual(ops.decideAccess({ kind: 'tournament', isMember: true, policy: all }).role, 'seriesPlayer');
  assert.strictEqual(ops.decideAccess({ kind: 'match', isTeamAdmin: true, isMember: true, policy: all }).role, 'clubAdmin');
  // Admins only.
  const adminsOnly = mk({ proposeAccess: 'admins' });
  throwsCode(() => ops.decideAccess({ kind: 'match', isTeamAdmin: true, policy: adminsOnly }), 'permission-denied');
  throwsCode(() => ops.decideAccess({ kind: 'tournament', isTeamAdmin: true, isMember: true, policy: adminsOnly }), 'permission-denied');
  assert.deepStrictEqual(ops.decideAccess({ kind: 'match', isAdmin: true, isOwner: false, policy: adminsOnly }), { role: 'seriesAdmin', autoApprove: true });

  // Matches and tournaments are independent.
  const split = mk({ matchProposeAccess: 'everyone', tournamentProposeAccess: 'admins' });
  assert.strictEqual(ops.decideAccess({ kind: 'match', isMember: true, policy: split }).role, 'seriesPlayer');
  throwsCode(() => ops.decideAccess({ kind: 'tournament', isTeamAdmin: true, policy: split }), 'permission-denied');
  const split2 = mk({ matchProposeAccess: 'admins', tournamentProposeAccess: 'teamAdmins' });
  throwsCode(() => ops.decideAccess({ kind: 'match', isTeamAdmin: true, policy: split2 }), 'permission-denied');
  assert.strictEqual(ops.decideAccess({ kind: 'tournament', isTeamAdmin: true, policy: split2 }).role, 'clubAdmin');

  // Approval is per kind and per role.
  const direct = mk({
    matchProposeAccess: 'everyone',
    tournamentProposeAccess: 'everyone',
    matchTeamAdminsNeedApproval: false,
    matchPlayersNeedApproval: true,
    tournamentTeamAdminsNeedApproval: true,
    tournamentPlayersNeedApproval: false,
  });
  assert.strictEqual(ops.decideAccess({ kind: 'match', isTeamAdmin: true, policy: direct }).autoApprove, true);
  assert.strictEqual(ops.decideAccess({ kind: 'match', isMember: true, policy: direct }).autoApprove, false);
  assert.strictEqual(ops.decideAccess({ kind: 'tournament', isTeamAdmin: true, policy: direct }).autoApprove, false);
  assert.strictEqual(ops.decideAccess({ kind: 'tournament', isMember: true, policy: direct }).autoApprove, true);
  // A team admin who is also a player uses the team-admin rule.
  assert.strictEqual(ops.decideAccess({ kind: 'match', isTeamAdmin: true, isMember: true, policy: direct }).autoApprove, true);
  // Legacy approval flag still drives orgs that never saved the new fields.
  assert.strictEqual(ops.decideAccess({ kind: 'match', isTeamAdmin: true, policy: mk({ matchRequestsNeedApproval: false }) }).autoApprove, true);
  assert.strictEqual(ops.decideAccess({ kind: 'tournament', isTeamAdmin: true, policy: mk({ matchRequestsNeedApproval: false }) }).autoApprove, false);
}

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

// Quick matches never belong to an org.
throwsCode(() => ops.assertNotQuick({ matchMode: 'quick' }), 'failed-precondition');
ops.assertNotQuick({ matchMode: 'normal' });
ops.assertNotQuick({});
assert.strictEqual(ops.competitionCoversMatch({ status: 'approved', seriesId: 's', matchId: 'm1' }, { ...m, matchMode: 'quick' }), false);

console.log('seriesCompetitionOps tests passed');

// Inactive orgs take no new proposals, not even from admins.
{
  const assert = require('assert');
  const ops = require('./seriesCompetitionOps');
  assert.strictEqual(ops.isOrgOpen({ status: 'active' }), true);
  assert.strictEqual(ops.isOrgOpen({ status: 'suspended' }), false);
  assert.strictEqual(ops.isOrgOpen({ status: 'archived' }), false);
  assert.strictEqual(ops.isOrgOpen({ status: 'active', platformHold: true }), false);
  assert.throws(
    () => ops.decideAccess({ kind: 'match', isAdmin: true, isOwner: true, orgOpen: false }),
    /not active/,
  );
  assert.strictEqual(
    ops.decideAccess({ kind: 'match', isAdmin: true, isOwner: true, orgOpen: true }).autoApprove,
    true,
  );
}
