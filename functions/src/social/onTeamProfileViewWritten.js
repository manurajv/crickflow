const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

/**
 * Increments teams/{teamId}.profileViewsCount when a profile view is recorded.
 */
exports.onTeamProfileViewWritten = onDocumentWritten(
  'teams/{teamId}/profileViews/{viewerId}',
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return;

    const teamId = event.params.teamId;
    const db = getFirestore();
    await db.collection('teams').doc(teamId).set(
      {
        profileViewsCount: FieldValue.increment(1),
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
  },
);
