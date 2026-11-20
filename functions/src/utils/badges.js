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

/** Winning team id when the result is decided between the two sides. */
function decidedWinnerTeamId(match) {
  const w = (match.winnerTeamId || '').trim();
  if (!w) return null;
  if (w !== match.teamAId && w !== match.teamBId) return null;
  return w;
}

/** Team ids [playerId] appeared for in the match innings cards. */
function playerTeamIds(match, playerId) {
  const teams = new Set();
  for (const inn of match.innings || []) {
    if ((inn.batsmen || []).some((b) => b.playerId === playerId)) {
      if (inn.battingTeamId) teams.add(inn.battingTeamId);
    }
    if ((inn.bowlers || []).some((b) => b.playerId === playerId)) {
      if (inn.bowlingTeamId) teams.add(inn.bowlingTeamId);
    }
  }
  return teams;
}

/** True when [hero] may be Man of the Match (winning side on decided results). */
function isEligibleHero(match, hero) {
  if (!hero || !hero.playerId) return false;
  const winner = decidedWinnerTeamId(match);
  if (!winner) return true;
  const teams = playerTeamIds(match, hero.playerId);
  if (teams.size === 0) return true;
  return teams.has(winner);
}

/**
 * Man of the Match. On decided results only winning-team players are
 * eligible (mirrors BadgeService.pickMatchHero in the app). Ties / no
 * results consider both teams.
 */
function pickMatchHero(match) {
  const winner = decidedWinnerTeamId(match);
  const eligible = (teamId) => !winner || teamId === winner;
  let bestScore = 0;
  let hero = null;

  for (const inn of match.innings || []) {
    if (eligible(inn.battingTeamId)) {
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
    }
    if (eligible(inn.bowlingTeamId)) {
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
  }

  return hero;
}

function makeBadge({ id, title, type, description, playerId, matchId, earnedAt }) {
  return { id, title, type, description, playerId, matchId, earnedAt, iconName: 'star' };
}

module.exports = {
  evaluateInningsBadges,
  pickMatchHero,
  isEligibleHero,
  decidedWinnerTeamId,
};
