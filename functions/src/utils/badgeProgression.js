/**
 * Badge progression — highest eligible only per match, no cascade unlocks.
 * Mirrors lib/domain/services/player_badge_progression_service.dart
 */

const RUNS_TIERS = [
  ['bat_30', 30],
  ['bat_50', 50],
  ['bat_75', 75],
  ['bat_100', 100],
  ['bat_150', 150],
  ['bat_200', 200],
];

const SIXES_TIERS = [
  ['6s_5', 5],
  ['6s_10', 10],
  ['6s_15', 15],
];

const WICKETS_TIERS = [
  ['bowl_3', 3],
  ['bowl_4', 4],
  ['bowl_5', 5],
  ['bowl_6', 6],
];

const CATCHES_TIERS = [
  ['catch_3', 3],
  ['catch_5', 5],
];

const SR_TIERS = [
  ['sr_200', 200],
  ['sr_250', 250],
  ['sr_300', 300],
];

function qualifiesForSrBadge(runs, balls) {
  return balls >= 6 || runs > 20;
}

function strikeRate(runs, balls) {
  return balls > 0 ? (runs / balls) * 100 : 0;
}

function highestTier(tiers, value) {
  let badgeId = null;
  for (const tier of tiers) {
    if (value >= tier[1]) badgeId = tier[0];
  }
  return badgeId;
}

function highestSrTier(sr, runs, balls) {
  if (!qualifiesForSrBadge(runs, balls)) return null;
  let badgeId = null;
  for (const [id, srMin] of SR_TIERS) {
    if (sr >= srMin) badgeId = id;
  }
  return badgeId;
}

function extractMatchPerformance(match, playerId) {
  let runs = 0;
  let balls = 0;
  let sixes = 0;
  let wickets = 0;
  let catches = 0;
  let bestSr = 0;
  let bestSrRuns = 0;
  let bestSrBalls = 0;

  for (const inn of match.innings || []) {
    for (const b of inn.batsmen || []) {
      if (b.playerId !== playerId) continue;
      runs += b.runs || 0;
      balls += b.balls || 0;
      sixes += b.sixes || 0;
      if ((b.balls || 0) > 0) {
        const runs = b.runs || 0;
        const balls = b.balls || 0;
        if (!qualifiesForSrBadge(runs, balls)) continue;
        const sr = strikeRate(runs, balls);
        if (sr >= bestSr) {
          bestSr = sr;
          bestSrRuns = runs;
          bestSrBalls = balls;
        }
      }
    }
    for (const b of inn.bowlers || []) {
      if (b.playerId === playerId) wickets += b.wickets || 0;
    }
    for (const f of inn.fielders || []) {
      if (f.playerId === playerId) catches += f.catches || 0;
    }
  }

  return { runs, balls, sixes, wickets, catches, bestSr, bestSrRuns, bestSrBalls };
}

function awardsForMatch(match, playerId) {
  const perf = extractMatchPerformance(match, playerId);
  const achievedAt =
    match.completedAt || match.scheduledAt || new Date().toISOString();
  const awards = [];

  const runsBadge = highestTier(RUNS_TIERS, perf.runs);
  if (runsBadge) {
    awards.push({
      badgeId: runsBadge,
      matchId: match.id || '',
      achievedAt,
      performanceSnapshot: `${perf.runs}${perf.balls > 0 ? ` (${perf.balls})` : ''}`,
      matchTitle: match.title || '',
    });
  }

  const sixesBadge = highestTier(SIXES_TIERS, perf.sixes);
  if (sixesBadge) {
    awards.push({
      badgeId: sixesBadge,
      matchId: match.id || '',
      achievedAt,
      performanceSnapshot: `${perf.sixes} sixes`,
      matchTitle: match.title || '',
    });
  }

  const wktsBadge = highestTier(WICKETS_TIERS, perf.wickets);
  if (wktsBadge) {
    awards.push({
      badgeId: wktsBadge,
      matchId: match.id || '',
      achievedAt,
      performanceSnapshot: `${perf.wickets} wickets`,
      matchTitle: match.title || '',
    });
  }

  const catchBadge = highestTier(CATCHES_TIERS, perf.catches);
  if (catchBadge) {
    awards.push({
      badgeId: catchBadge,
      matchId: match.id || '',
      achievedAt,
      performanceSnapshot: `${perf.catches} catches`,
      matchTitle: match.title || '',
    });
  }

  const srBadge = highestSrTier(perf.bestSr, perf.bestSrRuns, perf.bestSrBalls);
  if (srBadge) {
    awards.push({
      badgeId: srBadge,
      matchId: match.id || '',
      achievedAt,
      performanceSnapshot: `${Math.round(perf.bestSr)} SR (${perf.bestSrRuns}/${perf.bestSrBalls})`,
      matchTitle: match.title || '',
    });
  }

  return awards;
}

function collectPlayerIds(match) {
  const ids = new Set();
  for (const inn of match.innings || []) {
    for (const b of inn.batsmen || []) if (b.playerId) ids.add(b.playerId);
    for (const b of inn.bowlers || []) if (b.playerId) ids.add(b.playerId);
    for (const f of inn.fielders || []) if (f.playerId) ids.add(f.playerId);
  }
  return [...ids];
}

/**
 * Evaluate match badges for all players — returns map playerId -> awards[].
 */
function evaluateMatchBadges(match) {
  const byPlayer = {};
  for (const playerId of collectPlayerIds(match)) {
    byPlayer[playerId] = awardsForMatch(match, playerId);
  }
  return byPlayer;
}

/**
 * Apply awards to Firestore batch: players/{playerId}/badge_progress/{badgeId}
 * Repeatable badges store unlockCount + achievementHistory.
 * One-time badges store unlocked + unlockedAt (no unlockCount).
 */
function applyBadgeAwards(batch, db, playerId, awards, FieldValue) {
  for (const award of awards) {
    const ref = db
      .collection('players')
      .doc(playerId)
      .collection('badge_progress')
      .doc(award.badgeId);

    if (award.oneTime) {
      batch.set(
        ref,
        {
          badgeId: award.badgeId,
          repeatability: 'oneTime',
          unlocked: true,
          unlockedAt: award.achievedAt,
          unlockedMatchId: award.matchId,
          performanceSnapshot: award.performanceSnapshot,
          unlockMatchTitle: award.matchTitle,
        },
        { merge: true },
      );
      continue;
    }

    const historyEntry = {
      matchId: award.matchId,
      achievedAt: award.achievedAt,
      performanceSnapshot: award.performanceSnapshot,
      matchTitle: award.matchTitle,
    };

    batch.set(
      ref,
      {
        badgeId: award.badgeId,
        repeatability: 'repeatable',
        unlockCount: FieldValue.increment(1),
        lastAchievedAt: award.achievedAt,
        achievementHistory: FieldValue.arrayUnion(historyEntry),
      },
      { merge: true },
    );
  }
}

module.exports = {
  evaluateMatchBadges,
  applyBadgeAwards,
  awardsForMatch,
};
