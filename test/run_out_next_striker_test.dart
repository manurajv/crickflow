import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/dismissal_fielder.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/scoring/scoring_integrity_check.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = ScoringEngine();

  MatchModel baseMatch({int legalBalls = 0}) {
    return MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      rules: const MatchRulesModel(),
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          legalBalls: legalBalls,
          strikerId: 'striker',
          nonStrikerId: 'non_striker',
          currentBowlerId: 'bowler',
          batsmen: const [
            BatsmanInningsModel(playerId: 'striker', playerName: 'Striker'),
            BatsmanInningsModel(
              playerId: 'non_striker',
              playerName: 'Non-striker',
            ),
            BatsmanInningsModel(playerId: 'batter3', playerName: 'Batter 3'),
            BatsmanInningsModel(playerId: 'batter4', playerName: 'Batter 4'),
          ],
          bowlers: const [
            BowlerInningsModel(playerId: 'bowler', playerName: 'Bowler'),
          ],
        ),
      ],
    );
  }

  const fielders = [
    DismissalFielder(playerId: 'fielder1', playerName: 'Fielder'),
  ];

  BallEventInput runOut({
    required String dismissed,
    int runs = 0,
    RunOutDeliveryKind deliveryKind = RunOutDeliveryKind.normal,
    NoBallRunsMode? noBallRunsMode,
    String? nextStrikerId,
    String? nextStrikerName,
  }) {
    return BallEventInput(
      type: BallEventType.wicket,
      runs: runs,
      wicketType: WicketType.runOut,
      dismissedPlayerId: dismissed,
      fielderId: 'fielder1',
      fielderName: 'Fielder',
      fielders: fielders,
      runOutDeliveryKind: deliveryKind,
      completedRuns: runs,
      noBallRunsMode: noBallRunsMode,
      nextStrikerId: nextStrikerId,
      nextStrikerName: nextStrikerName,
    );
  }

  BallEventInput lineup({
    required String strikerId,
    required String nonStrikerId,
  }) {
    return BallEventInput(
      type: BallEventType.lineupChange,
      creaseStrikerId: strikerId,
      creaseNonStrikerId: nonStrikerId,
      creaseStrikerName: strikerId,
      creaseNonStrikerName: nonStrikerId,
      bowlerId: 'bowler',
      bowlerName: 'Bowler',
    );
  }

  MatchModel applyRunOutFlow(
    MatchModel start,
    List<BallEventInput> inputs,
  ) {
    var match = start;
    final events = <BallEventModel>[];
    for (var i = 0; i < inputs.length; i++) {
      final result = engine.recordBall(
        match: match,
        input: inputs[i],
        sequence: i + 1,
      );
      match = result.match;
      events.add(result.event);
      final issues = ScoringIntegrityCheck.verify(
        match: match,
        allEvents: events,
      );
      expect(issues, isEmpty, reason: issues.join('; '));
    }
    return match;
  }

  void expectCrease(
    MatchModel match, {
    required String strikerId,
    required String nonStrikerId,
  }) {
    final inn = match.currentInnings!;
    expect(inn.strikerId, strikerId, reason: 'striker');
    expect(inn.nonStrikerId, nonStrikerId, reason: 'non-striker');
  }

  group('run-out explicit next-ball striker', () {
    test('striker run out 0 runs — surviving batter faces next', () {
      final match = applyRunOutFlow(baseMatch(), [
        runOut(dismissed: 'striker', nextStrikerId: 'non_striker'),
        lineup(strikerId: 'non_striker', nonStrikerId: 'batter3'),
      ]);
      expectCrease(match, strikerId: 'non_striker', nonStrikerId: 'batter3');
    });

    test('striker run out 0 runs — new batter faces next', () {
      final match = applyRunOutFlow(baseMatch(), [
        runOut(dismissed: 'striker', nextStrikerId: 'batter3'),
        lineup(strikerId: 'batter3', nonStrikerId: 'non_striker'),
      ]);
      expectCrease(match, strikerId: 'batter3', nonStrikerId: 'non_striker');
    });

    test('non-striker run out 0 runs — surviving batter faces next', () {
      final match = applyRunOutFlow(baseMatch(), [
        runOut(dismissed: 'non_striker', nextStrikerId: 'striker'),
        lineup(strikerId: 'striker', nonStrikerId: 'batter3'),
      ]);
      expectCrease(match, strikerId: 'striker', nonStrikerId: 'batter3');
    });

    test('non-striker run out 0 runs — new batter faces next', () {
      final match = applyRunOutFlow(baseMatch(), [
        runOut(dismissed: 'non_striker', nextStrikerId: 'batter3'),
        lineup(strikerId: 'batter3', nonStrikerId: 'striker'),
      ]);
      expectCrease(match, strikerId: 'batter3', nonStrikerId: 'striker');
    });

    test('striker run out after 1 run — surviving batter faces next', () {
      final match = applyRunOutFlow(baseMatch(), [
        runOut(dismissed: 'striker', runs: 1, nextStrikerId: 'non_striker'),
        lineup(strikerId: 'non_striker', nonStrikerId: 'batter3'),
      ]);
      expectCrease(match, strikerId: 'non_striker', nonStrikerId: 'batter3');
      expect(match.currentInnings!.totalRuns, 1);
    });

    test('striker run out after 1 run — new batter faces next', () {
      final match = applyRunOutFlow(baseMatch(), [
        runOut(dismissed: 'striker', runs: 1, nextStrikerId: 'batter3'),
        lineup(strikerId: 'batter3', nonStrikerId: 'non_striker'),
      ]);
      expectCrease(match, strikerId: 'batter3', nonStrikerId: 'non_striker');
    });

    test('striker run out after 2 runs — surviving batter faces next', () {
      final match = applyRunOutFlow(baseMatch(), [
        runOut(dismissed: 'striker', runs: 2, nextStrikerId: 'non_striker'),
        lineup(strikerId: 'non_striker', nonStrikerId: 'batter3'),
      ]);
      expectCrease(match, strikerId: 'non_striker', nonStrikerId: 'batter3');
      expect(match.currentInnings!.totalRuns, 2);
    });

    test('non-striker run out after 1 run — surviving batter faces next', () {
      final match = applyRunOutFlow(baseMatch(), [
        runOut(dismissed: 'non_striker', runs: 1, nextStrikerId: 'striker'),
        lineup(strikerId: 'striker', nonStrikerId: 'batter3'),
      ]);
      expectCrease(match, strikerId: 'striker', nonStrikerId: 'batter3');
    });
  });

  group('run-out extras preserve explicit crease', () {
    final extrasCases = <({
      String name,
      BallEventInput wicket,
      String strikerId,
      String nonStrikerId,
      int expectedRuns,
    })>[
      (
        name: 'wide',
        wicket: runOut(
          dismissed: 'striker',
          deliveryKind: RunOutDeliveryKind.wide,
          nextStrikerId: 'batter3',
        ),
        strikerId: 'batter3',
        nonStrikerId: 'non_striker',
        expectedRuns: 1,
      ),
      (
        name: 'no ball from bat',
        wicket: runOut(
          dismissed: 'striker',
          runs: 2,
          deliveryKind: RunOutDeliveryKind.noBall,
          noBallRunsMode: NoBallRunsMode.bat,
          nextStrikerId: 'non_striker',
        ),
        strikerId: 'non_striker',
        nonStrikerId: 'batter3',
        expectedRuns: 3,
      ),
      (
        name: 'no ball bye',
        wicket: runOut(
          dismissed: 'striker',
          runs: 1,
          deliveryKind: RunOutDeliveryKind.noBall,
          noBallRunsMode: NoBallRunsMode.bye,
          nextStrikerId: 'batter3',
        ),
        strikerId: 'batter3',
        nonStrikerId: 'non_striker',
        expectedRuns: 2,
      ),
      (
        name: 'no ball leg bye',
        wicket: runOut(
          dismissed: 'striker',
          runs: 1,
          deliveryKind: RunOutDeliveryKind.noBall,
          noBallRunsMode: NoBallRunsMode.legBye,
          nextStrikerId: 'batter3',
        ),
        strikerId: 'batter3',
        nonStrikerId: 'non_striker',
        expectedRuns: 2,
      ),
      (
        name: 'bye',
        wicket: runOut(
          dismissed: 'striker',
          runs: 2,
          deliveryKind: RunOutDeliveryKind.bye,
          nextStrikerId: 'non_striker',
        ),
        strikerId: 'non_striker',
        nonStrikerId: 'batter3',
        expectedRuns: 2,
      ),
      (
        name: 'leg bye',
        wicket: runOut(
          dismissed: 'striker',
          runs: 2,
          deliveryKind: RunOutDeliveryKind.legBye,
          nextStrikerId: 'non_striker',
        ),
        strikerId: 'non_striker',
        nonStrikerId: 'batter3',
        expectedRuns: 2,
      ),
    ];

    for (final c in extrasCases) {
      test(c.name, () {
        final match = applyRunOutFlow(baseMatch(), [
          c.wicket,
          lineup(strikerId: c.strikerId, nonStrikerId: c.nonStrikerId),
        ]);
        expectCrease(
          match,
          strikerId: c.strikerId,
          nonStrikerId: c.nonStrikerId,
        );
        expect(match.currentInnings!.totalRuns, c.expectedRuns);
      });
    }
  });

  group('run-out over completion', () {
    test('last ball run out + explicit lineup + preserve end-over keeps striker',
        () {
      final priorBalls = List.generate(
        5,
        (_) => const BallEventInput(type: BallEventType.runs, runs: 0),
      );
      final match = applyRunOutFlow(baseMatch(), [
        ...priorBalls,
        runOut(dismissed: 'striker', nextStrikerId: 'batter3'),
        lineup(strikerId: 'batter3', nonStrikerId: 'non_striker'),
        const BallEventInput(
          type: BallEventType.endOver,
          preserveCreaseOnEndOver: true,
        ),
      ]);
      expect(match.currentInnings!.legalBalls, 6);
      expectCrease(match, strikerId: 'batter3', nonStrikerId: 'non_striker');
    });

    test('end-over without preserve swaps after explicit run-out lineup', () {
      final priorBalls = List.generate(
        5,
        (_) => const BallEventInput(type: BallEventType.runs, runs: 0),
      );
      final match = applyRunOutFlow(baseMatch(), [
        ...priorBalls,
        runOut(dismissed: 'striker', nextStrikerId: 'batter3'),
        lineup(strikerId: 'batter3', nonStrikerId: 'non_striker'),
        const BallEventInput(type: BallEventType.endOver),
      ]);
      expectCrease(match, strikerId: 'non_striker', nonStrikerId: 'batter3');
    });

    test('new batter as next-ball striker on over completion is preserved', () {
      final priorBalls = List.generate(
        5,
        (_) => const BallEventInput(type: BallEventType.runs, runs: 0),
      );
      final match = applyRunOutFlow(baseMatch(), [
        ...priorBalls,
        runOut(
          dismissed: 'non_striker',
          runs: 1,
          nextStrikerId: 'batter3',
        ),
        lineup(strikerId: 'batter3', nonStrikerId: 'striker'),
        const BallEventInput(
          type: BallEventType.endOver,
          preserveCreaseOnEndOver: true,
        ),
      ]);
      expectCrease(match, strikerId: 'batter3', nonStrikerId: 'striker');
    });
  });
}
