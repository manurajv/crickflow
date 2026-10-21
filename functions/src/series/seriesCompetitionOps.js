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
 *   competitionPolicy.membersCanRequest is true.
 * - Everyone else: denied.
 */

class CompetitionOpError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const DEFAULT_POLICY = Object.freeze({
  tournamentRequestsNeedApproval: true,
  matchRequestsNeedApproval: true,
  membersCanRequest: false,
});

function resolvePolicy(series) {
  const p = (series && series.competitionPolicy) || {};
  return {
    tournamentRequestsNeedApproval: p.tournamentRequestsNeedApproval !== false,
    matchRequestsNeedApproval: p.matchRequestsNeedApproval !== false,
    membersCanRequest: p.membersCanRequest === true,
  };
}

function sanitizePolicy(input) {
  if (!input || typeof input !== 'object') {
    throw new CompetitionOpError('invalid-argument', 'policy required');
  }
  const out = {};
  for (const key of Object.keys(DEFAULT_POLICY)) {
    if (key in input) {
      if (typeof input[key] !== 'boolean') {
        throw new CompetitionOpError('invalid-argument', `${key} must be true or false`);
      }
      out[key] = input[key];
    }
  }
  return { ...resolvePolicy({ competitionPolicy: {} }), ...out };
}

/**
 * kind: 'tournament' | 'match'.
 * Returns { role, autoApprove } or throws permission-denied.
 */
function decideAccess({ kind, isAdmin, isOwner, isTeamAdmin, isMember, policy }) {
  if (isAdmin) {
    return { role: isOwner ? 'superAdmin' : 'seriesAdmin', autoApprove: true };
  }
  const pol = policy || resolvePolicy(null);
  const needs = kind === 'tournament'
    ? pol.tournamentRequestsNeedApproval
    : pol.matchRequestsNeedApproval;
  if (isTeamAdmin) return { role: 'clubAdmin', autoApprove: !needs };
  if (isMember && pol.membersCanRequest) return { role: 'seriesPlayer', autoApprove: !needs };
  throw new CompetitionOpError(
    'permission-denied',
    'Only org admins, team admins of org teams or allowed members can do this',
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
function competitionCoversMatch(comp, match) {
  if (!comp || !match || comp.status !== 'approved') return false;
  if (!match.seriesId || comp.seriesId !== match.seriesId) return false;
  if (comp.matchId && comp.matchId === match.id) return true;
  return !!comp.tournamentId && comp.tournamentId === match.tournamentId;
}

module.exports = {
  competitionCoversMatch,
  CompetitionOpError,
  DEFAULT_POLICY,
  resolvePolicy,
  sanitizePolicy,
  decideAccess,
  isTournamentOrganizer,
  validateTournamentLink,
  playableTeamsByLinkedId,
  resolveMatchTeams,
  requesterOwnsSide,
  canRegisterMatch,
  resolveTournamentTeams,
  tournamentTeamsPatch,
};
