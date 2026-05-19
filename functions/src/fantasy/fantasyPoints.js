/**
 * Dream11-style fantasy points (mirrors lib/domain/services/fantasy_points_service.dart).
 */

const WICKET_POINTS = 25;
const CATCH_POINTS = 8;
const FOUR_BONUS = 1;
const SIX_BONUS = 2;

function rawPlayerPoints(events) {
  const points = {};

  const add = (playerId, value) => {
    if (!playerId || value === 0) return;
    points[playerId] = (points[playerId] || 0) + value;
  };

  for (const e of events) {
    const batsmanRuns = e.batsmanRuns || e.runs || 0;
    if (e.strikerId && batsmanRuns > 0) {
      add(e.strikerId, batsmanRuns);
      if (batsmanRuns === 4) add(e.strikerId, FOUR_BONUS);
      if (batsmanRuns === 6) add(e.strikerId, SIX_BONUS);
    }

    const isWicket =
      e.wicketType ||
      e.eventType === 'wicket' ||
      e.dismissedPlayerId;

    if (isWicket) {
      add(e.bowlerId, WICKET_POINTS);
      add(e.fielderId, CATCH_POINTS);
    }
  }

  return points;
}

function totalForEntry(entry, league, raw) {
  const squad = entry.playerIds || [];
  if (squad.length === 0) return 0;

  const captainMult = league.captainMultiplier || 2;
  const viceMult = league.viceCaptainMultiplier || 1.5;
  let total = 0;

  for (const playerId of squad) {
    let pts = raw[playerId] || 0;
    if (playerId === entry.captainId) pts *= captainMult;
    else if (playerId === entry.viceCaptainId) pts *= viceMult;
    total += pts;
  }

  return Math.round(total * 10) / 10;
}

module.exports = { rawPlayerPoints, totalForEntry };
