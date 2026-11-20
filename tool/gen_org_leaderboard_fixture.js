// Generates the INPUT half of test/fixtures/org_leaderboard_golden.json.
// The expected half is produced by the Dart engines (the app is the source of
// truth): UPDATE_GOLDEN=1 flutter test test/org_leaderboard_golden_test.dart
// Re-run this only to change the scenarios:  node tool/gen_org_leaderboard_fixture.js
const fs = require('fs');
const path = require('path');

const out = path.join(__dirname, '..', 'test', 'fixtures', 'org_leaderboard_golden.json');
const prev = fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, 'utf8')) : {};

const players = [];
const addP = (id, name, userId) => players.push({ id, name, userId: userId === null ? '' : `u_${id}` });
['p1', 'p2', 'p3', 'p4'].forEach((id, i) => addP(id, `Alpha ${i + 1}`));
['p5', 'p6', 'p7', 'p8'].forEach((id, i) => addP(id, `Bravo ${i + 1}`));
['p9', 'p10'].forEach((id, i) => addP(id, `Charlie ${i + 1}`));
addP('w1', 'Walk-in Roster Wally', null); // roster entry without an account
// 'guest_g1' has no players doc at all (match-only guest).

const teams = [
  { id: 'c1', seriesId: 's1', name: 'Alpha XI', linkedTeamId: 't1', status: 'approved' },
  { id: 'c2', seriesId: 's1', name: 'Bravo XI', linkedTeamId: 't2', status: 'approved' },
  { id: 'c3', seriesId: 's1', name: 'Charlie XI', linkedTeamId: 't3', status: 'approved' },
  { id: 'c4', seriesId: 's1', name: 'Delta XI (pending)', linkedTeamId: 't4', status: 'pending' },
];

function evt(inn, over, ball, seq, o) {
  return {
    matchId: o.matchId,
    inningsNumber: inn,
    overNumber: over,
    ballInOver: ball,
    sequence: seq,
    eventType: o.eventType || 'runs',
    runs: o.runs ?? 0,
    batsmanRuns: o.batsmanRuns ?? 0,
    extraRuns: o.extraRuns ?? 0,
    isLegalDelivery: o.isLegalDelivery ?? true,
    countsAsBallFaced: o.countsAsBallFaced ?? true,
    countsInOver: o.countsInOver ?? true,
    countsToBowler: o.countsToBowler ?? true,
    isWicket: o.isWicket ?? false,
    bowlerGetsWicket: o.bowlerGetsWicket ?? false,
    strikerId: o.striker,
    bowlerId: o.bowler,
    ...(o.wicketType ? { wicketType: o.wicketType } : {}),
    ...(o.dismissedPlayerId ? { dismissedPlayerId: o.dismissedPlayerId } : {}),
    ...(o.fielder ? { primaryFielderId: o.fielder } : {}),
    ...(o.keeper ? { wicketKeeperId: o.keeper } : {}),
    ...(o.subType ? { dismissalSubType: o.subType } : {}),
  };
}

/** Build one innings' events from a compact script. */
function script(matchId, inn, overs) {
  const events = [];
  let seq = 1;
  overs.forEach((over, overNo) => {
    let legal = 0;
    for (const item of over.balls) {
      const [striker, code] = item;
      const bowler = over.bowler;
      const base = { matchId, striker, bowler };
      if (code === 'WD') {
        events.push(evt(inn, overNo, legal, seq++, {
          ...base, eventType: 'wide', runs: 1, extraRuns: 1, isLegalDelivery: false,
          countsAsBallFaced: false,
        }));
      } else if (typeof code === 'number') {
        legal += 1;
        events.push(evt(inn, overNo, legal, seq++, {
          ...base, runs: code, batsmanRuns: code,
        }));
      } else if (code.startsWith('W:')) {
        const [, type, fielder, keeper] = code.split(':');
        legal += 1;
        events.push(evt(inn, overNo, legal, seq++, {
          ...base, eventType: 'wicket', isWicket: true, wicketType: type,
          dismissedPlayerId: striker, fielder: fielder || undefined, keeper: keeper || undefined,
          bowlerGetsWicket: type !== 'runOut',
          subType: type === 'caughtBehind' ? 'caught_behind' : undefined,
        }));
      }
    }
  });
  return events;
}

function inningsFrom(events, inn, batting, bowling, totals, fielders = []) {
  const bat = new Map();
  const bowl = new Map();
  for (const e of events) {
    if (!bat.has(e.strikerId)) bat.set(e.strikerId, { playerId: e.strikerId, playerName: e.strikerId, runs: 0, balls: 0, fours: 0, sixes: 0, isOut: false });
    const b = bat.get(e.strikerId);
    b.runs += e.batsmanRuns;
    if (e.countsAsBallFaced) b.balls += 1;
    if (e.batsmanRuns === 4) b.fours += 1;
    if (e.batsmanRuns === 6) b.sixes += 1;
    if (e.isWicket) b.isOut = true;
    if (!bowl.has(e.bowlerId)) bowl.set(e.bowlerId, { playerId: e.bowlerId, playerName: e.bowlerId, oversBowledBalls: 0, runsConceded: 0, wickets: 0 });
    const w = bowl.get(e.bowlerId);
    if (e.isLegalDelivery) w.oversBowledBalls += 1;
    w.runsConceded += e.runs;
    if (e.bowlerGetsWicket) w.wickets += 1;
  }
  return {
    inningsNumber: inn,
    battingTeamId: batting,
    bowlingTeamId: bowling,
    status: 'completed',
    ...totals,
    batsmen: [...bat.values()],
    bowlers: [...bowl.values()],
    fielders,
  };
}

const rules = (o = {}) => ({
  cricketMatchType: 'limitedOvers',
  format: 'standard',
  ballType: 'leather',
  totalOvers: 20,
  ballsPerOver: 6,
  maxWickets: 10,
  ...o,
});

const org = (o) => ({
  matchType: 'single',
  matchMode: 'normal',
  seriesId: 's1',
  seriesOfficialStatus: 'approved',
  ...o,
});

const ballEvents = {};
const matches = [];

// m1: standalone leather T20. Alpha XI (t1) beat Bravo XI (t2).
{
  const id = 'm1';
  const inn1 = script(id, 1, [
    { bowler: 'p5', balls: [['p1', 6], ['p1', 4], ['p1', 6], ['p1', 6], ['p1', 4], ['p1', 6]] },
    { bowler: 'p6', balls: [['p2', 0], ['p2', 0], ['p2', 0], ['p2', 0], ['p2', 0], ['p2', 0]] }, // maiden
    { bowler: 'p5', balls: [['p1', 6], ['p1', 4], ['p1', 4], ['p1', 6], ['p1', 'W:caught:p7'], ['p3', 'WD'], ['p3', 'W:stumped:p8:p8']] },
    { bowler: 'p6', balls: [['p4', 1], ['p4', 'W:runOut:p7'], ['p2', 'W:caughtBehind:p8:p8'], ['p3', 'W:caughtAndBowled:p6'], ['p2', 2], ['p2', 0]] },
  ]);
  const inn2 = script(id, 2, [
    { bowler: 'p1', balls: [['p5', 0], ['p5', 0], ['p5', 1], ['p6', 0], ['p6', 0], ['p6', 0]] }, // 1 run -> not maiden
    { bowler: 'p2', balls: [['p5', 0], ['p5', 0], ['p5', 0], ['p5', 0], ['p5', 0], ['p5', 0]] }, // maiden for p2
    { bowler: 'p1', balls: [['p7', 'W:bowled'], ['p6', 4], ['p6', 4], ['p6', 4], ['p6', 4], ['p6', 6]] },
  ]);
  ballEvents[id] = [...inn1, ...inn2];
  matches.push(org({
    id, title: 'Alpha XI vs Bravo XI', status: 'completed',
    teamAId: 't1', teamBId: 't2', teamAName: 'Alpha XI', teamBName: 'Bravo XI',
    seriesClubAId: 'c1', seriesClubBId: 'c2', rules: rules(),
    winnerTeamId: 't1', resultSummary: 'Alpha XI won by 10 runs',
    completedAt: '2026-03-01T12:00:00.000Z',
    innings: [
      inningsFrom(inn1, 1, 't1', 't2', { totalRuns: 150, totalWickets: 6, legalBalls: 120 }),
      inningsFrom(inn2, 2, 't2', 't1', { totalRuns: 140, totalWickets: 10, legalBalls: 118 }),
    ],
  }));
}

// m2: org tournament tn1, leather 10 overs. Charlie XI (t3) beat Bravo XI (t2).
{
  const id = 'm2';
  const balls = [];
  for (let i = 0; i < 16; i += 1) balls.push(['p9', 6]);
  balls.push(['p9', 4]);
  const overs = [];
  for (let i = 0; i < balls.length; i += 6) {
    overs.push({ bowler: i % 12 === 0 ? 'p5' : 'p6', balls: balls.slice(i, i + 6) });
  }
  overs.push({ bowler: 'p5', balls: [['p10', 'W:lbw'], ['p10', 'W:bowled']] });
  const inn1 = script(id, 1, overs);
  const inn2 = script(id, 2, [
    { bowler: 'p9', balls: [['p5', 2], ['p5', 1], ['p6', 'W:caught:p10'], ['p5', 0], ['p5', 'W:caught:p10']] },
  ]);
  ballEvents[id] = [...inn1, ...inn2];
  matches.push(org({
    id, title: 'Charlie XI vs Bravo XI', status: 'completed', tournamentId: 'tn1',
    teamAId: 't3', teamBId: 't2', teamAName: 'Charlie XI', teamBName: 'Bravo XI',
    seriesClubAId: 'c3', seriesClubBId: 'c2', rules: rules({ totalOvers: 10 }),
    winnerTeamId: 't3', resultSummary: 'Charlie XI won by 60 runs',
    completedAt: '2026-03-05T12:00:00.000Z',
    innings: [
      inningsFrom(inn1, 1, 't3', 't2', { totalRuns: 110, totalWickets: 2, legalBalls: 62 }),
      inningsFrom(inn2, 2, 't2', 't3', { totalRuns: 50, totalWickets: 10, legalBalls: 45 }),
    ],
  }));
}

// m3: standalone tennis 6-over match, tied; no ball events (innings fielders used).
{
  const id = 'm3';
  matches.push(org({
    id, title: 'Alpha XI vs Charlie XI', status: 'completed',
    teamAId: 't1', teamBId: 't3', teamAName: 'Alpha XI', teamBName: 'Charlie XI',
    seriesClubAId: 'c1', seriesClubBId: 'c3',
    rules: rules({ ballType: 'tennis', format: 'tennis', totalOvers: 6 }),
    resultSummary: 'Match tied',
    completedAt: '2026-03-09T12:00:00.000Z',
    innings: [
      {
        inningsNumber: 1, battingTeamId: 't1', bowlingTeamId: 't3', status: 'completed',
        totalRuns: 60, totalWickets: 4, legalBalls: 36,
        batsmen: [
          { playerId: 'p1', playerName: 'Alpha 1', runs: 31, balls: 14, fours: 2, sixes: 3, isOut: true },
          { playerId: 'p2', playerName: 'Alpha 2', runs: 20, balls: 15, fours: 1, sixes: 2, isOut: false },
          { playerId: 'guest_g1', playerName: 'Guest Gary', runs: 9, balls: 7, fours: 1, sixes: 0, isOut: true },
        ],
        bowlers: [
          { playerId: 'p9', playerName: 'Charlie 1', oversBowledBalls: 12, runsConceded: 20, wickets: 2 },
          { playerId: 'w1', playerName: 'Wally', oversBowledBalls: 12, runsConceded: 18, wickets: 1 },
          { playerId: 'p10', playerName: 'Charlie 2', oversBowledBalls: 12, runsConceded: 22, wickets: 1 },
        ],
        fielders: [
          { playerId: 'p10', playerName: 'Charlie 2', catches: 2, runOuts: 0, stumpings: 0 },
          { playerId: 'w1', playerName: 'Wally', catches: 1, runOuts: 1, stumpings: 0 },
        ],
      },
      {
        inningsNumber: 2, battingTeamId: 't3', bowlingTeamId: 't1', status: 'completed',
        totalRuns: 60, totalWickets: 3, legalBalls: 36,
        batsmen: [
          { playerId: 'p9', playerName: 'Charlie 1', runs: 28, balls: 18, fours: 3, sixes: 1, isOut: true },
          { playerId: 'p10', playerName: 'Charlie 2', runs: 0, balls: 3, fours: 0, sixes: 0, isOut: true },
        ],
        bowlers: [
          { playerId: 'p3', playerName: 'Alpha 3', oversBowledBalls: 12, runsConceded: 26, wickets: 3 },
          { playerId: 'p4', playerName: 'Alpha 4', oversBowledBalls: 6, runsConceded: 9, wickets: 0 },
        ],
        fielders: [{ playerId: 'p1', playerName: 'Alpha 1', catches: 0, runOuts: 0, stumpings: 1 }],
      },
    ],
  }));
}

// m4: abandoned, no result.
matches.push(org({
  id: 'm4', title: 'Alpha XI vs Bravo XI (rain)', status: 'abandoned',
  teamAId: 't1', teamBId: 't2', teamAName: 'Alpha XI', teamBName: 'Bravo XI',
  seriesClubAId: 'c1', seriesClubBId: 'c2', rules: rules(),
  resultSummary: 'Match abandoned', completedAt: '2026-03-12T12:00:00.000Z', innings: [],
}));

// Excluded: pending approval, quick match, no org team on one side, other series.
const excluded = (id, patch) => org({
  id, title: id, status: 'completed',
  teamAId: 't1', teamBId: 't2', teamAName: 'Alpha XI', teamBName: 'Bravo XI',
  seriesClubAId: 'c1', seriesClubBId: 'c2', rules: rules(),
  winnerTeamId: 't1', resultSummary: 'Alpha XI won', completedAt: '2026-03-15T12:00:00.000Z',
  innings: [{
    inningsNumber: 1, battingTeamId: 't1', bowlingTeamId: 't2', status: 'completed',
    totalRuns: 300, totalWickets: 1, legalBalls: 120,
    batsmen: [{ playerId: 'p1', playerName: 'Alpha 1', runs: 250, balls: 100, fours: 20, sixes: 20, isOut: false }],
    bowlers: [], fielders: [],
  }],
  ...patch,
});
matches.push(excluded('x_pending', { seriesOfficialStatus: 'pendingApproval' }));
matches.push(excluded('x_quick', { matchMode: 'quick' }));
matches.push(excluded('x_noclub', { seriesClubBId: undefined }));
matches.push(excluded('x_live', { status: 'live' }));

const series = {
  rankingRules: { winPoints: 2, tiePoints: 1, lossPoints: 0, noResultPoints: 1, useNetRunRate: true },
};
const tournaments = [{ id: 'tn1', teamIds: ['t2', 't3'] }];

fs.writeFileSync(
  out,
  JSON.stringify({ series, teams, tournaments, players, matches, ballEvents, expected: prev.expected || {} }, null, 1) + '\n',
);
console.log('wrote', out);
