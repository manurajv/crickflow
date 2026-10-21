const assert = require('assert');
const { pickMatchHero, isEligibleHero } = require('./badges');

const match = (winnerTeamId) => ({
  teamAId: 'a',
  teamBId: 'b',
  winnerTeamId,
  innings: [
    {
      battingTeamId: 'a',
      bowlingTeamId: 'b',
      batsmen: [{ playerId: 'a1', playerName: 'A1', runs: 40 }],
      bowlers: [{ playerId: 'b2', playerName: 'B2', wickets: 1 }],
    },
    {
      battingTeamId: 'b',
      bowlingTeamId: 'a',
      batsmen: [{ playerId: 'b1', playerName: 'B1', runs: 85 }],
      bowlers: [{ playerId: 'a2', playerName: 'A2', wickets: 1 }],
    },
  ],
});

assert.strictEqual(pickMatchHero(match('a')).playerId, 'a1', 'winner-side hero');
assert.strictEqual(pickMatchHero(match(null)).playerId, 'b1', 'no result: best overall');
assert.strictEqual(isEligibleHero(match('a'), { playerId: 'b1' }), false, 'losing hero rejected');
assert.strictEqual(isEligibleHero(match('a'), { playerId: 'a1' }), true, 'winning hero kept');
assert.strictEqual(isEligibleHero(match(null), { playerId: 'b1' }), true, 'no result keeps hero');
console.log('badges.test.js: all passed');
