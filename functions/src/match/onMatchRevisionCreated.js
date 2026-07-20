const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const { fanOutMatchNotification } = require('../utils/fanOut');
const {
  buildTargetRevisionNotification,
  buildDlsNotification,
} = require('../utils/notificationBuilder');

const db = getFirestore();

exports.onMatchRevisionCreated = onDocumentCreated(
  'matches/{matchId}/matchRevisions/{revisionId}',
  async (event) => {
    const revision = event.data?.data();
    if (!revision) return;

    const matchId = event.params.matchId;
    const matchSnap = await db.collection('matches').doc(matchId).get();
    if (!matchSnap.exists) return;
    const match = matchSnap.data();

    const type = (revision.type || '').toLowerCase();
    let built;
    let notifType;

    if (type === 'dls') {
      built = buildDlsNotification(match, revision);
      notifType = 'dls_applied';
    } else if (type === 'manual' || revision.newTarget != null) {
      built = buildTargetRevisionNotification(match, revision);
      notifType = 'target_revised';
    } else if (revision.penaltyRuns) {
      built = buildTargetRevisionNotification(match, revision);
      notifType = 'penalty_runs';
    } else {
      return;
    }

    await fanOutMatchNotification(db, matchId, match, built, notifType, {}, {
      category: 'match',
      tab: 'live',
    });
  },
);
