/**
 * Walk-in / guest players in org matches. Pure helpers (no Firebase) plus the
 * lookups the callers do themselves.
 *
 * A walk-in is a player without a linked CrickFlow account:
 *  - a match-only guest (snapshot isMatchOnlyPlayer / isRegisteredUser false,
 *    ids like `guest_<uuid>`), or
 *  - a roster player whose `players/{id}` doc has no userId.
 * Orgs decide with competitionPolicy.allowWalkIns (default true) whether org
 * matches and org-tournament matches may use them. Org teams' rosters never
 * hold walk-ins (rosters are locked and only change through org approvals).
 */

const SQUAD_KEYS = Object.freeze([
  'teamAPlayingPlayers',
  'teamASubstitutePlayers',
  'teamBPlayingPlayers',
  'teamBSubstitutePlayers',
]);

function squadSnapshots(match) {
  const out = [];
  for (const key of SQUAD_KEYS) {
    const list = match && match[key];
    if (!Array.isArray(list)) continue;
    for (const snap of list) {
      if (snap && typeof snap === 'object') out.push({ key, snap });
    }
  }
  return out;
}

/** Snapshot that is clearly a guest from its own flags / id. */
function isGuestSnapshot(snap) {
  if (!snap) return false;
  return snap.isMatchOnlyPlayer === true ||
    snap.isRegisteredUser === false ||
    String(snap.id || '').startsWith('guest_');
}

/** `players/{id}` doc ids to look up for the non-guest squad entries. */
function rosterPlayerIdsToCheck(match) {
  const ids = new Set();
  for (const { snap } of squadSnapshots(match)) {
    if (isGuestSnapshot(snap)) continue;
    const id = String(snap.playerId || snap.id || '');
    if (id) ids.add(id);
  }
  return [...ids];
}

/**
 * Squad entries that are walk-ins.
 * [userIdByPlayerDocId]: Map of players doc id -> userId ('' / null when the
 * doc exists without an account). Ids missing from the map are treated as
 * registered (unknown), so a deleted profile never blocks a match.
 */
function findWalkIns(match, userIdByPlayerDocId = new Map()) {
  const found = [];
  for (const { key, snap } of squadSnapshots(match)) {
    let walkIn = isGuestSnapshot(snap);
    if (!walkIn) {
      const id = String(snap.playerId || snap.id || '');
      if (id && userIdByPlayerDocId.has(id)) {
        walkIn = !String(userIdByPlayerDocId.get(id) || '').trim();
      }
    }
    if (walkIn) found.push({ key, id: String(snap.id || ''), name: String(snap.name || '') });
  }
  return found;
}

/** Player ids that already batted, bowled or fielded in the match. */
function playedPlayerIds(match) {
  const ids = new Set();
  for (const inn of (match && match.innings) || []) {
    for (const b of inn.batsmen || []) if (b && b.playerId) ids.add(b.playerId);
    for (const b of inn.bowlers || []) if (b && b.playerId) ids.add(b.playerId);
    for (const f of inn.fielders || []) if (f && f.playerId) ids.add(f.playerId);
  }
  return ids;
}

/**
 * Firestore patch that removes [walkIns] from the squads (and clears captain /
 * vice-captain / keeper slots that pointed at them). Walk-ins who already
 * played are kept: [kept] lists them. Returns null when nothing changes.
 */
function stripWalkInsPatch(match, walkIns) {
  const played = playedPlayerIds(match);
  const removeIds = new Set();
  const kept = [];
  for (const w of walkIns) {
    if (played.has(w.id)) kept.push(w);
    else removeIds.add(w.id);
  }
  if (removeIds.size === 0) return { patch: null, removed: [], kept };

  const patch = {};
  for (const key of SQUAD_KEYS) {
    const list = match[key];
    if (!Array.isArray(list)) continue;
    const next = list.filter((s) => !(s && removeIds.has(String(s.id || ''))));
    if (next.length !== list.length) patch[key] = next;
  }
  for (const side of ['A', 'B']) {
    const playing = patch[`team${side}PlayingPlayers`] || match[`team${side}PlayingPlayers`];
    if (Array.isArray(playing) && patch[`team${side}PlayingPlayers`]) {
      patch[`team${side}SquadIds`] = playing.map((s) => s.id);
    }
    for (const slot of ['Captain', 'ViceCaptain', 'WicketKeeper']) {
      const key = `team${side}${slot}Id`;
      if (removeIds.has(String(match[key] || ''))) patch[key] = null;
    }
  }
  const removed = walkIns.filter((w) => removeIds.has(w.id));
  return { patch, removed, kept };
}

/** Message shown to the client when a walk-in blocks registration. */
function walkInsMessage(walkIns) {
  const names = walkIns.map((w) => w.name).filter(Boolean).slice(0, 3);
  const list = names.length ? `: ${names.join(', ')}` : '';
  return `This org does not allow walk-in players${list}. Use players with CrickFlow accounts.`;
}

module.exports = {
  SQUAD_KEYS,
  squadSnapshots,
  isGuestSnapshot,
  rosterPlayerIdsToCheck,
  findWalkIns,
  playedPlayerIds,
  stripWalkInsPatch,
  walkInsMessage,
};
