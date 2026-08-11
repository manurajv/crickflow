import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/lineup_player.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/data/models/match_setup_draft_models.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:crickflow/features/scoring/presentation/widgets/change_bowler_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = ScoringEngine();

  MatchModel matchWith({
    MatchRulesModel rules = const MatchRulesModel(),
    String? currentBowlerId = 'bowler',
    String? currentWicketKeeperId,
    String? setupKeeperId = 'wk1',
  }) {
    return MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      rules: rules,
      setup: MatchSetupData(
        teamBWicketKeeperId: setupKeeperId,
      ),
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          strikerId: 'striker',
          nonStrikerId: 'non_striker',
          currentBowlerId: currentBowlerId,
          currentWicketKeeperId: currentWicketKeeperId,
          batsmen: const [
            BatsmanInningsModel(playerId: 'striker', playerName: 'S'),
            BatsmanInningsModel(playerId: 'non_striker', playerName: 'NS'),
          ],
          bowlers: [
            BowlerInningsModel(
              playerId: currentBowlerId ?? 'bowler',
              playerName: 'B',
            ),
          ],
        ),
      ],
    );
  }

  group('freeHitEnabled', () {
    test('defaults true and missing map field stays true', () {
      expect(const MatchRulesModel().freeHitEnabled, isTrue);
      expect(
        MatchRulesModel.fromMap(const {}).freeHitEnabled,
        isTrue,
      );
      expect(
        MatchRulesModel.fromMap(const {'freeHitEnabled': false}).freeHitEnabled,
        isFalse,
      );
    });

    test('no-ball sets free hit when enabled', () {
      var match = matchWith();
      final result = engine.recordBall(
        match: match,
        sequence: 1,
        input: const BallEventInput(type: BallEventType.noBall, runs: 1),
      );
      expect(result.match.currentInnings!.isFreeHitActive, isTrue);
    });

    test('no-ball does not set free hit when disabled', () {
      var match = matchWith(
        rules: const MatchRulesModel(freeHitEnabled: false),
      );
      final result = engine.recordBall(
        match: match,
        sequence: 1,
        input: const BallEventInput(type: BallEventType.noBall, runs: 1),
      );
      expect(result.match.currentInnings!.isFreeHitActive, isFalse);
      expect(result.match.currentInnings!.totalRuns, greaterThan(0));
    });

    test('consecutive no-balls stay without free hit when disabled', () {
      var match = matchWith(
        rules: const MatchRulesModel(freeHitEnabled: false),
      );
      for (var i = 1; i <= 3; i++) {
        final result = engine.recordBall(
          match: match,
          sequence: i,
          input: const BallEventInput(type: BallEventType.noBall, runs: 1),
        );
        match = result.match;
        expect(match.currentInnings!.isFreeHitActive, isFalse);
      }
    });
  });

  group('wicketKeeperCanBowl', () {
    test('defaults true and missing map field stays true', () {
      expect(const MatchRulesModel().wicketKeeperCanBowl, isTrue);
      expect(
        MatchRulesModel.fromMap(const {}).wicketKeeperCanBowl,
        isTrue,
      );
      expect(
        MatchRulesModel.fromMap(const {'wicketKeeperCanBowl': false})
            .wicketKeeperCanBowl,
        isFalse,
      );
    });

    test('keeper eligible when allowed', () {
      final match = matchWith(
        rules: const MatchRulesModel(wicketKeeperCanBowl: true),
      );
      final reason = ChangeBowlerSheet.ineligibility(
        player: const LineupPlayer(id: 'wk1', name: 'Keeper'),
        match: match,
        innings: match.currentInnings!,
        mode: BowlerPickMode.changeBowler,
        excludedBowlerIds: const {},
        wicketKeeperId: 'wk1',
      );
      expect(reason, BowlerIneligibility.none);
    });

    test('keeper ineligible when not allowed', () {
      final match = matchWith(
        rules: const MatchRulesModel(wicketKeeperCanBowl: false),
      );
      final reason = ChangeBowlerSheet.ineligibility(
        player: const LineupPlayer(id: 'wk1', name: 'Keeper'),
        match: match,
        innings: match.currentInnings!,
        mode: BowlerPickMode.nextOver,
        excludedBowlerIds: const {},
        wicketKeeperId: 'wk1',
      );
      expect(reason, BowlerIneligibility.wicketKeeper);
    });

    test('former keeper becomes eligible after keeper change', () {
      final match = matchWith(
        rules: const MatchRulesModel(wicketKeeperCanBowl: false),
        currentWicketKeeperId: 'wk2',
      );
      final former = ChangeBowlerSheet.ineligibility(
        player: const LineupPlayer(id: 'wk1', name: 'Old Keeper'),
        match: match,
        innings: match.currentInnings!,
        mode: BowlerPickMode.changeBowler,
        excludedBowlerIds: const {},
        wicketKeeperId: 'wk2',
      );
      final current = ChangeBowlerSheet.ineligibility(
        player: const LineupPlayer(id: 'wk2', name: 'New Keeper'),
        match: match,
        innings: match.currentInnings!,
        mode: BowlerPickMode.changeBowler,
        excludedBowlerIds: const {},
        wicketKeeperId: 'wk2',
      );
      expect(former, BowlerIneligibility.none);
      expect(current, BowlerIneligibility.wicketKeeper);
    });

    test('engine rejects assigning keeper as bowler when not allowed', () {
      final match = matchWith(
        rules: const MatchRulesModel(wicketKeeperCanBowl: false),
        currentWicketKeeperId: 'wk1',
        currentBowlerId: 'bowler',
      );
      expect(
        () => engine.recordBall(
          match: match,
          sequence: 1,
          input: const BallEventInput(
            type: BallEventType.lineupChange,
            creaseStrikerId: 'striker',
            creaseNonStrikerId: 'non_striker',
            bowlerId: 'wk1',
            bowlerName: 'Keeper',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Wicket keeper cannot bowl'),
          ),
        ),
      );
    });

    test('engine allows keeper as bowler when allowed', () {
      final match = matchWith(
        rules: const MatchRulesModel(wicketKeeperCanBowl: true),
        currentWicketKeeperId: 'wk1',
      );
      final result = engine.recordBall(
        match: match,
        sequence: 1,
        input: const BallEventInput(
          type: BallEventType.lineupChange,
          creaseStrikerId: 'striker',
          creaseNonStrikerId: 'non_striker',
          bowlerId: 'wk1',
          bowlerName: 'Keeper',
        ),
      );
      expect(result.match.currentInnings!.currentBowlerId, 'wk1');
    });
  });
}
