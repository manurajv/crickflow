const { resolveAuthUid } = require('../notifications/pushUtils');

/**
 * Resolve notification recipients for a match event.
 * Returns Map<authUid, { viaScorer, viaTeam, viaFollower }>
 */
async function resolveMatchRecipients(db, matchId, match) {
  const recipients = new Map();

  function add(uid, source) {
    if (!uid || uid.length === 0) return;
    const existing = recipients.get(uid) || {
      viaScorer: false,
      viaTeam: false,
      viaFollower: false,
    };
    existing[source] = true;
    recipients.set(uid, existing);
  }

  if (match.scorer1UserId) add(match.scorer1UserId, 'viaScorer');
  if (match.scorer2UserId) add(match.scorer2UserId, 'viaScorer');
  if (match.createdBy) add(match.createdBy, 'viaScorer');

  const teamIds = [match.teamAId, match.teamBId].filter(Boolean);
  for (const teamId of teamIds) {
    const teamSnap = await db.collection('teams').doc(teamId).get();
    if (!teamSnap.exists) continue;
    const team = teamSnap.data();
    if (team.createdBy) add(team.createdBy, 'viaTeam');
    for (const pid of team.playerIds || []) {
      const uid = await resolveAuthUid(db, pid);
      if (uid) add(uid, 'viaTeam');
    }
  }

  const followersSnap = await db
    .collection('matchFollowers')
    .where('matchId', '==', matchId)
    .get();

  for (const doc of followersSnap.docs) {
    const uid = doc.data().userId;
    if (uid) add(uid, 'viaFollower');
  }

  return { recipients, teamIds };
}

async function getUserNotificationPrefs(db, userId) {
  const snap = await db.collection('users').doc(userId).get();
  if (!snap.exists) {
    return {
      receiveTeamMatchNotifications: true,
      receiveFollowerNotifications: true,
    };
  }
  const prefs = snap.data().notificationPrefs || {};
  return {
    receiveTeamMatchNotifications:
      prefs.receiveTeamMatchNotifications !== false,
    receiveFollowerNotifications:
      prefs.receiveFollowerNotifications !== false,
  };
}

async function isTeamNotificationEnabled(db, userId, teamId) {
  const prefSnap = await db
    .collection('users')
    .doc(userId)
    .collection('teamNotificationPrefs')
    .doc(teamId)
    .get();
  if (!prefSnap.exists) return true;
  return prefSnap.data()?.enabled !== false;
}

async function userMemberTeamIdsInMatch(db, userId, teamIds) {
  const memberOf = [];
  for (const teamId of teamIds) {
    const teamSnap = await db.collection('teams').doc(teamId).get();
    if (!teamSnap.exists) continue;
    const team = teamSnap.data();
    if (team.createdBy === userId) {
      memberOf.push(teamId);
      continue;
    }
    for (const pid of team.playerIds || []) {
      const uid = await resolveAuthUid(db, pid);
      if (uid === userId) {
        memberOf.push(teamId);
        break;
      }
    }
  }
  return memberOf;
}

async function shouldNotifyUser(db, userId, sources, teamIds) {
  if (sources.viaScorer) return true;

  const prefs = await getUserNotificationPrefs(db, userId);

  if (sources.viaFollower && prefs.receiveFollowerNotifications) {
    return true;
  }

  if (sources.viaTeam && prefs.receiveTeamMatchNotifications) {
    const memberTeams = await userMemberTeamIdsInMatch(db, userId, teamIds);
    for (const tid of memberTeams) {
      const enabled = await isTeamNotificationEnabled(db, userId, tid);
      if (enabled) return true;
    }
  }

  return false;
}

module.exports = {
  resolveMatchRecipients,
  shouldNotifyUser,
  getUserNotificationPrefs,
  isTeamNotificationEnabled,
};
