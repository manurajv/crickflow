const { onSchedule } = require('firebase-functions/v2/scheduler');
const { getFirestore } = require('firebase-admin/firestore');
const {
  isTournamentLookingPostExpired,
} = require('../utils/tournamentLookingPostExpiry');

const db = getFirestore();

/**
 * Daily cleanup: remove draft-tournament looking posts (teams / officials)
 * once the tournament has started or the end date has passed.
 */
exports.cleanupExpiredTournamentLookingPosts = onSchedule(
  {
    schedule: 'every day 04:15',
    timeZone: 'Asia/Colombo',
  },
  async () => {
    const snap = await db
      .collection('community_posts')
      .where('category', '==', 'tournamentNeed')
      .limit(500)
      .get();

    const now = new Date();
    let deleted = 0;

    for (const doc of snap.docs) {
      const data = doc.data() || {};
      if (!isTournamentLookingPostExpired(data, now)) continue;

      try {
        await _deletePostTree(doc.ref);
        deleted += 1;
      } catch (err) {
        console.warn(
          `cleanupExpiredTournamentLookingPosts: failed ${doc.id}`,
          err,
        );
      }
    }

    console.log(
      `cleanupExpiredTournamentLookingPosts: scanned=${snap.size} deleted=${deleted}`,
    );
  },
);

async function _deletePostTree(postRef) {
  const batchLimit = 400;
  for (const sub of ['likes', 'comments', 'saves']) {
    // eslint-disable-next-line no-await-in-loop
    let more = true;
    while (more) {
      // eslint-disable-next-line no-await-in-loop
      const subSnap = await postRef.collection(sub).limit(batchLimit).get();
      if (subSnap.empty) {
        more = false;
        break;
      }
      const batch = db.batch();
      for (const d of subSnap.docs) {
        batch.delete(d.ref);
      }
      // eslint-disable-next-line no-await-in-loop
      await batch.commit();
      if (subSnap.size < batchLimit) more = false;
    }
  }
  await postRef.delete();
}
