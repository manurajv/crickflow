const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');

/**
 * Notifies platform admins when a player reports an unauthorized roster add.
 * Configure admins in Firestore: app_meta/platform_admins { uids: ["..."] }
 */
exports.onTeamRosterReportCreated = onDocumentCreated(
  'team_roster_reports/{reportId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const db = getFirestore();
    const reportId = event.params.reportId;
    const adminsSnap = await db.doc('app_meta/platform_admins').get();
    const uids = adminsSnap.exists ? adminsSnap.data()?.uids || [] : [];

    if (!Array.isArray(uids) || uids.length === 0) {
      console.warn(
        'team_roster_reports: no platform admins configured at app_meta/platform_admins',
      );
      return;
    }

    const title = 'Unauthorized roster report';
    const body =
      `${data.reporterName || 'A player'} reported being added to ` +
      `${data.teamName || 'a team'} without consent.`;

    const now = new Date().toISOString();
    const batch = db.batch();

    for (const uid of uids) {
      if (!uid || typeof uid !== 'string') continue;
      const ref = db.collection('notifications').doc();
      batch.set(ref, {
        userId: uid,
        title,
        body,
        message: body,
        type: 'admin_roster_report',
        teamId: data.teamId || '',
        playerId: data.playerId || '',
        reportId,
        read: false,
        isRead: false,
        createdAt: now,
      });
    }

    await batch.commit();
  },
);
