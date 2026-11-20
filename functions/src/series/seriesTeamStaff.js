/** Team-admin invitations and player-removal decisions. */

const CLUB_ADMIN_STATUS = Object.freeze({
  invited: 'invited',
  active: 'active',
  pending: 'pending',
  cancelled: 'cancelled',
  declined: 'declined',
  removed: 'removed',
});

function isEffectiveClubAdmin(status) {
  return status === CLUB_ADMIN_STATUS.active;
}

function isOpenClubAdminInvite(status) {
  return status === CLUB_ADMIN_STATUS.invited;
}

function canInviteClubAdmin(existingStatus) {
  if (!existingStatus) return true;
  return [
    CLUB_ADMIN_STATUS.cancelled,
    CLUB_ADMIN_STATUS.declined,
    CLUB_ADMIN_STATUS.removed,
  ].includes(existingStatus);
}

function nextClubAdminStatusOnAccept(clubStatus) {
  return clubStatus === 'approved' ? CLUB_ADMIN_STATUS.active : CLUB_ADMIN_STATUS.pending;
}

function assertReason(reason) {
  const text = String(reason || '').trim();
  if (!text) {
    const err = new Error('A reason is required');
    err.code = 'invalid-argument';
    throw err;
  }
  return text.slice(0, 500);
}

/** Org admins finalize immediately; team admins request approval. */
function playerRemovalPath({ isOrgAdmin, reason }) {
  return {
    mode: isOrgAdmin ? 'direct' : 'request',
    reason: assertReason(reason),
  };
}

function isListedSquadMember(status) {
  return status === 'active' || status === 'pendingRemoval';
}

module.exports = {
  CLUB_ADMIN_STATUS,
  isEffectiveClubAdmin,
  isOpenClubAdminInvite,
  canInviteClubAdmin,
  nextClubAdminStatusOnAccept,
  assertReason,
  playerRemovalPath,
  isListedSquadMember,
};
