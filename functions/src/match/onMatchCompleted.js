const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { pickMatchHero } = require('../utils/badges');
const { evaluateMatchBadges, applyBadgeAwards } = require('../utils/badgeProgression');
const { updateTournamentStandings } = require('../utils/tournament');
const { fanOutMatchNotification, notifySingleUser } = require('../utils/fanOut');
const {
  buildMatchResultNotification,
  formatPerformanceLines,
  buildHeroOfMatchNotification,
  buildBadgeUnlockNotification,
} = require('../utils/notificationBuilder');
const {
  extractPlayerPerformance,
  enrichHero,
} = require('../utils/notificationPersonalize');
const { resolveAuthUid } = require('../notifications/pushUtils');
const {
  resolveBallType,
  applyPlayerStats,
  applyPlayerHighScores,
  collectPlayerAgg,
  applyTeamResult,
} = require('../utils/stats');
const {
  collectPlayerAggFromEvents,
  deriveInningsList,
} = require('../utils/ballEventStats');

const db = getFirestore();

const BADGE_TITLES = {
  bat_30: { title: '30 in a Match', reason: 'Score 30+ runs in a match.' },
  bat_50: { title: '50 in a Match', reason: 'Score 50+ runs in a match.' },
  bat_75: { title: '75 in a Match', reason: 'Score 75+ runs in a match.' },
  bat_100: { title: '100 in a Match', reason: 'Score 100+ runs in a match.' },
  bat_150: { title: '150 in a Match', reason: 'Score 150+ runs in a match.' },
  bat_200: { title: '200 in a Match', reason: 'Score 200+ runs in a match.' },
  '6s_5': { title: '5 Sixes Match', reason: 'Hit 5+ sixes in a match.' },
  '6s_10': { title: '10 Sixes Match', reason: 'Hit 10+ sixes in a match.' },
  '6s_15': { title: '15 Sixes Match', reason: 'Hit 15+ sixes in a match.' },
  bowl_3: { title: '3 Wicket Haul', reason: 'Take 3+ wickets in a match.' },
  bowl_4: { title: '4 Wicket Haul', reason: 'Take 4+ wickets in a match.' },
  bowl_5: { title: '5 Wicket Haul', reason: 'Take 5+ wickets in a match.' },
  bowl_6: { title: '6 Wicket Haul', reason: 'Take 6+ wickets in a match.' },
  catch_3: { title: '3 Catches Match', reason: 'Take 3+ catches in a match.' },
  catch_5: { title: '5 Catches Match', reason: 'Take 5+ catches in a match.' },
  sr_200: { title: '200+ SR Match', reason: 'Strike rate 200+ in a match.' },
  sr_250: { title: '250+ SR Match', reason: 'Strike rate 250+ in a match.' },
  sr_300: { title: '300+ SR Match', reason: 'Strike rate 300+ in a match.' },
};

async function fetchBallEvents(matchId) {
  const snap = await db
    .collection('matches')
    .doc(matchId)
    .collection('ball_events')
    .orderBy('sequence')
    .get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

exports.onMatchCompleted = onDocumentUpdated(
  'matches/{matchId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    if (before.status === 'completed' || after.status !== 'completed') return;
    if (after.statsProcessed === true) return;

    const matchId = event.params.matchId;
    const ballEvents = await fetchBallEvents(matchId);

    const useEvents = ballEvents.length > 0;
    const playerAgg = useEvents
      ? collectPlayerAggFromEvents(after, ballEvents)
      : collectPlayerAgg(after.innings || []);

    const derivedInnings = useEvents
      ? deriveInningsList(after, ballEvents)
      : after.innings || [];

    const ballType = resolveBallType(after.rules);
    const batch = db.batch();
    applyPlayerStats(batch, db, playerAgg, ballType);

    const winner = after.winnerTeamId;
    const teamA = after.teamAId;
    const teamB = after.teamBId;

    if (teamA && teamB) {
      if (winner) {
        applyTeamResult(batch, db, winner, { won: true, lost: false, tied: false });
        const loser = winner === teamA ? teamB : teamA;
        applyTeamResult(batch, db, loser, { won: false, lost: true, tied: false });
      }
    }

    const matchWithInnings = { ...after, id: matchId, innings: derivedInnings };
    const badgeAwardsByPlayer = evaluateMatchBadges(matchWithInnings);
    const awardedBadgeIds = new Set();

    for (const [playerId, awards] of Object.entries(badgeAwardsByPlayer)) {
      if (!awards.length) continue;
      applyBadgeAwards(batch, db, playerId, awards, FieldValue);
      for (const a of awards) awardedBadgeIds.add(a.badgeId);
    }

    const hero =
      after.matchHero ||
      pickMatchHero({ ...after, innings: derivedInnings });
    const badgeIds = [...awardedBadgeIds];

    batch.update(event.data.after.ref, {
      statsProcessed: true,
      badgeIds,
      matchHero: hero,
      playerOfMatchId: hero?.playerId || after.playerOfMatchId || null,
      statsSource: useEvents ? 'ball_events' : 'innings_cache',
      updatedAt: new Date().toISOString(),
    });

    await batch.commit();
    await applyPlayerHighScores(db, playerAgg, ballType);

    if (after.tournamentId) {
      await updateTournamentStandings(db, after.tournamentId, matchWithInnings);
    }

    const resultType =
      after.targetState?.matchOutcome === 'draw'
        ? 'match_drawn'
        : after.targetState?.matchOutcome === 'abandoned'
          ? 'match_abandoned'
          : 'match_result';

    // Personalized match result fan-out.
    await fanOutMatchNotification(
      db,
      matchId,
      matchWithInnings,
      buildMatchResultNotification(matchWithInnings),
      resultType,
      {},
      {
        mode: 'lifecycle',
        category: 'match',
        tab: 'summary',
        personalize: (ctx, life) => {
          let performanceLines = null;
          if (life.perspective === 'self' && life.actorPlayerId) {
            const perf = extractPlayerPerformance(
              matchWithInnings,
              life.actorPlayerId,
            );
            performanceLines = formatPerformanceLines(
              perf,
              'self',
              life.actorName,
            );
          } else if (life.perspective === 'network' && life.actorPlayerId) {
            const perf = extractPlayerPerformance(
              matchWithInnings,
              life.actorPlayerId,
            );
            performanceLines = formatPerformanceLines(
              perf,
              'network',
              life.actorName,
            );
          }
          return buildMatchResultNotification(
            matchWithInnings,
            life.perspective,
            performanceLines,
          );
        },
      },
    );

    // Hero of the Match — separate notification, subject-priority.
    if (hero?.playerId) {
      const enriched = enrichHero(matchWithInnings, hero);
      await fanOutMatchNotification(
        db,
        matchId,
        matchWithInnings,
        buildHeroOfMatchNotification(matchWithInnings, enriched),
        'hero_of_match',
        {},
        {
          mode: 'subject',
          subjectPlayerIds: [hero.playerId],
          category: 'achievement',
          tab: 'summary',
          skipTopic: true,
          personalize: (ctx, chosen) =>
            buildHeroOfMatchNotification(
              matchWithInnings,
              enriched,
              chosen.perspective,
            ),
        },
      );
    }

    // Badge unlock notifications — only to the earning player.
    for (const [playerId, awards] of Object.entries(badgeAwardsByPlayer)) {
      if (!awards.length) continue;
      const uid = await resolveAuthUid(db, playerId);
      if (!uid) continue;
      for (const award of awards) {
        const meta = BADGE_TITLES[award.badgeId] || {
          title: award.badgeId,
          reason: award.performanceSnapshot || 'New badge unlocked.',
        };
        const reason =
          award.performanceSnapshot ||
          meta.reason ||
          'New badge unlocked.';
        await notifySingleUser(
          db,
          uid,
          buildBadgeUnlockNotification(meta.title, reason),
          'badge_unlock',
          {
            matchId,
            playerId,
            category: 'badge',
            tab: 'badges',
            requestId: award.badgeId,
          },
        );
      }
    }

    console.log(
      `Processed match ${matchId}: ${badgeIds.length} badge awards, stats from ${useEvents ? 'ball_events' : 'innings'}`,
    );
  },
);
