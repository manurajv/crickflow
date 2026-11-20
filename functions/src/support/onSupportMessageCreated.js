const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const { createUserNotification } = require('../utils/messaging');

/**
 * When staff reply in a CrickFlow Help thread, write an in-app notification
 * so onNotificationCreated can push to the user. Users cannot create the
 * `support_reply` notification type from the client.
 */
exports.onSupportMessageCreated = onDocumentCreated(
  'support_threads/{threadId}/messages/{messageId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    if (data.senderRole !== 'staff') return;

    const threadId = event.params.threadId;
    if (!threadId) return;

    const db = getFirestore();
    const threadSnap = await db.collection('support_threads').doc(threadId).get();
    const thread = threadSnap.data() || {};
    const userId = thread.userId || threadId;
    if (!userId || userId === data.senderId) return;

    const preview = String(data.text || '').trim().slice(0, 180);
    const staffName = String(data.senderName || '').trim() || 'CrickFlow staff';
    await createUserNotification(db, userId, {
      title: 'New reply from CrickFlow',
      body: preview ? `${staffName}: ${preview}` : `${staffName} replied to your help request.`,
      type: 'support_reply',
      category: 'support',
      requestId: threadId,
    });
  },
);
