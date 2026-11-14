const assert = require('assert');
const p = require('./notificationPriority');

assert.strictEqual(p.isPriorityType('team_join_request'), true);
assert.strictEqual(p.isPriorityType('series_approval_pending'), true);
assert.strictEqual(p.isPriorityType('tournament_join_approved'), true);
assert.strictEqual(p.isPriorityType('match_result'), false);
assert.strictEqual(p.isPriorityType('wicket'), false);
assert.strictEqual(p.isPriorityType(null), false);

const key = { teamId: 't', requestId: 'u1' };
assert.strictEqual(p.isTeamRequestNotification({ type: 'team_join_request', teamId: 't', playerId: 'u1' }, key), true);
assert.strictEqual(p.isTeamRequestNotification({ type: 'team_join_request', teamId: 't', playerId: 'u2' }, key), false);
assert.strictEqual(p.isTeamRequestNotification({ type: 'team_invitation', teamId: 't', userId: 'u1' }, key), true);
assert.strictEqual(p.isTeamRequestNotification({ type: 'team_join_accepted', teamId: 't', userId: 'u1' }, key), false);
assert.strictEqual(p.isTeamRequestNotification({ type: 'team_join_request', teamId: 'x', playerId: 'u1' }, key), false);

console.log('notificationPriority tests passed');
