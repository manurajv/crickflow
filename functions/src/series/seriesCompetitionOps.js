/**
 * Pure rules for starting tournaments / matches inside an org (series).
 * Free of Firebase so they can be unit tested with plain objects.
 *
 * Who can do what:
 * - Owner + active org admins: create/start directly (auto-approved) and link
 *   one of their own existing tournaments.
 * - Active team admins of an approved org team: request a tournament, or a
 *   match that involves their team. Goes to the approvals queue unless the
 *   org's competitionPolicy says that request type needs no approval.
 * - Active players of an approved org team: same as team admins, only when
 *   competitionPolicy.proposeAccess is 'everyone'.
 * - Everyone else: denied.
 *
 * competitionPolicy (all keys optional, see resolvePolicy):
 *   matchProposeAccess / tournamentProposeAccess decide, independently, who
 *   may propose that kind besides the owner and org admins:
 *     'admins'     – nobody else (owner and org admins only)
 *     'teamAdmins' – admins of an approved org team (default)
 *     'everyone'   – team admins and active players of an approved org team
 *   {match,tournament}{TeamAdmins,Players}NeedApproval say whether a request
 *   from that role waits for an org admin (default true) or starts directly.
 *   allowWalkIns (default true) lets org matches use walk-in / guest players.
 * Older orgs only have proposeAccess / membersCanRequest and the two
 * *RequestsNeedApproval booleans; they seed both kinds and both roles.
 * membersCanRequest === true means 'everyone', anything else 'teamAdmins'.
 */

const PROPOSE_ACCESS = Object.freeze(['admins', 'teamAdmins', 'everyone']);
const ACCESS_RANK = Object.freeze({ admins: 0, teamAdmins: 1, everyone: 2 });

class CompetitionOpError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

/** Who-can-propose keys, one per competition kind. */
const ACCESS_KEYS = Object.freeze({
  match: 'matchProposeAccess',
  tournament: 'tournamentProposeAccess',
});

/**
 * Approval switches: does a request from this role wait for an org admin?
 * Role 'teamAdmins' = admins of an org team, 'players' = other team members.
 */
const APPROVAL_KEYS = Object.freeze({
  match: { teamAdmins: 'matchTeamAdminsNeedApproval', players: 'matchPlayersNeedApproval' },
  tournament: {
    teamAdmins: 'tournamentTeamAdminsNeedApproval',
    players: 'tournamentPlayersNeedApproval',
  },
});

const BOOLEAN_POLICY_KEYS = [
  'tournamentRequestsNeedApproval',
  'matchRequestsNeedApproval',
  'matchTeamAdminsNeedApproval',
  'matchPlayersNeedApproval',
  'tournamentTeamAdminsNeedApproval',
  'tournamentPlayersNeedApproval',
  'allowWalkIns',
];

/** Single legacy setting: proposeAccess, else membersCanRequest. */
function resolveProposeAccess(p) {
  if (p && PROPOSE_ACCESS.includes(p.proposeAccess)) return p.proposeAccess;
  return p && p.membersCanRequest === true ? 'everyone' : 'teamAdmins';
}

/** Who may propose [kind] ('match' | 'tournament'), with legacy fallback. */
function resolveKindAccess(p, kind) {
  const v = p && p[ACCESS_KEYS[kind]];
  return PROPOSE_ACCESS.includes(v) ? v : resolveProposeAccess(p);
}

/** Whether a request of [kind] from [role] ('teamAdmins' | 'players') needs approval. */
function resolveNeedsApproval(p, kind, role) {
  const v = p && p[APPROVAL_KEYS[kind][role]];
  if (typeof v === 'boolean') return v;
  const legacy = p && (kind === 'tournament'
    ? p.tournamentRequestsNeedApproval
    : p.matchRequestsNeedApproval);
  return legacy !== false;
}

function maxAccess(a, b) {
  return ACCESS_RANK[a] >= ACCESS_RANK[b] ? a : b;
}

/**
 * Full, normalised policy. New orgs store the per-kind fields; older orgs
 * only have proposeAccess / membersCanRequest and the two approval booleans,
 * which seed both kinds and both roles. Legacy mirror fields are always
 * derived so older app builds keep working:
 *   proposeAccess      – the more permissive of match / tournament
 *   membersCanRequest  – proposeAccess === 'everyone'
 *   *RequestsNeedApproval – true when any role needs approval
 */
function resolvePolicy(series) {
  const p = (series && series.competitionPolicy) || {};
  const matchProposeAccess = resolveKindAccess(p, 'match');
  const tournamentProposeAccess = resolveKindAccess(p, 'tournament');
  const matchTeamAdminsNeedApproval = resolveNeedsApproval(p, 'match', 'teamAdmins');
  const matchPlayersNeedApproval = resolveNeedsApproval(p, 'match', 'players');
  const tournamentTeamAdminsNeedApproval = resolveNeedsApproval(p, 'tournament', 'teamAdmins');
  const tournamentPlayersNeedApproval = resolveNeedsApproval(p, 'tournament', 'players');
  const proposeAccess = maxAccess(matchProposeAccess, tournamentProposeAccess);
  return {
    matchProposeAccess,
    tournamentProposeAccess,
    matchTeamAdminsNeedApproval,
    matchPlayersNeedApproval,
    tournamentTeamAdminsNeedApproval,
    tournamentPlayersNeedApproval,
    allowWalkIns: p.allowWalkIns !== false,
    // Legacy mirrors (older app builds read these).
    proposeAccess,
    membersCanRequest: proposeAccess === 'everyone',
    matchRequestsNeedApproval: matchTeamAdminsNeedApproval || matchPlayersNeedApproval,
    tournamentRequestsNeedApproval:
      tournamentTeamAdminsNeedApproval || tournamentPlayersNeedApproval,
  };
}

const DEFAULT_POLICY = Object.freeze(resolvePolicy({}));

function assertAccessValue(key, value) {
  if (!PROPOSE_ACCESS.includes(value)) {
    throw new CompetitionOpError(
      'invalid-argument',
      `${key} must be one of ${PROPOSE_ACCESS.join(', ')}`,
    );
  }
}

/**
 * Validates an owner's policy edit and returns the full policy to store.
 * Partial edits are merged onto [existing] (the org's current competitionPolicy)
 * so a client that only sends some fields never resets the others.
 *
 * Input precedence: legacy single settings (proposeAccess, membersCanRequest,
 * *RequestsNeedApproval) are applied first and seed both kinds / both roles;
 * the per-kind fields then override them. Unknown keys are dropped.
 */
function sanitizePolicy(input, existing = null) {
  if (!input || typeof input !== 'object') {
    throw new CompetitionOpError('invalid-argument', 'policy required');
  }
  for (const key of BOOLEAN_POLICY_KEYS) {
    if (key in input && typeof input[key] !== 'boolean') {
      throw new CompetitionOpError('invalid-argument', `${key} must be true or false`);
    }
  }
  if ('membersCanRequest' in input && typeof input.membersCanRequest !== 'boolean') {
    throw new CompetitionOpError('invalid-argument', 'membersCanRequest must be true or false');
  }
  const out = { ...resolvePolicy({ competitionPolicy: existing || {} }) };

  // 1. Legacy single settings seed both kinds / both roles.
  if ('proposeAccess' in input) {
    assertAccessValue('proposeAccess', input.proposeAccess);
    out.matchProposeAccess = input.proposeAccess;
    out.tournamentProposeAccess = input.proposeAccess;
  } else if ('membersCanRequest' in input) {
    const v = input.membersCanRequest ? 'everyone' : 'teamAdmins';
    out.matchProposeAccess = v;
    out.tournamentProposeAccess = v;
  }
  if ('matchRequestsNeedApproval' in input) {
    out.matchTeamAdminsNeedApproval = input.matchRequestsNeedApproval;
    out.matchPlayersNeedApproval = input.matchRequestsNeedApproval;
  }
  if ('tournamentRequestsNeedApproval' in input) {
    out.tournamentTeamAdminsNeedApproval = input.tournamentRequestsNeedApproval;
    out.tournamentPlayersNeedApproval = input.tournamentRequestsNeedApproval;
  }

  // 2. Per-kind fields win over the legacy ones.
  for (const key of Object.values(ACCESS_KEYS)) {
    if (key in input) {
      assertAccessValue(key, input[key]);
      out[key] = input[key];
    }
  }
  for (const key of [
    ...Object.values(APPROVAL_KEYS.match),
    ...Object.values(APPROVAL_KEYS.tournament),
    'allowWalkIns',
  ]) {
    if (key in input) out[key] = input[key];
  }
  return resolvePolicy({ competitionPolicy: out });
}

/** Orgs that are archived, suspended or on platform hold take no new matches. */
function isOrgOpen(series) {
  if (!series) return true;
  if (series.platformHold === true) return false;
  return !['archived', 'suspended'].includes(series.status);
}

function decideAccess({
  kind, isAdmin, isOwner, isTeamAdmin, isMember, policy, orgOpen = true,
}) {
  if (orgOpen === false) {
    throw new CompetitionOpError(
      'failed-precondition',
      'This org is not active, so new matches and tournaments cannot be added',
    );
  }
  if (isAdmin) {
    return { role: isOwner ? 'superAdmin' : 'seriesAdmin', autoApprove: true };
  }
  const pol = policy || resolvePolicy(null);
  const access = resolveKindAccess(pol, kind);
  const noun = kind === 'tournament' ? 'tournaments' : 'matches';
  if (isTeamAdmin && access !== 'admins') {
    return {
      role: 'clubAdmin',
      autoApprove: !resolveNeedsApproval(pol, kind, 'teamAdmins'),
    };
  }
  if (isMember && access === 'everyone') {
    return {
      role: 'seriesPlayer',
      autoApprove: !resolveNeedsApproval(pol, kind, 'players'),
    };
  }
  throw new CompetitionOpError(
    'permission-denied',
    access === 'admins'
      ? `Only the org owner and admins can add ${noun} here`
      : access === 'everyone'
        ? `Only org admins and members of org teams can add ${noun}`
        : `Only org admins and team admins of org teams can add ${noun}`,
  );
}

function isTournamentOrganizer(tournament, uid) {
  return !!tournament && !!uid &&
    (tournament.createdBy === uid || tournament.organizerId === uid);
}

/** The tournament may be linked to [seriesId] (not another org, not reviewed). */
function validateTournamentLink({ tournament, seriesId, uid }) {
  if (!tournament) throw new CompetitionOpError('not-found', 'Tournament not found');
  if (!isTournamentOrganizer(tournament, uid)) {
    throw new CompetitionOpError(
      'permission-denied',
      'You can only add tournaments you organize',
    );
  }
  if (tournament.seriesId && tournament.seriesId !== seriesId &&
      tournament.seriesOfficialStatus !== 'rejected') {
    throw new CompetitionOpError('failed-precondition', 'Tournament already belongs to another org');
  }
  if (tournament.seriesId === seriesId &&
      ['approved', 'pendingApproval'].includes(tournament.seriesOfficialStatus)) {
    throw new CompetitionOpError('already-exists', 'Tournament is already in this org');
  }
}

/** Approved org teams that can play: map of linked CrickFlow teamId → team row. */
function playableTeamsByLinkedId(clubs) {
  const out = new Map();
  for (const c of clubs || []) {
    if (c && c.status === 'approved' && c.linkedTeamId) out.set(c.linkedTeamId, c);
  }
  return out;
}

/** Both match sides must be approved org teams. Returns [teamA, teamB] rows. */
function resolveMatchTeams({ match, clubs }) {
  if (!match) throw new CompetitionOpError('not-found', 'Match not found');
  const byTeam = playableTeamsByLinkedId(clubs);
  const a = byTeam.get(match.teamAId || '');
  const b = byTeam.get(match.teamBId || '');
  if (!a || !b) {
    throw new CompetitionOpError(
      'failed-precondition',
      'Both teams must be approved teams of this org',
    );
  }
  if (a.id === b.id) {
    throw new CompetitionOpError('invalid-argument', 'Pick two different teams');
  }
  return [a, b];
}

/** Requester (non-admin) must belong to one of the two sides. */
function requesterOwnsSide({ isAdmin, sideClubIds, myClubIds }) {
  if (isAdmin) return true;
  return sideClubIds.some((id) => myClubIds.includes(id));
}

/** Who may register a match into an org: its creator or one of its scorers. */
function canRegisterMatch(match, uid) {
  if (!match || !uid) return false;
  return match.createdBy === uid ||
    (Array.isArray(match.scorerIds) && match.scorerIds.includes(uid));
}

/** Validate team rows chosen for a new org tournament. */
function resolveTournamentTeams({ teamClubIds, clubs }) {
  const ids = Array.from(new Set((teamClubIds || []).map(String).filter(Boolean)));
  if (ids.length > 64) throw new CompetitionOpError('invalid-argument', 'Too many teams');
  const byId = new Map((clubs || []).map((c) => [c.id, c]));
  return ids.map((id) => {
    const c = byId.get(id);
    if (!c || c.status !== 'approved') {
      throw new CompetitionOpError('failed-precondition', 'Only approved org teams can be added');
    }
    if (!c.linkedTeamId) {
      throw new CompetitionOpError(
        'failed-precondition',
        `${c.name || 'Team'} is not linked to a CrickFlow team yet`,
      );
    }
    return c;
  });
}

/** Tournament doc patch that adds org teams (teamIds + points table rows). */
function tournamentTeamsPatch(tournament, teamRows) {
  const teamIds = Array.isArray(tournament.teamIds) ? [...tournament.teamIds] : [];
  const table = Array.isArray(tournament.pointsTable) ? [...tournament.pointsTable] : [];
  for (const c of teamRows) {
    if (!teamIds.includes(c.linkedTeamId)) teamIds.push(c.linkedTeamId);
    if (!table.some((e) => e && e.teamId === c.linkedTeamId)) {
      table.push({ teamId: c.linkedTeamId, teamName: c.name || '' });
    }
  }
  return { teamIds, pointsTable: table };
}

/**
 * Server-side source of truth for "this match counts for the org": the
 * approved series_competitions row (clients cannot approve it) must cover the
 * match directly or through its tournament. Match-doc flags alone are not
 * trusted because scorers can write them.
 */
function isQuickMatch(match) {
  return !!match && match.matchMode === 'quick';
}

/** Orgs only allow normal matches (also inside org tournaments). */
function assertNotQuick(match) {
  if (isQuickMatch(match)) {
    throw new CompetitionOpError(
      'failed-precondition',
      'Quick matches are not allowed in orgs. Start a normal match instead.',
    );
  }
}

function competitionCoversMatch(comp, match) {
  if (!comp || !match || comp.status !== 'approved') return false;
  if (isQuickMatch(match)) return false;
  if (!match.seriesId || comp.seriesId !== match.seriesId) return false;
  if (comp.matchId && comp.matchId === match.id) return true;
  return !!comp.tournamentId && comp.tournamentId === match.tournamentId;
}

module.exports = {
  isQuickMatch,
  assertNotQuick,
  competitionCoversMatch,
  CompetitionOpError,
  DEFAULT_POLICY,
  resolvePolicy,
  sanitizePolicy,
  resolveProposeAccess,
  resolveKindAccess,
  resolveNeedsApproval,
  PROPOSE_ACCESS,
  ACCESS_KEYS,
  APPROVAL_KEYS,
  decideAccess,
  isOrgOpen,
  isTournamentOrganizer,
  validateTournamentLink,
  playableTeamsByLinkedId,
  resolveMatchTeams,
  requesterOwnsSide,
  canRegisterMatch,
  resolveTournamentTeams,
  tournamentTeamsPatch,
};
