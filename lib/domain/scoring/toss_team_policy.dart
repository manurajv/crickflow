import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';

/// Derives batting/bowling teams from toss and innings order.
class TossTeamPolicy {
  TossTeamPolicy._();

  /// Who bats and bowls in innings 1 from recorded toss.
  static ({String battingTeamId, String bowlingTeamId}) firstInningsTeams(
    MatchModel match,
  ) {
    final setup = match.setup;
    final teamAId = match.teamAId;
    final teamBId = match.teamBId;
    if (setup == null ||
        !setup.tossReady ||
        teamAId == null ||
        teamBId == null) {
      return (
        battingTeamId: teamAId ?? 'team_a',
        bowlingTeamId: teamBId ?? 'team_b',
      );
    }

    final winnerIsA = setup.tossWinnerIsTeamA!;
    final winnerBatsFirst = setup.tossWinnerBatsFirst!;
    final battingIsTeamA = winnerIsA == winnerBatsFirst;
    return (
      battingTeamId: battingIsTeamA ? teamAId : teamBId,
      bowlingTeamId: battingIsTeamA ? teamBId : teamAId,
    );
  }

  /// Second innings: team that bowled first innings bats; team that batted bowls.
  static ({String battingTeamId, String bowlingTeamId}) chaseInningsTeams(
    InningsModel firstInnings,
  ) {
    return (
      battingTeamId: firstInnings.bowlingTeamId,
      bowlingTeamId: firstInnings.battingTeamId,
    );
  }
}
