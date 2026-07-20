const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore } = require('firebase-admin/firestore');
const { sendPushToUser } = require('./pushUtils');

/** Types that already send FCM inside fanOut / notifySingleUser. */
const PUSH_ALREADY_SENT_TYPES = new Set([
  'match_started',
  'first_innings_complete',
  'second_innings_started',
  'wicket',
  'hat_trick',
  'team_milestone',
  'player_milestone',
  'bowling_milestone',
  'match_result',
  'match_drawn',
  'match_abandoned',
  'match_break_started',
  'match_break_ended',
  'dls_applied',
  'target_revised',
  'penalty_runs',
  'stream_started',
  'stream_ended',
  'hero_of_match',
  'badge_unlock',
  'match_update',
]);

/**
 * Sends FCM push for in-app notification docs (except join requests — those
 * are handled by onTeamJoinRequestCreated to avoid duplicate pushes).
 * Also skips docs that already pushed via fanOut (pushSent / match types).
 */
exports.onNotificationCreated = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    if (data.type === 'team_join_request' || data.type === 'team_invitation') {
      return;
    }

    if (data.pushSent === true) return;
    if (data.type && PUSH_ALREADY_SENT_TYPES.has(data.type)) return;

    const userId = data.userId;
    if (!userId) return;

    const db = getFirestore();
    const title =
      data.matchTitle || data.title || 'CrickFlow';
    const body = data.body || data.message || '';

    await sendPushToUser(db, userId, {
      title,
      body,
      data: {
        type: data.type || '',
        teamId: data.teamId || '',
        matchId: data.matchId || '',
        playerId: data.playerId || '',
        tournamentId: data.tournamentId || '',
        requestId: data.requestId || '',
        category: data.category || '',
        tab: data.tab || '',
      },
    });
  },
);
