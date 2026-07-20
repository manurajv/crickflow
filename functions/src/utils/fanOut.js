const { notifyMatchTopic, createUserNotification } = require('./messaging');
const { sendPushToUser } = require('../notifications/pushUtils');
const { resolveMatchRecipients, shouldNotifyUser } = require('./recipients');
const {
  resolveMatchPlayers,
  buildRecipientContext,
  resolveSubjectPerspective,
  resolveLifecyclePerspective,
} = require('./notificationPersonalize');

/**
 * Fan out in-app + FCM notifications to scorers, team members, and followers.
 *
 * @param {object} options
 * @param {string[]} [options.subjectPlayerIds] - Player-specific event subjects
 * @param {'lifecycle'|'subject'|'broadcast'} [options.mode]
 * @param {function} [options.personalize] - (ctx, perspectiveInfo) => built notif
 * @param {string} [options.category]
 * @param {string} [options.tab] - Deep-link tab hint (live|summary|…)
 * @param {boolean} [options.skipTopic] - Skip FCM topic broadcast
 */
async function fanOutMatchNotification(
  db,
  matchId,
  match,
  built,
  type,
  extraData = {},
  options = {},
) {
  const matchWithId = { ...match, id: matchId };
  const { recipients, teamIds } = await resolveMatchRecipients(
    db,
    matchId,
    matchWithId,
  );

  const mode = options.mode || 'broadcast';
  const subjectPlayerIds = options.subjectPlayerIds || [];
  const category = options.category || categoryForType(type);

  let matchPlayers = null;
  if (mode !== 'broadcast' || options.personalize) {
    matchPlayers = await resolveMatchPlayers(db, matchWithId);
  }

  const baseBuilt = normalizeBuilt(built, matchWithId);
  const data = {
    matchId,
    type: type || 'match_update',
    category,
    ...(options.tab ? { tab: options.tab } : {}),
    ...extraData,
  };

  // Topic push uses generic copy (followers subscribed via match_{id}).
  if (!options.skipTopic) {
    await notifyMatchTopic(
      matchId,
      baseBuilt.pushTitle || baseBuilt.matchTitle || baseBuilt.title,
      firstLine(baseBuilt.pushBody || baseBuilt.body || baseBuilt.title),
      data,
    );
  }

  const tasks = [];
  for (const [userId, sources] of recipients.entries()) {
    tasks.push(
      (async () => {
        const eligible = await shouldNotifyUser(db, userId, sources, teamIds);
        if (!eligible) return;

        let personalized = baseBuilt;
        let perspective = 'general';

        if (matchPlayers) {
          const ctx = await buildRecipientContext(db, userId, matchPlayers);

          if (mode === 'subject') {
            // Prefer self among subjects; skip network subjects if playing.
            let chosen = null;
            for (const subjectId of subjectPlayerIds) {
              const decision = resolveSubjectPerspective(ctx, subjectId);
              if (decision.send) {
                chosen = { subjectId, ...decision };
                if (decision.perspective === 'self') break;
              }
            }
            if (!chosen) return;
            perspective = chosen.perspective;
            if (typeof options.personalize === 'function') {
              personalized = normalizeBuilt(
                options.personalize(ctx, chosen),
                matchWithId,
              );
            }
          } else if (mode === 'lifecycle' || options.personalize) {
            const life = resolveLifecyclePerspective(ctx);
            perspective = life.perspective;
            if (typeof options.personalize === 'function') {
              personalized = normalizeBuilt(
                options.personalize(ctx, life),
                matchWithId,
              );
            }
          }
        }

        await createUserNotification(db, userId, {
          title: personalized.title,
          body: personalized.body,
          matchTitle: personalized.matchTitle || null,
          matchId,
          type: type || 'match_update',
          category,
          tab: options.tab || null,
          playerId: subjectPlayerIds[0] || null,
          pushSent: true,
          perspective,
        });

        await sendPushToUser(db, userId, {
          title: personalized.pushTitle || personalized.matchTitle || personalized.title,
          body: personalized.pushBody || personalized.body,
          data: {
            ...data,
            ...(subjectPlayerIds[0] ? { playerId: subjectPlayerIds[0] } : {}),
          },
        });
      })(),
    );
  }

  await Promise.allSettled(tasks);
}

/**
 * Create a single-user notification (hero/badge) with optional push.
 */
async function notifySingleUser(db, userId, built, type, extra = {}) {
  if (!userId) return;
  const normalized = normalizeBuilt(built, {});
  await createUserNotification(db, userId, {
    title: normalized.title,
    body: normalized.body,
    matchTitle: normalized.matchTitle || null,
    matchId: extra.matchId || null,
    type,
    category: extra.category || categoryForType(type),
    tab: extra.tab || null,
    playerId: extra.playerId || null,
    pushSent: true,
  });
  await sendPushToUser(db, userId, {
    title: normalized.pushTitle || normalized.title,
    body: normalized.pushBody || normalized.body,
    data: {
      type,
      matchId: extra.matchId || '',
      playerId: extra.playerId || '',
      category: extra.category || categoryForType(type),
      tab: extra.tab || '',
    },
  });
}

function normalizeBuilt(built, match) {
  if (!built) {
    return { title: 'Update', body: '', matchTitle: null };
  }
  const matchTitle =
    built.matchTitle ||
    (match.teamAName && match.teamBName
      ? `${match.teamAName} vs ${match.teamBName}`
      : match.title || null);
  return {
    title: built.title || 'Update',
    body: built.body || '',
    matchTitle,
    pushTitle: built.pushTitle || matchTitle || built.title,
    pushBody: built.pushBody || built.body || built.title,
  };
}

function firstLine(text) {
  if (!text) return '';
  return String(text).split('\n').find((l) => l.trim()) || '';
}

function categoryForType(type) {
  switch (type) {
    case 'match_started':
    case 'first_innings_complete':
    case 'second_innings_started':
    case 'match_result':
    case 'match_drawn':
    case 'match_abandoned':
    case 'match_break_started':
    case 'match_break_ended':
    case 'dls_applied':
    case 'target_revised':
    case 'penalty_runs':
      return 'match';
    case 'wicket':
    case 'hat_trick':
    case 'team_milestone':
    case 'player_milestone':
    case 'bowling_milestone':
      return 'live_match';
    case 'hero_of_match':
      return 'achievement';
    case 'badge_unlock':
      return 'badge';
    case 'stream_started':
    case 'stream_ended':
      return 'streaming';
    default:
      return 'system';
  }
}

module.exports = { fanOutMatchNotification, notifySingleUser, categoryForType };
