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
 * competitionPolicy.proposeAccess decides who may propose a match or
 * tournament besides the owner and org admins:
 *   'admins'     – nobody else (owner and org admins only)
 *   'teamAdmins' – admins of an approved org team (default)
 *   'everyone'   – team admins and active players of an approved org team
 * Orgs that never set it keep their old behaviour: membersCanRequest === true
 * means 'everyone', anything else means 'teamAdmins'.
 */

const PROPOSE_ACCESS = Object.freeze(['admins', 'teamAdmins', 'everyone']);

class CompetitionOpError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const DEFAULT_POLICY = Object.freeze({
  tournamentRequestsNeedApproval: true,
  matchRequestsNeedApproval: true,
  proposeAccess: 'teamAdmins',
  // Legacy mirror of proposeAccess === 'everyone' (older app builds read it).
  membersCanRequest: false,
});

const BOOLEAN_POLICY_KEYS = [
  'tournamentRequestsNeedApproval',
  'matchRequestsNeedApproval',
];

function resolveProposeAccess(p) {
  if (p && PROPOSE_ACCESS.includes(p.proposeAccess)) return p.proposeAccess;
  return p && p.membersCanRequest === true ? 'everyone' : 'teamAdmins';
}

function resolvePolicy(series) {
  const p = (series && series.competitionPolicy) || {};
  const proposeAccess = resolveProposeAccess(p);
  return {
    tournamentRequestsNeedApproval: p.tournamentRequestsNeedApproval !== false,
    matchRequestsNeedApproval: p.matchRequestsNeedApproval !== false,
    proposeAccess,
    membersCanRequest: proposeAccess === 'everyone',
  };
}

/**
 * Validates an owner's policy edit. Accepts the new proposeAccess, or the
 * legacy membersCanRequest boolean from older app builds (true = everyone,
 * false = team admins). proposeAccess wins when both are sent.
 */
function sanitizePolicy(input) {
  if (!input || typeof input !== 'object') {
    throw new CompetitionOpError('invalid-argument', 'policy required');
  }
  const out = {};
  for (const key of BOOLEAN_POLICY_KEYS) {
    if (key in input) {
      if (typeof input[key] !== 'boolean') {
        throw new CompetitionOpError('invalid-argument', `${key} must be true or false`);
      }
      out[key] = input[key];
    }
  }
  let proposeAccess = DEFAULT_POLICY.proposeAccess;
  if ('proposeAccess' in input) {
    if (!PROPOSE_ACCESS.includes(input.proposeAccess)) {
      throw new CompetitionOpError(
        'invalid-argument',
        `proposeAccess must be one of ${PROPOSE_ACCESS.join(', ')}`,
      );
    }
    proposeAccess = input.proposeAccess;
  } else if ('membersCanRequest' in input) {
    if (typeof input.membersCanRequest !== 'boolean') {
      throw new CompetitionOpError('invalid-argument', 'membersCanRequest must be true or false');
    }
    proposeAccess = input.membersCanRequest ? 'everyone' : 'teamAdmins';
  }
  return {
    ...resolvePolicy({ competitionPolicy: {} }),
    ...out,
    proposeAccess,
    membersCanRequest: proposeAccess === 'everyone',
  };
}

/**
 * kind: 'tournament' | 'match'.
 * Returns { role, autoApprove } or throws permission-denied.
 */
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
  const needs = kind === 'tournament'
    ? pol.tournamentRequestsNeedApproval
    : pol.matchRequestsNeedApproval;
  const access = pol.proposeAccess || resolveProposeAccess(pol);
  if (isTeamAdmin && access !== 'admins') return { role: 'clubAdmin', autoApprove: !needs };
  if (isMember && access === 'everyone') return { role: 'seriesPlayer', autoApprove: !needs };
  throw new CompetitionOpError(
    'permission-denied',
    access === 'admins'
      ? 'Only the org owner and admins can propose here'
      : access === 'everyone'
        ? 'Only org admins and members of org teams can do this'
        : 'Only org admins and team admins of org teams can do this',
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
  PROPOSE_ACCESS,
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
