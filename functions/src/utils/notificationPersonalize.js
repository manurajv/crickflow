const { resolveAuthUid } = require('../notifications/pushUtils');

/**
 * Collect playing XI snapshots from a match document (flat setup fields).
 */
function playingSnapshots(match) {
  const lists = [
    match.teamAPlayingPlayers,
    match.teamBPlayingPlayers,
    match.teamASquadIds,
    match.teamBSquadIds,
  ];
  const out = [];
  for (const list of lists) {
    if (!Array.isArray(list)) continue;
    for (const item of list) {
      if (typeof item === 'string') {
        out.push({ id: item, name: '', playerId: item });
      } else if (item && typeof item === 'object') {
        out.push({
          id: item.id || item.playerId || '',
          name: item.name || '',
          playerId: item.playerId || item.id || '',
        });
      }
    }
  }
  return out.filter((p) => p.id);
}

/**
 * Map of playerDocId -> { name, userId } for players in the match XI.
 */
async function resolveMatchPlayers(db, match) {
  const snaps = playingSnapshots(match);
  const byPlayerId = new Map();

  for (const snap of snaps) {
    const playerId = snap.id;
    if (!playerId || byPlayerId.has(playerId)) continue;
    const uid = await resolveAuthUid(db, playerId);
    byPlayerId.set(playerId, {
      playerId,
      name: snap.name || 'Player',
      userId: uid || null,
    });
  }

  // Also include batsmen/bowlers from innings (may cover late replacements).
  for (const inn of match.innings || []) {
    for (const list of [inn.batsmen || [], inn.bowlers || [], inn.fielders || []]) {
      for (const p of list) {
        if (!p?.playerId || byPlayerId.has(p.playerId)) continue;
        const uid = await resolveAuthUid(db, p.playerId);
        byPlayerId.set(p.playerId, {
          playerId: p.playerId,
          name: p.playerName || 'Player',
          userId: uid || null,
        });
      }
    }
  }

  return byPlayerId;
}

/**
 * Build recipient context: playing status + followed players in this match.
 */
async function buildRecipientContext(db, userId, matchPlayers) {
  const playingPlayerIds = [];
  let playingName = null;
  const playerUserIds = [];

  for (const p of matchPlayers.values()) {
    if (p.userId === userId) {
      playingPlayerIds.push(p.playerId);
      playingName = p.name;
    }
    if (p.userId) playerUserIds.push(p.userId);
  }

  const isPlaying = playingPlayerIds.length > 0;
  const followedPlayerIds = [];
  const followedNames = [];

  // Query follows where this user is the follower and followed is in match.
  if (playerUserIds.length > 0) {
    const uniqueFollowed = [...new Set(playerUserIds.filter((u) => u !== userId))];
    // Firestore 'in' limit 30 — batch.
    for (let i = 0; i < uniqueFollowed.length; i += 30) {
      const chunk = uniqueFollowed.slice(i, i + 30);
      const followIds = chunk.map((fid) => `${userId}_${fid}`);
      // Fetch docs by id in parallel
      const docs = await Promise.all(
        followIds.map((id) => db.collection('playerFollows').doc(id).get()),
      );
      for (const doc of docs) {
        if (!doc.exists) continue;
        const data = doc.data();
        const followedUserId = data.followedUserId;
        for (const p of matchPlayers.values()) {
          if (p.userId === followedUserId) {
            followedPlayerIds.push(p.playerId);
            followedNames.push(p.name);
          }
        }
      }
    }
  }

  return {
    userId,
    isPlaying,
    playingPlayerIds,
    playingName,
    followedPlayerIds: [...new Set(followedPlayerIds)],
    followedNames: [...new Set(followedNames)],
  };
}

/**
 * Decide whether to send a player-subject notification and which perspective.
 * Priority: self > network. If recipient is playing, never notify about others.
 */
function resolveSubjectPerspective(ctx, subjectPlayerId) {
  if (!subjectPlayerId) return { send: true, perspective: 'general' };

  if (ctx.playingPlayerIds.includes(subjectPlayerId)) {
    return { send: true, perspective: 'self' };
  }
  if (ctx.isPlaying) {
    return { send: false, perspective: null };
  }
  if (ctx.followedPlayerIds.includes(subjectPlayerId)) {
    return { send: true, perspective: 'network' };
  }
  return { send: false, perspective: null };
}

/**
 * For lifecycle events (start / innings break): personalize copy.
 */
function resolveLifecyclePerspective(ctx) {
  if (ctx.isPlaying) {
    return {
      perspective: 'self',
      actorName: ctx.playingName,
      actorPlayerId: ctx.playingPlayerIds[0] || null,
    };
  }
  if (ctx.followedPlayerIds.length > 0) {
    return {
      perspective: 'network',
      actorName: ctx.followedNames[0] || 'A player you follow',
      actorPlayerId: ctx.followedPlayerIds[0] || null,
    };
  }
  return { perspective: 'general', actorName: null, actorPlayerId: null };
}

/**
 * Extract batting/bowling/fielding performance for a player in a match.
 */
function extractPlayerPerformance(match, playerId) {
  let runs = 0;
  let balls = 0;
  let wickets = 0;
  let runsConceded = 0;
  let ballsBowled = 0;
  let catches = 0;
  const bpo = match?.rules?.ballsPerOver || 6;

  for (const inn of match.innings || []) {
    for (const b of inn.batsmen || []) {
      if (b.playerId !== playerId) continue;
      runs += b.runs || 0;
      balls += b.ballsFaced || b.balls || 0;
    }
    for (const b of inn.bowlers || []) {
      if (b.playerId !== playerId) continue;
      wickets += b.wickets || 0;
      runsConceded += b.runsConceded || b.runs || 0;
      ballsBowled += b.ballsBowled || b.legalBalls || 0;
    }
    for (const f of inn.fielders || []) {
      if (f.playerId !== playerId) continue;
      catches += f.catches || 0;
    }
  }

  if (runs === 0 && wickets === 0 && catches === 0) return null;
  return { runs, balls, wickets, runsConceded, ballsBowled, catches, bpo };
}

/**
 * Enrich hero object with batting/bowling summary lines.
 */
function enrichHero(match, hero) {
  if (!hero?.playerId) return hero;
  const perf = extractPlayerPerformance(match, hero.playerId);
  if (!perf) return hero;
  const out = { ...hero };
  if (perf.runs > 0) {
    out.battingLine = `${perf.runs}${perf.balls > 0 ? ` (${perf.balls})` : ''}`;
  }
  if (perf.wickets > 0) {
    out.bowlingLine =
      perf.runsConceded != null
        ? `${perf.wickets} Wickets · ${perf.wickets}/${perf.runsConceded}`
        : `${perf.wickets} Wickets`;
  }
  return out;
}

module.exports = {
  playingSnapshots,
  resolveMatchPlayers,
  buildRecipientContext,
  resolveSubjectPerspective,
  resolveLifecyclePerspective,
  extractPlayerPerformance,
  enrichHero,
};
