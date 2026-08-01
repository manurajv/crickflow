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

// No-ball balls faced: NB+bat / NB+LB increment BF; NB-only / NB+bye do not.
// Over legalBalls must stay unchanged.
const nbLineup = {
  inningsNumber: 1,
  battingTeamId: 'ta',
  bowlingTeamId: 'tb',
  strikerId: 'b1',
  nonStrikerId: 'b2',
  currentBowlerId: 'bowl1',
  batsmen: [
    { playerId: 'b1', playerName: 'Striker', runs: 0, balls: 0 },
    { playerId: 'b2', playerName: 'Non', runs: 0, balls: 0 },
  ],
  bowlers: [{ playerId: 'bowl1', playerName: 'Bowler' }],
};

const nbBat = replayInnings(
  nbLineup,
  [
    {
      sequence: 1,
      inningsNumber: 1,
      eventType: 'noBall',
      runs: 2,
      batsmanRuns: 1,
      extraRuns: 1,
      isLegalDelivery: false,
      noBallRunsMode: 'bat',
      noBallRuns: 1,
      strikerId: 'b1',
      nonStrikerId: 'b2',
      bowlerId: 'bowl1',
      overNumber: 0,
      ballInOver: 1,
    },
  ],
  rules,
);
assert.strictEqual(nbBat.legalBalls, 0);
assert.strictEqual(nbBat.batsmen.find((b) => b.playerId === 'b1').runs, 1);
assert.strictEqual(nbBat.batsmen.find((b) => b.playerId === 'b1').balls, 1);

const nbOnly = replayInnings(
  nbLineup,
  [
    {
      sequence: 1,
      inningsNumber: 1,
      eventType: 'noBall',
      runs: 1,
      batsmanRuns: 0,
      extraRuns: 1,
      isLegalDelivery: false,
      noBallRunsMode: 'bat',
      noBallRuns: 1,
      strikerId: 'b1',
      nonStrikerId: 'b2',
      bowlerId: 'bowl1',
      overNumber: 0,
      ballInOver: 1,
    },
  ],
  rules,
);
assert.strictEqual(nbOnly.legalBalls, 0);
assert.strictEqual(nbOnly.batsmen.find((b) => b.playerId === 'b1').balls, 0);

const nbBye = replayInnings(
  nbLineup,
  [
    {
      sequence: 1,
      inningsNumber: 1,
      eventType: 'noBall',
      runs: 2,
      batsmanRuns: 0,
      extraRuns: 1,
      isLegalDelivery: false,
      noBallRunsMode: 'bye',
      noBallByeRuns: 1,
      byeRuns: 1,
      noBallRuns: 1,
      strikerId: 'b1',
      nonStrikerId: 'b2',
      bowlerId: 'bowl1',
      overNumber: 0,
      ballInOver: 1,
    },
  ],
  rules,
);
assert.strictEqual(nbBye.batsmen.find((b) => b.playerId === 'b1').balls, 0);

const nbLb = replayInnings(
  nbLineup,
  [
    {
      sequence: 1,
      inningsNumber: 1,
      eventType: 'noBall',
      runs: 2,
      batsmanRuns: 0,
      extraRuns: 1,
      isLegalDelivery: false,
      noBallRunsMode: 'legBye',
      noBallLegByeRuns: 1,
      legByeRuns: 1,
      noBallRuns: 1,
      strikerId: 'b1',
      nonStrikerId: 'b2',
      bowlerId: 'bowl1',
      overNumber: 0,
      ballInOver: 1,
    },
  ],
  rules,
);
assert.strictEqual(nbLb.legalBalls, 0);
assert.strictEqual(nbLb.batsmen.find((b) => b.playerId === 'b1').balls, 1);

// Retired hurt: not a wicket, partnership continues, bowler unchanged, returnable.
const rhLineup = {
  inningsNumber: 1,
  battingTeamId: 'ta',
  bowlingTeamId: 'tb',
  strikerId: 'b1',
  nonStrikerId: 'b2',
  currentBowlerId: 'bowl1',
  batsmen: [
    { playerId: 'b1', playerName: 'Striker', runs: 12, balls: 8 },
    { playerId: 'b2', playerName: 'Non', runs: 3, balls: 5 },
  ],
  bowlers: [
    {
      playerId: 'bowl1',
      playerName: 'Bowler',
      oversBowledBalls: 8,
      runsConceded: 15,
      wickets: 1,
    },
  ],
  totalRuns: 15,
  totalWickets: 1,
  legalBalls: 13,
  extras: 0,
  partnershipRuns: 15,
  partnershipBalls: 13,
};

const rhReplayed = replayInnings(
  rhLineup,
  [
    {
      sequence: 1,
      inningsNumber: 1,
      eventType: 'wicket',
      wicketType: 'retiredHurt',
      retiredHurt: true,
      isEligibleToReturn: true,
      isWicket: false,
      runs: 0,
      batsmanRuns: 0,
      isLegalDelivery: false,
      countsInOver: false,
      countsToBowler: false,
      dismissedPlayerId: 'b1',
      strikerId: 'b1',
      nonStrikerId: 'b2',
      bowlerId: 'bowl1',
      overNumber: 2,
      ballInOver: 1,
    },
  ],
  rules,
);
assert.strictEqual(rhReplayed.totalWickets, 1);
assert.strictEqual(rhReplayed.totalRuns, 15);
assert.strictEqual(rhReplayed.legalBalls, 13);
assert.strictEqual(rhReplayed.partnershipRuns, 15);
assert.strictEqual(rhReplayed.partnershipBalls, 13);
assert.strictEqual(rhReplayed.bowlers[0].wickets, 1);
assert.strictEqual(rhReplayed.bowlers[0].oversBowledBalls, 8);
const rhBatter = rhReplayed.batsmen.find((b) => b.playerId === 'b1');
assert.strictEqual(rhBatter.isOut, false);
assert.strictEqual(rhBatter.retiredHurt, true);
assert.strictEqual(rhBatter.canReturn, true);
assert.strictEqual(rhBatter.status, 'retired_hurt');
assert.strictEqual(rhBatter.retiredAtScore, 12);
assert.strictEqual(rhBatter.retiredAtBalls, 8);
assert.strictEqual(rhBatter.runs, 12);

console.log('ballEventStats.test.js: all passed');
