/**
 * Run: node src/utils/tournamentLookingPostExpiry.test.js
 */
const assert = require('assert');
const {
  isTournamentLookingPostExpired,
} = require('./tournamentLookingPostExpiry');

const today = new Date(2026, 6, 11); // 11 July 2026

function lookingPost({ start, end, title = 'Teams wanted' }) {
  return {
    category: 'tournamentNeed',
    postKind: 'tournament',
    title,
    tournamentSnapshot: {
      startDate: start,
      endDate: end,
    },
  };
}

assert.strictEqual(
  isTournamentLookingPostExpired(
    lookingPost({
      start: '2026-07-01T00:00:00.000',
      end: '2026-07-10T00:00:00.000',
    }),
    today,
  ),
  true,
  'end before today',
);

assert.strictEqual(
  isTournamentLookingPostExpired(
    lookingPost({
      start: '2026-07-11T00:00:00.000',
      end: '2026-07-20T00:00:00.000',
    }),
    today,
  ),
  true,
  'start today',
);

assert.strictEqual(
  isTournamentLookingPostExpired(
    lookingPost({
      start: '2026-07-12T00:00:00.000',
      end: '2026-07-20T00:00:00.000',
    }),
    today,
  ),
  false,
  'start after today',
);

assert.strictEqual(
  isTournamentLookingPostExpired(
    {
      category: 'general',
      tournamentSnapshot: {
        startDate: '2026-07-01T00:00:00.000',
        endDate: '2026-07-10T00:00:00.000',
      },
    },
    today,
  ),
  false,
  'non-looking post',
);

console.log('tournamentLookingPostExpiry.test.js: all passed');
