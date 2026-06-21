const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

function socialStatsRef(db, userId) {
  return db.collection('users').doc(userId).collection('social').doc('stats');
}

function applyFollowDelta(batch, db, userId, field, delta) {
  if (!userId || delta === 0) return;
  const inc = FieldValue.increment(delta);
  const now = FieldValue.serverTimestamp();
  batch.set(
    db.collection('users').doc(userId),
    {
      [`socialStats.${field}`]: inc,
      updatedAt: new Date().toISOString(),
    },
    { merge: true },
  );
  batch.set(
    socialStatsRef(db, userId),
    {
      [field]: inc,
      updatedAt: now,
    },
    { merge: true },
  );
}

/**
 * Mirrors follow counts from playerFollows into users/{uid}.socialStats
 * and users/{uid}/social/stats for indexed discovery + realtime UI.
 */
exports.onPlayerFollowWritten = onDocumentWritten(
  'playerFollows/{followId}',
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after && !before) return;

    const followedId = (after || before).followedUserId;
    const followerId = (after || before).followerUserId;
    if (!followedId || !followerId) return;

    const delta = after && !before ? 1 : !after && before ? -1 : 0;
    if (delta === 0) return;

    const db = getFirestore();
    const batch = db.batch();
    applyFollowDelta(batch, db, followedId, 'followersCount', delta);
    applyFollowDelta(batch, db, followerId, 'followingCount', delta);
    await batch.commit();
  },
);

/**
 * Mirrors profile view counts into the user doc and social/stats subdoc.
 */
exports.onProfileViewWritten = onDocumentWritten(
  'users/{userId}/profileViews/{viewerId}',
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;

    const userId = event.params.userId;
    const db = getFirestore();
    const inc = FieldValue.increment(1);
    const now = FieldValue.serverTimestamp();
    const batch = db.batch();
    batch.set(
      db.collection('users').doc(userId),
      {
        'socialStats.profileViewsCount': inc,
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
    batch.set(
      socialStatsRef(db, userId),
      {
        profileViewsCount: inc,
        updatedAt: now,
      },
      { merge: true },
    );
    await batch.commit();
  },
);
