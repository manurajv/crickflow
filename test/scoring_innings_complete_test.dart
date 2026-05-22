import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_setup_draft_models.dart';
import 'package:crickflow/features/scoring/presentation/utils/scoring_display_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MatchModel matchWithSquad(int squadSize, {int wickets = 0, int legalBalls = 0}) {
    final ids = List.generate(squadSize, (i) => 'p$i');
    return MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      setup: MatchSetupData(
        teamASquadIds: ids,
        teamBSquadIds: const ['b1'],
      ),
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          totalWickets: wickets,
          legalBalls: legalBalls,
        ),
      ],
    );
  }

  test('11 player squad all out at 10 wickets', () {
    final match = matchWithSquad(11, wickets: 10);
    final inn = match.currentInnings!;
    expect(ScoringDisplayUtils.maxDismissals(match, inn), 10);
    expect(ScoringDisplayUtils.isAllOut(match, inn), isTrue);
    expect(ScoringDisplayUtils.inningsCompleteReason(match, inn), 'All out');
  });

  test('overs complete at 20 overs x 6 balls', () {
    final match = matchWithSquad(11, legalBalls: 120);
    final inn = match.currentInnings!;
    expect(ScoringDisplayUtils.isOversComplete(match, inn), isTrue);
    expect(ScoringDisplayUtils.isInningsComplete(match, inn), isTrue);
  });

  test('all out when no batters available to fill vacant crease', () {
    final ids = List.generate(11, (i) => 'p$i');
    final outBatters = List.generate(
      10,
      (i) => BatsmanInningsModel(playerId: 'p$i', isOut: true),
    );
    final match = MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      setup: MatchSetupData(
        teamASquadIds: ids,
        teamBSquadIds: const ['b1'],
      ),
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          totalWickets: 9,
          strikerId: null,
          nonStrikerId: 'p10',
          batsmen: [
            ...outBatters,
            const BatsmanInningsModel(playerId: 'p10', isOut: false),
          ],
        ),
      ],
    );
    final inn = match.currentInnings!;
    expect(ScoringDisplayUtils.noBattersAvailable(match, inn), isTrue);
    expect(ScoringDisplayUtils.isAllOut(match, inn), isTrue);
    expect(ScoringDisplayUtils.isInningsComplete(match, inn), isTrue);
  });

  test('cannot undo after innings marked complete', () {
    final match = MatchModel(
      id: 'm1',
      title: 'Test',
      status: MatchStatus.inningsBreak,
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
        ),
      ],
    );
    expect(ScoringDisplayUtils.canUndoInnings(match), isFalse);
  });
}
