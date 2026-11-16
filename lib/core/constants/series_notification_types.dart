/// In-app / FCM notification type strings for Series (must stay in firestore.rules allowlist).
class SeriesNotificationTypes {
  SeriesNotificationTypes._();

  static const approvalPending = 'series_approval_pending';
  static const approvalApproved = 'series_approval_approved';
  static const approvalRejected = 'series_approval_rejected';
  static const clubJoinRequest = 'series_club_join_request';
  static const memberAdded = 'series_member_added';
  static const memberRemoved = 'series_member_removed';
  static const clubAdminInvite = 'series_club_admin_invite';
  static const clubAdminInviteAccepted = 'series_club_admin_invite_accepted';
  static const clubAdminInviteDeclined = 'series_club_admin_invite_declined';
  static const clubAdminInviteCancelled = 'series_club_admin_invite_cancelled';
  static const playerRemovalRequested = 'series_player_removal_requested';
}
