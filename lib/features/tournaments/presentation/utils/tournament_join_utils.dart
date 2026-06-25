import '../../../../data/models/team_model.dart';
import '../../../../data/models/tournament/tournament_team_request_model.dart';
import '../../../../data/models/tournament_model.dart';

/// Shared helpers for tournament join UI (dashboard banner + join screen).
abstract final class TournamentJoinUtils {
  static Map<String, TournamentTeamRequestModel> requestMap(
    List<TournamentTeamRequestModel> requests,
  ) =>
      {for (final r in requests) r.teamId: r};

  /// Leadership teams already enrolled in the tournament.
  static List<TeamModel> joinedTeams(
    TournamentModel tournament,
    List<TeamModel> leadershipTeams,
  ) =>
      leadershipTeams
          .where((team) => tournament.teamIds.contains(team.id))
          .toList();

  /// Teams with a pending join request or invitation (not yet in tournament).
  static List<TeamModel> pendingTeams({
    required TournamentModel tournament,
    required List<TeamModel> leadershipTeams,
    required Map<String, TournamentTeamRequestModel> requestByTeamId,
  }) =>
      leadershipTeams.where((team) {
        if (tournament.teamIds.contains(team.id)) return false;
        return requestByTeamId[team.id]?.isPending ?? false;
      }).toList();

  /// Teams the user can still request to join (excludes joined + pending).
  static List<TeamModel> actionableJoinTeams({
    required TournamentModel tournament,
    required List<TeamModel> leadershipTeams,
    required Map<String, TournamentTeamRequestModel> requestByTeamId,
  }) =>
      leadershipTeams.where((team) {
        if (tournament.teamIds.contains(team.id)) return false;
        final request = requestByTeamId[team.id];
        if (request?.isPending ?? false) return false;
        if (request?.status == TournamentTeamRequestStatus.approved) {
          return false;
        }
        return true;
      }).toList();

  /// Join-screen list — includes pending teams so their status is visible.
  static List<TeamModel> selectableJoinTeams({
    required TournamentModel tournament,
    required List<TeamModel> leadershipTeams,
    required Map<String, TournamentTeamRequestModel> requestByTeamId,
  }) =>
      leadershipTeams.where((team) {
        if (tournament.teamIds.contains(team.id)) return false;
        final request = requestByTeamId[team.id];
        if (request?.status == TournamentTeamRequestStatus.approved) {
          return false;
        }
        return true;
      }).toList();
}
