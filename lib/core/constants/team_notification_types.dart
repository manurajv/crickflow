/// Team roster notification [NotificationModel.type] values.
class TeamNotificationTypes {
  TeamNotificationTypes._();

  static const joinRequest = 'team_join_request';
  static const joinAccepted = 'team_join_accepted';
  static const joinRejected = 'team_join_rejected';

  static const invitation = 'team_invitation';
  static const invitationAccepted = 'team_invitation_accepted';
  static const invitationRejected = 'team_invitation_rejected';

  static const memberAdded = 'team_member_added';
  static const memberRemoved = 'team_member_removed';
}
