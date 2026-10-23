/**
 * Pure validation for linking an existing match into a tournament.
 * Kept free of Firebase so it can be unit tested with plain objects.
 */

class LinkMatchError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const MANAGER_ROLES = new Set(['owner', 'admin']);
const CLOSED_TOURNAMENT_STATUSES = new Set(['completed', 'cancelled', 'archived']);

/** Owner (createdBy / organizerId) or a tournament member with owner/admin role. */
function canManageTournament(tournament, uid, memberRole) {
  if (!uid || !tournament) return false;
  if (tournament.createdBy === uid || tournament.organizerId === uid) return true;
  return MANAGER_ROLES.has(memberRole || '');
}

/**
 * Throws LinkMatchError when [match] cannot be linked to [tournament].
 * Returns the Firestore patch for the match document.
 */
function validateLink({
  tournamentId,
  tournament,
  match,
  uid,
  memberRole,
  registerOnly = false,
}) {
  if (!tournament) throw new LinkMatchError('not-found', 'Tournament not found');
  if (!canManageTournament(tournament, uid, memberRole)) {
    throw new LinkMatchError(
      'permission-denied',
      'Only tournament admins can add matches to this tournament',
    );
  }
  if (CLOSED_TOURNAMENT_STATUSES.has(tournament.status)) {
    throw new LinkMatchError('failed-precondition', 'This tournament is closed');
  }
  if (!match) throw new LinkMatchError('not-found', 'Match not found');

  const linked = (match.tournamentId || '').trim();
  if (registerOnly) {
    // Match was created inside the tournament (tournamentId already set);
    // only the tournament's match list needs the id.
    if (linked !== tournamentId) {
      throw new LinkMatchError(
        'failed-precondition',
        'Match was not created in this tournament',
      );
    }
  } else if (linked === tournamentId) {
    throw new LinkMatchError('already-exists', 'Match is already in this tournament');
  }
  if (linked && linked !== tournamentId) {
    throw new LinkMatchError(
      'failed-precondition',
      'Match already belongs to another tournament',
    );
  }
  const orgLinked = !!tournament.seriesId && tournament.seriesOfficialStatus !== 'rejected';
  if (orgLinked && match.matchMode === 'quick') {
    throw new LinkMatchError(
      'failed-precondition',
      'Quick matches are not allowed in org tournaments. Start a normal match instead.',
    );
  }
  // Org match started inside its own org tournament is fine.
  if (match.seriesId && match.seriesId !== tournament.seriesId) {
    throw new LinkMatchError(
      'failed-precondition',
      'Series matches cannot be added to a tournament',
    );
  }

  const teamIds = new Set(tournament.teamIds || []);
  if (!match.teamAId || !match.teamBId) {
    throw new LinkMatchError(
      'failed-precondition',
      'Both match teams must be registered teams',
    );
  }
  if (!teamIds.has(match.teamAId) || !teamIds.has(match.teamBId)) {
    throw new LinkMatchError(
      'failed-precondition',
      'Both teams must be part of this tournament',
    );
  }

  return {
    tournamentId,
    matchType: 'tournament',
  };
}

/** Results that affect standings when the match is linked after it ended. */
function shouldApplyStandings(match) {
  return match && (match.status === 'completed' || match.status === 'abandoned');
}

module.exports = {
  LinkMatchError,
  canManageTournament,
  validateLink,
  shouldApplyStandings,
};
