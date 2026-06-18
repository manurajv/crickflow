const { getFirestore } = require('firebase-admin/firestore');
const { notifyMatchTopic, createUserNotification } = require('./messaging');
const { sendPushToUser } = require('../notifications/pushUtils');
const { resolveMatchRecipients, shouldNotifyUser } = require('./recipients');

/**
 * Fan out in-app + FCM notifications to scorers, team members, and followers.
 */
async function fanOutMatchNotification(
  db,
  matchId,
  match,
  { title, body },
  type,
  extraData = {},
) {
  const matchWithId = { ...match, id: matchId };
  const { recipients, teamIds } = await resolveMatchRecipients(
    db,
    matchId,
    matchWithId,
  );

  const data = {
    matchId,
    type: type || 'match_update',
    ...extraData,
  };

  await notifyMatchTopic(matchId, title, body.split('\n')[0], data);

  const tasks = [];
  for (const [userId, sources] of recipients.entries()) {
    tasks.push(
      (async () => {
        const eligible = await shouldNotifyUser(db, userId, sources, teamIds);
        if (!eligible) return;

        await createUserNotification(db, userId, {
          title,
          body,
          matchId,
          type: type || 'match_update',
        });

        await sendPushToUser(db, userId, {
          title,
          body,
          data,
        });
      })(),
    );
  }

  await Promise.allSettled(tasks);
}

module.exports = { fanOutMatchNotification };
