const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { fanOutMatchNotification } = require('../utils/fanOut');
const { refreshFantasyForMatch } = require('../fantasy/refreshFantasyForMatch');
const {
  buildWicketNotification,
  buildBoundaryNotification,
  buildTeamMilestoneNotification,
  buildPlayerMilestoneNotification,
} = require('../utils/notificationBuilder');
const { currentInnings, ballsPerOver } = require('../utils/matchFormat');

const db = getFirestore();

const TEAM_MILESTONES = [50, 100, 150, 200, 250, 300];

async function fetchMatch(matchId) {
  const snap = await db.collection('matches').doc(matchId).get();
  return snap.exists ? snap.data() : null;
}

function detectTeamMilestone(prevRuns, newRuns) {
  for (const m of TEAM_MILESTONES) {
    if (prevRuns < m && newRuns >= m) return m;
  }
  return null;
}

function detectPlayerMilestone(prevRuns, newRuns) {
  for (const m of [50, 100, 150, 200]) {
    if (prevRuns < m && newRuns >= m) return m;
  }
  return null;
}

/**
 * Push enriched notifications for wickets, boundaries, and milestones.
 */
exports.onBallEventCreated = onDocumentCreated(
  'matches/{matchId}/ball_events/{eventId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const matchId = event.params.matchId;
    const eventId = event.params.eventId;
    const type = data.eventType;
    const runs = data.runs || 0;

    const match = await fetchMatch(matchId);
    if (!match) return;

    let title = null;
    let highlightTag = null;
    let body = data.commentary || '';
    let notifType = null;
    let built = null;

    if (type === 'wicket') {
      highlightTag = 'wicket';
      built = buildWicketNotification(match, data);
      title = built.title;
      body = built.body;
      notifType = 'wicket';
    } else if (runs >= 6) {
      highlightTag = 'six';
      built = buildBoundaryNotification(match, data, 'six');
      title = built.title;
      body = built.body;
      notifType = 'six';
    } else if (runs === 4) {
      highlightTag = 'four';
      built = buildBoundaryNotification(match, data, 'four');
      title = built.title;
      body = built.body;
      notifType = 'four';
    }

    if (title) {
      await db
        .collection('matches')
        .doc(matchId)
        .collection('highlights')
        .doc(eventId)
        .set({
          eventId,
          matchId,
          highlightTag,
          eventType: type,
          runs,
          commentary: body,
          inningsNumber: data.inningsNumber || 1,
          overNumber: data.overNumber || 0,
          ballInOver: data.ballInOver || 0,
          sequence: data.sequence || 0,
          timestamp: data.timestamp || new Date().toISOString(),
          createdAt: FieldValue.serverTimestamp(),
        });

      await fanOutMatchNotification(db, matchId, match, built, notifType, {
        eventType: type,
        sequence: String(data.sequence || ''),
      });
    }

    const inn = currentInnings(match);
    if (inn) {
      const teamRuns = inn.totalRuns || 0;
      const prevTeamRuns = Math.max(0, teamRuns - runs);
      const milestone = detectTeamMilestone(prevTeamRuns, teamRuns);
      if (milestone) {
        const mBuilt = buildTeamMilestoneNotification(match, milestone, inn);
        await fanOutMatchNotification(
          db,
          matchId,
          match,
          mBuilt,
          'team_milestone',
        );
      }

      if (data.strikerId) {
        const batsman = (inn.batsmen || []).find(
          (b) => b.playerId === data.strikerId,
        );
        if (batsman) {
          const currentRuns = batsman.runs || 0;
          const prevRuns = Math.max(0, currentRuns - (data.batsmanRuns || 0));
          const playerMilestone = detectPlayerMilestone(prevRuns, currentRuns);
          if (playerMilestone) {
            const name =
              data.lineupStrikerName ||
              batsman.playerName ||
              data.strikerAfterBall ||
              'Batsman';
            const balls = batsman.ballsFaced || 0;
            const pBuilt = buildPlayerMilestoneNotification(
              match,
              name,
              playerMilestone,
              balls,
              inn,
            );
            await fanOutMatchNotification(
              db,
              matchId,
              match,
              pBuilt,
              'player_milestone',
            );
          }
        }
      }
    }

    try {
      await refreshFantasyForMatch(matchId);
    } catch (err) {
      console.error('fantasy refresh failed', matchId, err);
    }
  },
);
