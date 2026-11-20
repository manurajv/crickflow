'use strict';

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const COLLECTION = 'admin_platform_daily_stats';
const COUNTED_COLLECTIONS = [
  ['users', 'users'],
  ['teams', 'teams'],
  ['matches', 'matches'],
  ['players', 'players'],
  ['tournaments', 'tournaments'],
  ['grounds', 'grounds'],
  ['series', 'series'],
];

/** Calendar date in Asia/Colombo (IST, no DST) as YYYY-MM-DD. */
function colomboDateId(now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Colombo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

async function countQuery(query) {
  try {
    const snap = await query.count().get();
    const data = typeof snap.data === 'function' ? snap.data() : snap;
    return (data && data.count) || 0;
  } catch (_) {
    return 0;
  }
}

async function writeDailyPlatformStats(db, now = new Date()) {
  const id = colomboDateId(now);
  const counts = {};
  for (const [field, name] of COUNTED_COLLECTIONS) {
    counts[field] = await countQuery(db.collection(name));
  }
  const liveMatches = await countQuery(
    db.collection('matches').where('status', '==', 'live'),
  );
  const payload = {
    date: id,
    ...counts,
    liveMatches,
    source: 'v1',
    writtenAt: FieldValue.serverTimestamp(),
  };
  await db.collection(COLLECTION).doc(id).set(payload, { merge: true });
  return { id, date: id, ...counts, liveMatches, source: 'v1' };
}

const writeDailyPlatformStatsSched = onSchedule(
  {
    schedule: '0 1 * * *',
    timeZone: 'Asia/Colombo',
    timeoutSeconds: 120,
    memory: '256MiB',
  },
  async () => {
    await writeDailyPlatformStats(getFirestore());
  },
);

module.exports = {
  writeDailyPlatformStats: writeDailyPlatformStatsSched,
  writeDailyPlatformStatsFn: writeDailyPlatformStats,
  colomboDateId,
  COLLECTION,
  COUNTED_COLLECTIONS,
};
