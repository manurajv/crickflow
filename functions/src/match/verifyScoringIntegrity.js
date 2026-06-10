const { onSchedule } = require('firebase-functions/v2/scheduler');
const { getFirestore } = require('firebase-admin/firestore');
const { verifyMatchProjection } = require('../utils/ballEventStats');

const db = getFirestore();

/**
 * Nightly scan: log matches where innings projection diverges from ball_events.
 */
exports.verifyScoringIntegrity = onSchedule(
  {
    schedule: 'every day 03:00',
    timeZone: 'Asia/Colombo',
  },
  async () => {
    const liveSnap = await db
      .collection('matches')
      .where('status', '==', 'live')
      .limit(30)
      .get();

    const completedSnap = await db
      .collection('matches')
      .where('status', '==', 'completed')
      .limit(20)
      .get();

    const seen = new Set();
    const docs = [];
    for (const d of [...liveSnap.docs, ...completedSnap.docs]) {
      if (seen.has(d.id)) continue;
      seen.add(d.id);
      docs.push(d);
    }

    let checked = 0;
    let mismatches = 0;

    for (const doc of docs) {
      const match = doc.data();
      const eventsSnap = await db
        .collection('matches')
        .doc(doc.id)
        .collection('ball_events')
        .orderBy('sequence')
        .get();
      const events = eventsSnap.docs.map((e) => e.data());
      if (events.length === 0) continue;

      checked += 1;
      const issues = verifyMatchProjection(match, events);
      if (issues.length === 0) continue;

      mismatches += 1;
      console.warn(
        `ScoringIntegrity [${doc.id}] ${issues.length} issue(s):`,
        issues.join('; '),
      );

      await doc.ref.set(
        {
          scoringIntegrity: {
            checkedAt: new Date().toISOString(),
            issueCount: issues.length,
            issues: issues.slice(0, 20),
          },
        },
        { merge: true },
      );
    }

    console.log(
      `ScoringIntegrity nightly: checked=${checked} mismatches=${mismatches}`,
    );
  },
);
