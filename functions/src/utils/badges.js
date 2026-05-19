/**
 * Server-side badge evaluation (mirrors client BadgeService).
 */

function evaluateInningsBadges(matchId, innings) {
  const badges = [];
  const now = new Date().toISOString();

  for (const batsman of innings.batsmen || []) {
    if (!batsman.playerId) continue;
    const runs = batsman.runs || 0;
    if (runs >= 100) {
      badges.push(makeBadge({
        id: `century_${batsman.playerId}_${matchId}`,
        title: 'Century!',
        type: 'milestone',
        description: `Scored ${runs} runs`,
        playerId: batsman.playerId,
        matchId,
        earnedAt: now,
      }));
    } else if (runs >= 50) {
      badges.push(makeBadge({
        id: `fifty_${batsman.playerId}_${matchId}`,
        title: 'Half Century',
        type: 'batting',
        description: `Scored ${runs} runs`,
        playerId: batsman.playerId,
        matchId,
        earnedAt: now,
      }));
    }
  }

  for (const bowler of innings.bowlers || []) {
    if (!bowler.playerId) continue;
    const wickets = bowler.wickets || 0;
    if (wickets >= 5) {
      badges.push(makeBadge({
        id: `five_${bowler.playerId}_${matchId}`,
        title: '5 Wicket Haul',
        type: 'bowling',
        description: `Took ${wickets} wickets`,
        playerId: bowler.playerId,
        matchId,
        earnedAt: now,
      }));
    } else if (wickets >= 3) {
      badges.push(makeBadge({
        id: `three_${bowler.playerId}_${matchId}`,
        title: '3 Wicket Haul',
        type: 'bowling',
        description: `Took ${wickets} wickets`,
        playerId: bowler.playerId,
        matchId,
        earnedAt: now,
      }));
    }
  }

  return badges;
}

function pickMatchHero(match) {
  let bestScore = 0;
  let hero = null;

  for (const inn of match.innings || []) {
    for (const b of inn.batsmen || []) {
      if ((b.runs || 0) > bestScore) {
        bestScore = b.runs;
        hero = {
          playerId: b.playerId,
          playerName: b.playerName || 'Player',
          reason: `Top scorer with ${b.runs} runs`,
        };
      }
    }
    for (const bowler of inn.bowlers || []) {
      const score = (bowler.wickets || 0) * 25;
      if (score > bestScore) {
        bestScore = score;
        hero = {
          playerId: bowler.playerId,
          playerName: bowler.playerName || 'Player',
          reason: `Match-winning ${bowler.wickets} wicket haul`,
        };
      }
    }
  }

  return hero;
}

function makeBadge({ id, title, type, description, playerId, matchId, earnedAt }) {
  return { id, title, type, description, playerId, matchId, earnedAt, iconName: 'star' };
}

module.exports = { evaluateInningsBadges, pickMatchHero };
