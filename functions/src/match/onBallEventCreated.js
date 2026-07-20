const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { fanOutMatchNotification } = require('../utils/fanOut');
const { refreshFantasyForMatch } = require('../fantasy/refreshFantasyForMatch');
const {
  buildWicketNotification,
  buildHatTrickNotification,
  buildTeamMilestoneNotification,
  buildPlayerMilestoneNotification,
  buildBowlingMilestoneNotification,
} = require('../utils/notificationBuilder');
const { currentInnings } = require('../utils/matchFormat');

const db = getFirestore();

const TEAM_MILESTONES = [50, 100, 150, 200];
const BATTING_MILESTONES = [30, 50, 100, 150, 200];
const BOWLING_MILESTONES = [3, 4, 5];

async function fetchMatch(matchId) {
  const snap = await db.collection('matches').doc(matchId).get();
  return snap.exists ? snap.data() : null;
}

function detectMilestone(prev, next, thresholds) {
  for (const m of thresholds) {
    if (prev < m && next >= m) return m;
  }
  return null;
}

/**
 * Hat-trick: same bowler took wickets on the last 3 consecutive legal balls.
 */
async function detectHatTrick(matchId, event) {
  const bowlerId = event.bowlerId;
  if (!bowlerId || event.eventType !== 'wicket') return false;

  const snap = await db
    .collection('matches')
    .doc(matchId)
    .collection('ball_events')
    .orderBy('sequence', 'desc')
    .limit(24)
    .get();

  const legal = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    if (d.isWide || d.isNoBall || d.extrasType === 'wide' || d.extrasType === 'noBall') {
      continue;
    }
    // Count legal deliveries only.
    if (d.isLegal === false) continue;
    legal.push(d);
    if (legal.length >= 3) break;
  }

  if (legal.length < 3) return false;
  return legal
    .slice(0, 3)
    .every((d) => d.eventType === 'wicket' && d.bowlerId === bowlerId);
}

/**
 * Push enriched notifications for wickets and milestones.
 * Boundaries (four/six) are intentionally not notified.
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

    // Highlights for wickets / boundaries (no push for boundaries).
    let highlightTag = null;
    if (type === 'wicket') {
      highlightTag = 'wicket';
    } else if (data.boundaryType === 'six' || runs >= 6) {
      highlightTag = 'six';
    } else if (data.boundaryType === 'four' || runs === 4) {
      highlightTag = 'four';
    }

    if (highlightTag) {
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
          commentary: data.commentary || '',
          inningsNumber: data.inningsNumber || 1,
          overNumber: data.overNumber || 0,
          ballInOver: data.ballInOver || 0,
          sequence: data.sequence || 0,
          timestamp: data.timestamp || new Date().toISOString(),
          createdAt: FieldValue.serverTimestamp(),
        });
    }

    if (type === 'wicket') {
      const built = buildWicketNotification(match, data);
      await fanOutMatchNotification(db, matchId, match, built, 'wicket', {
        eventType: type,
        sequence: String(data.sequence || ''),
      }, { category: 'live_match', tab: 'live' });

      try {
        const isHatTrick = await detectHatTrick(matchId, data);
        if (isHatTrick) {
          const bowlerName =
            data.lineupBowlerName ||
            data.bowlerName ||
            'Bowler';
          const hatBuilt = buildHatTrickNotification(match, bowlerName);
          await fanOutMatchNotification(
            db,
            matchId,
            match,
            hatBuilt,
            'hat_trick',
            { eventType: type, sequence: String(data.sequence || '') },
            {
              category: 'live_match',
              tab: 'live',
            },
          );
        }
      } catch (err) {
        console.warn('hat-trick detect failed', err.message);
      }
    }

    const inn = currentInnings(match);
    if (inn) {
      const teamRuns = inn.totalRuns || 0;
      const prevTeamRuns = Math.max(0, teamRuns - runs);
      const milestone = detectMilestone(prevTeamRuns, teamRuns, TEAM_MILESTONES);
      if (milestone) {
        const mBuilt = buildTeamMilestoneNotification(match, milestone, inn);
        await fanOutMatchNotification(
          db,
          matchId,
          match,
          mBuilt,
          'team_milestone',
          {},
          { category: 'live_match', tab: 'live' },
        );
      }

      if (data.strikerId) {
        const batsman = (inn.batsmen || []).find(
          (b) => b.playerId === data.strikerId,
        );
        if (batsman) {
          const currentRuns = batsman.runs || 0;
          const prevRuns = Math.max(0, currentRuns - (data.batsmanRuns || 0));
          const playerMilestone = detectMilestone(
            prevRuns,
            currentRuns,
            BATTING_MILESTONES,
          );
          if (playerMilestone) {
            const name =
              data.lineupStrikerName ||
              batsman.playerName ||
              data.strikerAfterBall ||
              'Batsman';
            const balls = batsman.ballsFaced || batsman.balls || 0;
            await fanOutMatchNotification(
              db,
              matchId,
              match,
              buildPlayerMilestoneNotification(
                match,
                name,
                playerMilestone,
                balls,
              ),
              'player_milestone',
              {},
              {
                mode: 'subject',
                subjectPlayerIds: [data.strikerId],
                category: 'live_match',
                tab: 'live',
                personalize: (ctx, chosen) =>
                  buildPlayerMilestoneNotification(
                    match,
                    name,
                    playerMilestone,
                    balls,
                    chosen.perspective,
                  ),
              },
            );
          }
        }
      }

      if (type === 'wicket' && data.bowlerId) {
        const bowler = (inn.bowlers || []).find(
          (b) => b.playerId === data.bowlerId,
        );
        if (bowler) {
          const currentWkts = bowler.wickets || 0;
          const prevWkts = Math.max(0, currentWkts - 1);
          const bowlMilestone = detectMilestone(
            prevWkts,
            currentWkts,
            BOWLING_MILESTONES,
          );
          if (bowlMilestone) {
            const name =
              data.lineupBowlerName ||
              bowler.playerName ||
              data.bowlerName ||
              'Bowler';
            const conceded = bowler.runsConceded || bowler.runs || 0;
            await fanOutMatchNotification(
              db,
              matchId,
              match,
              buildBowlingMilestoneNotification(
                match,
                name,
                bowlMilestone,
                conceded,
              ),
              'bowling_milestone',
              {},
              {
                mode: 'subject',
                subjectPlayerIds: [data.bowlerId],
                category: 'live_match',
                tab: 'live',
                personalize: (ctx, chosen) =>
                  buildBowlingMilestoneNotification(
                    match,
                    name,
                    bowlMilestone,
                    conceded,
                    chosen.perspective,
                  ),
              },
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
