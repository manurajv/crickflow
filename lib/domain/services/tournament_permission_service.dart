import '../../core/constants/enums.dart';
import '../../data/models/tournament/tournament_member_model.dart';

/// Role-based access control for tournament operations.
class TournamentPermissionService {
  const TournamentPermissionService();

  TournamentRole resolveRole({
    required String? userId,
    required String organizerId,
    TournamentMemberModel? membership,
  }) {
    if (userId == null || userId.isEmpty) return TournamentRole.viewer;
    if (userId == organizerId) return TournamentRole.owner;
    return membership?.role ?? TournamentRole.viewer;
  }

  bool canManageTournament(TournamentRole role) =>
      role == TournamentRole.owner || role == TournamentRole.admin;

  bool canManageTeams(TournamentRole role) => canManageTournament(role);

  bool canManageFixtures(TournamentRole role) => canManageTournament(role);

  bool canManageGroups(TournamentRole role) => canManageTournament(role);

  bool canManageOfficials(TournamentRole role) => canManageTournament(role);

  bool canManageSponsors(TournamentRole role) => canManageTournament(role);

  bool canEditRules(TournamentRole role) => canManageTournament(role);

  bool canScoreMatches(TournamentRole role) =>
      role == TournamentRole.owner ||
      role == TournamentRole.admin ||
      role == TournamentRole.scorer;

  bool canEditSettings(TournamentRole role) =>
      role == TournamentRole.owner || role == TournamentRole.admin;

  bool canDeleteTournament(TournamentRole role) => role == TournamentRole.owner;

  bool canInviteMembers(TournamentRole role) => canManageTournament(role);
}
