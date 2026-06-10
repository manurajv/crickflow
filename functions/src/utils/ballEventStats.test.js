/**
 * Run: node src/utils/ballEventStats.test.js
 */
const assert = require('assert');
const {
  replayInnings,
  collectPlayerAggFromEvents,
  fieldersFromEvents,
  verifyMatchProjection,
} = require('./ballEventStats');

const lineup = {
  inningsNumber: 1,
  battingTeamId: 'ta',
  bowlingTeamId: 'tb',
  strikerId: 'b1',
  nonStrikerId: 'b2',
  currentBowlerId: 'bowl1',
  batsmen: [
    { playerId: 'b1', playerName: 'Striker' },
    { playerId: 'b2', playerName: 'Non' },
  ],
  bowlers: [{ playerId: 'bowl1', playerName: 'Bowler' }],
};

const rules = { ballsPerOver: 6, wideRuns: 1, noBallRuns: 1, freeHitEnabled: true };

const events = [
  {
    sequence: 1,
    inningsNumber: 1,
    eventType: 'runs',
    runs: 4,
    batsmanRuns: 4,
    isLegalDelivery: true,
    strikerId: 'b1',
    nonStrikerId: 'b2',
    bowlerId: 'bowl1',
    overNumber: 0,
    ballInOver: 1,
  },
  {
    sequence: 2,
    inningsNumber: 1,
    eventType: 'wicket',
    runs: 0,
    batsmanRuns: 0,
    isLegalDelivery: true,
    isWicket: true,
    wicketType: 'caught',
    dismissedPlayerId: 'b1',
    fielderId: 'f1',
    fielderName: 'Fielder',
    strikerId: 'b1',
    nonStrikerId: 'b2',
    bowlerId: 'bowl1',
    overNumber: 0,
    ballInOver: 2,
  },
];

const replayed = replayInnings(lineup, events, rules);
assert.strictEqual(replayed.totalRuns, 4);
assert.strictEqual(replayed.totalWickets, 1);
assert.strictEqual(replayed.batsmen.find((b) => b.playerId === 'b1').runs, 4);
assert.strictEqual(replayed.batsmen.find((b) => b.playerId === 'b1').isOut, true);
assert.strictEqual(replayed.bowlers[0].wickets, 1);

assert.strictEqual(fieldersFromEvents(events)[0].catches, 1);

const match = { innings: [lineup], rules };
const agg = collectPlayerAggFromEvents(match, events);
assert.strictEqual(agg.get('b1').runs, 4);
assert.strictEqual(agg.get('b1').fours, 1);
assert.strictEqual(agg.get('bowl1').wickets, 1);
assert.strictEqual(agg.get('f1').catches, 1);

const cache = {
  innings: [
    {
      ...lineup,
      strikerId: null,
      nonStrikerId: 'b2',
      totalRuns: 4,
      totalWickets: 1,
      legalBalls: 2,
      extras: 0,
      batsmen: [
        {
          playerId: 'b1',
          playerName: 'Striker',
          runs: 4,
          balls: 2,
          fours: 1,
          sixes: 0,
          isOut: true,
        },
        { playerId: 'b2', playerName: 'Non', runs: 0, balls: 0, fours: 0, sixes: 0, isOut: false },
      ],
      bowlers: [
        {
          playerId: 'bowl1',
          playerName: 'Bowler',
          oversBowledBalls: 2,
          runsConceded: 4,
          wickets: 1,
        },
      ],
    },
  ],
};
assert.deepStrictEqual(verifyMatchProjection(cache, events), []);

console.log('ballEventStats.test.js: all passed');
