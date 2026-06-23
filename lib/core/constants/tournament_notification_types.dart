/// Firestore notification `type` values for tournament team workflows.
class TournamentNotificationTypes {
  TournamentNotificationTypes._();

  static const invitation = 'tournament_invitation';
  static const invitationAccepted = 'tournament_invitation_accepted';
  static const invitationRejected = 'tournament_invitation_rejected';
  static const joinRequest = 'tournament_join_request';
  static const joinApproved = 'tournament_join_approved';
  static const joinRejected = 'tournament_join_rejected';
}
