import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/data/models/match_setup_draft_models.dart';
import 'package:crickflow/domain/scoring/toss_team_policy.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _match({
  required bool winnerIsTeamA,
  required bool winnerBatsFirst,
}) {
  return MatchModel(
    id: 'm1',
    title: 'A vs B',
    matchType: MatchType.single,
    status: MatchStatus.tossCompleted,
    teamAId: 'team_a',
    teamBId: 'team_b',
    teamAName: 'Team A',
    teamBName: 'Team B',
    rules: const MatchRulesModel(),
    setup: MatchSetupData(
      tossWinnerIsTeamA: winnerIsTeamA,
      tossWinnerBatsFirst: winnerBatsFirst,
    ),
  );
}

void main() {
  group('TossTeamPolicy', () {
    test('winner bats first — winner is batting team', () {
      final teams = TossTeamPolicy.firstInningsTeams(
        _match(winnerIsTeamA: true, winnerBatsFirst: true),
      );
      expect(teams.battingTeamId, 'team_a');
      expect(teams.bowlingTeamId, 'team_b');
    });

    test('winner bowls first — other team bats', () {
      final teams = TossTeamPolicy.firstInningsTeams(
        _match(winnerIsTeamA: true, winnerBatsFirst: false),
      );
      expect(teams.battingTeamId, 'team_b');
      expect(teams.bowlingTeamId, 'team_a');
    });

    test('second innings swaps roles from first innings', () {
      const first = InningsModel(
        inningsNumber: 1,
        battingTeamId: 'team_a',
        bowlingTeamId: 'team_b',
      );
      final chase = TossTeamPolicy.chaseInningsTeams(first);
      expect(chase.battingTeamId, 'team_b');
      expect(chase.bowlingTeamId, 'team_a');
    });
  });
}
