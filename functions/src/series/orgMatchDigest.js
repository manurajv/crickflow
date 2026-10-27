/**
 * Per-match digest for org leaderboards (series_match_digests/{matchId}).
 *
 * The org points table and every player ranking category can be computed from
 * the match documents alone EXCEPT the stats that need ball-by-ball replay:
 * fielding credits, dot balls, maidens, fastest fifty / hundred. Web clients
 * cannot afford to read thousands of ball events, so the server replays them
 * once per finished org match and stores this small digest. The app's
 * PlayerRankingsService does the same replay on the device; this file mirrors
 * it exactly (see test/fixtures/org_leaderboard_golden.json, which both
 * runtimes must reproduce).
 *
 * Pure functions only — no Firestore here.
 */

const { fieldersFromEvents } = require('../utils/ballEventStats');

const DIGEST_VERSION = 1;

/** Mirrors lib/data/models/match_rules_model.dart clampBallsPerOver. */
function clampBallsPerOver(value) {
  const n = Number.isFinite(value) ? Math.trunc(value) : 6;
  if (n < 1) return 1;
  if (n > 12) return 12;
  return n;
}

function str(v) {
  return typeof v === 'string' ? v.trim() : '';
}

function eventsForInnings(all, inningsNumber) {
  return all
    .filter((e) => (e.inningsNumber ?? 1) === inningsNumber)
    .sort((a, b) => (a.sequence ?? 0) - (b.sequence ?? 0));
}

/** Mirrors BallEventAggregator._runsAgainstBowler. */
function runsAgainstBowler(e) {
  if (e.eventType === 'bye' || e.eventType === 'legBye') return 0;
  return e.runs || 0;
}

/** Mirrors BallEventAggregator.maidenOversFromEvents. */
function maidenOversFromEvents(events, rules) {
  const byOver = new Map();
  for (const e of events) {
    if (e.countsInOver === false || e.countsToBowler === false) continue;
    const bowlerId = str(e.bowlerId);
    if (!bowlerId) continue;
    const key = `${e.inningsNumber ?? 1}|${e.overNumber ?? 0}`;
    if (!byOver.has(key)) byOver.set(key, []);
    byOver.get(key).push(e);
  }
  const maidens = {};
  const ballsPerOver = clampBallsPerOver(rules?.ballsPerOver ?? 6);
  for (const overEvents of byOver.values()) {
    const legal = overEvents.filter((e) => e.isLegalDelivery !== false).length;
    if (legal < ballsPerOver) continue;
    const bowlers = new Set(overEvents.map((e) => str(e.bowlerId)).filter(Boolean));
    if (bowlers.size !== 1) continue; // a split over is no maiden for anyone
    const conceded = overEvents.reduce((t, e) => t + runsAgainstBowler(e), 0);
    if (conceded === 0) {
      const [id] = [...bowlers];
      maidens[id] = (maidens[id] || 0) + 1;
    }
  }
  return maidens;
}

function emptyPlayer() {
  return {
    catches: 0,
    runOuts: 0,
    stumpings: 0,
    dotBalls: 0,
    maidens: 0,
    fastestFiftyBalls: null,
    fastestHundredBalls: null,
  };
}

/**
 * Mirrors PlayerRankingsService._aggregateReplayEvents for one innings.
 * `ensure(id)` returns the player's digest row.
 */
function aggregateReplayEvents(events, rules, ensure) {
  const batterRuns = {};
  const batterBalls = {};
  for (const e of events) {
    const strikerId = str(e.strikerId);
    if (strikerId) {
      const prev = batterRuns[strikerId] || 0;
      const next = prev + (e.batsmanRuns || 0);
      const balls = (batterBalls[strikerId] || 0) + (e.countsAsBallFaced === true ? 1 : 0);
      batterRuns[strikerId] = next;
      batterBalls[strikerId] = balls;
      const row = ensure(strikerId);
      if (prev < 50 && next >= 50 && balls > 0) {
        if (row.fastestFiftyBalls == null || balls < row.fastestFiftyBalls) {
          row.fastestFiftyBalls = balls;
        }
      }
      if (prev < 100 && next >= 100 && balls > 0) {
        if (row.fastestHundredBalls == null || balls < row.fastestHundredBalls) {
          row.fastestHundredBalls = balls;
        }
      }
    }
    const bowlerId = str(e.bowlerId);
    if (
      bowlerId &&
      e.countsToBowler !== false &&
      e.isLegalDelivery !== false &&
      (e.runs || 0) === 0
    ) {
      ensure(bowlerId).dotBalls += 1;
    }
  }
  for (const [id, n] of Object.entries(maidenOversFromEvents(events, rules))) {
    ensure(id).maidens += n;
  }
}

/**
 * Digest for one finished org match.
 *
 * Fielding comes from the ball events when the match has any, otherwise from
 * the innings' stored fielders (same precedence as the app).
 */
function buildMatchDigest(match, events) {
  const players = {};
  const ensure = (id) => {
    if (!players[id]) players[id] = emptyPlayer();
    return players[id];
  };
  const all = Array.isArray(events) ? events : [];
  const rules = match?.rules || {};

  for (const inn of match?.innings || []) {
    const inningsEvents = eventsForInnings(all, inn.inningsNumber ?? 1);
    if (inningsEvents.length) aggregateReplayEvents(inningsEvents, rules, ensure);
  }

  let fieldingSource = 'innings';
  const credit = (f) => {
    const id = str(f.playerId);
    if (!id) return;
    if (!(f.catches || 0) && !(f.runOuts || 0) && !(f.stumpings || 0)) return;
    const row = ensure(id);
    row.catches += f.catches || 0;
    row.runOuts += f.runOuts || 0;
    row.stumpings += f.stumpings || 0;
  };
  if (all.length) {
    fieldingSource = 'events';
    for (const f of fieldersFromEvents(all)) credit(f);
  } else {
    for (const inn of match?.innings || []) {
      for (const f of inn.fielders || []) credit(f);
    }
  }

  // Players with nothing to report stay out of the digest.
  const kept = {};
  for (const [id, row] of Object.entries(players)) {
    const empty =
      !row.catches && !row.runOuts && !row.stumpings && !row.dotBalls &&
      !row.maidens && row.fastestFiftyBalls == null && row.fastestHundredBalls == null;
    if (!empty) kept[id] = row;
  }
  return { version: DIGEST_VERSION, fieldingSource, players: kept };
}

/** An approved, non-quick org match that is finished. Mirrors countsForOrgStandings. */
function isDigestMatch(match) {
  if (!match || !match.seriesId) return false;
  if (match.seriesOfficialStatus !== 'approved') return false;
  if (match.matchMode === 'quick') return false;
  if (match.status !== 'completed' && match.status !== 'abandoned') return false;
  return Boolean(match.seriesClubAId) && Boolean(match.seriesClubBId);
}

/** Fields that decide whether an existing digest is stale. */
function digestFingerprint(match) {
  return JSON.stringify({
    s: match.status,
    o: match.seriesOfficialStatus,
    a: match.seriesClubAId || null,
    b: match.seriesClubBId || null,
    t: match.tournamentId || null,
    i: match.innings || [],
    r: match.rules || null,
  });
}

module.exports = {
  DIGEST_VERSION,
  buildMatchDigest,
  maidenOversFromEvents,
  isDigestMatch,
  digestFingerprint,
  clampBallsPerOver,
};
