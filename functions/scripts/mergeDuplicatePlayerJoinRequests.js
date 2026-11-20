/**
 * One-off: merge existing pending/historical duplicate playerJoin approvals
 * for the same player + team, keeping the newest. Does not delete docs;
 * older copies are marked status=merged. Does not touch other records.
 *
 * Run from a repo checkout with Admin credentials:
 *   node functions/scripts/mergeDuplicatePlayerJoinRequests.js
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const playerJoin = require('../src/series/playerJoinRequest');

const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || 'crickflow-b06bc';

function groupKey(doc) {
  const userId = doc.requestedBy || (doc.metadata && doc.metadata.userId) || '';
  return `${doc.seriesId}::${doc.clubId}::${userId}`;
}

async function mergeDuplicatePlayerJoinRequests(firestore, { nowIso } = {}) {
  const snap = await firestore.collection('series_approvals')
    .where('targetType', '==', 'playerJoin')
    .get();
  const groups = new Map();
  for (const d of snap.docs) {
    const data = { id: d.id, ...d.data() };
    if (!data.seriesId || !data.clubId) continue;
    const key = groupKey(data);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(data);
  }
  const merged = [];
  const ts = nowIso || new Date().toISOString();
  for (const [key, docs] of groups) {
    const pendingOrOpen = docs.filter((d) => d.status === 'pending' || d.status === 'merged');
    const plan = playerJoin.mergeDuplicateJoinPlan(docs);
    if (!plan.keep || plan.duplicates.length === 0) continue;
    // Only rewrite older pending (or already-unmerged) copies; leave
    // historically approved/rejected unique records unless they share a
    // pending twin.
    const toClose = plan.duplicates.filter((d) => d.status === 'pending');
    if (toClose.length === 0 && docs.filter((d) => d.status === 'pending').length <= 1) {
      continue;
    }
    const targets = toClose.length ? toClose : plan.duplicates.filter((d) => d.id !== plan.keep.id && d.status === 'pending');
    for (const dup of targets) {
      const payload = {
        status: 'merged',
        reviewedAt: ts,
        reason: 'Combined with a newer request from the same player for this team',
        metadata: {
          ...(dup.metadata || {}),
          mergedIntoApproval: plan.keep.id,
        },
      };
      const root = firestore.collection('series_approvals').doc(dup.id);
      const nested = firestore.collection('series').doc(dup.seriesId)
        .collection('approvals').doc(dup.id);
      const batch = firestore.batch();
      batch.set(root, payload, { merge: true });
      batch.set(nested, payload, { merge: true });
      await batch.commit();
      merged.push({
        seriesId: dup.seriesId,
        clubId: dup.clubId,
        playerUserId: dup.requestedBy,
        keptApprovalId: plan.keep.id,
        mergedApprovalId: dup.id,
        keptSubmittedAt: dup && plan.keep.submittedAt || plan.keep.requestedAt || null,
        mergedSubmittedAt: dup.submittedAt || dup.requestedAt || null,
        group: key,
      });
    }
  }
  return { scanned: snap.size, groups: groups.size, merged };
}

async function main() {
  initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const result = await mergeDuplicatePlayerJoinRequests(getFirestore());
  console.log(JSON.stringify(result, null, 2));
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}

module.exports = { mergeDuplicatePlayerJoinRequests };
