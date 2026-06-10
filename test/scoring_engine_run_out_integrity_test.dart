import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/dismissal_fielder.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/scoring/ball_event_aggregator.dart';
import 'package:crickflow/domain/scoring/scoring_integrity_check.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = ScoringEngine();
  final aggregator = BallEventAggregator(engine: engine);

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
            BowlerInningsModel(playerId: 'bowler2', playerName: 'Bowler 2'),
          ],
        ),
      ],
    );
  }

  const runOutFielders = [
    DismissalFielder(playerId: 'fielder1', playerName: 'Fielder'),
  ];

  BallEventInput runOut({
    required String dismissed,
    int runs = 0,
  }) {
    return BallEventInput(
      type: BallEventType.wicket,
      runs: runs,
      wicketType: WicketType.runOut,
      dismissedPlayerId: dismissed,
      fielderId: 'fielder1',
      fielderName: 'Fielder',
      fielders: runOutFielders,
    );
  }

  BallEventInput lineupChange({
    required String strikerId,
    required String nonStrikerId,
  }) {
    return BallEventInput(
      type: BallEventType.lineupChange,
      creaseStrikerId: strikerId,
      creaseNonStrikerId: nonStrikerId,
      creaseStrikerName: strikerId == 'striker'
          ? 'Striker'
          : strikerId == 'batter3'
              ? 'Batter 3'
              : 'Batter 4',
      creaseNonStrikerName: nonStrikerId == 'non_striker'
          ? 'Non-striker'
          : nonStrikerId == 'batter3'
              ? 'Batter 3'
              : 'Batter 4',
      bowlerId: 'bowler',
      bowlerName: 'Bowler',
    );
  }

  void assertIntegrity(MatchModel match, List<BallEventModel> events) {
    final issues = ScoringIntegrityCheck.verify(
      match: match,
      allEvents: events,
    );
    expect(issues, isEmpty, reason: issues.join('; '));
  }

  ScoringInput recordSequence(
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
      assertIntegrity(match, events);
    }
    return ScoringInput(
      match: match,
      event: events.last,
      overlay: engine.buildOverlayForMatch(match),
    );
  }

  test('run out striker 0 runs + lineup + next ball passes integrity', () {
    final result = recordSequence(baseMatch(), [
      runOut(dismissed: 'striker'),
      lineupChange(strikerId: 'batter3', nonStrikerId: 'non_striker'),
      const BallEventInput(type: BallEventType.runs, runs: 1),
    ]);

    final inn = result.match.currentInnings!;
    expect(inn.totalWickets, 1);
    expect(inn.strikerId, 'non_striker');
    expect(inn.nonStrikerId, 'batter3');
    expect(inn.totalRuns, 1);
    expect(inn.legalBalls, 2);
  });

  test('run out striker after 1 run rotates ends before dismissal', () {
    final result = recordSequence(baseMatch(), [
      runOut(dismissed: 'striker', runs: 1),
      lineupChange(strikerId: 'batter3', nonStrikerId: 'non_striker'),
    ]);

    final inn = result.match.currentInnings!;
    expect(inn.totalRuns, 1);
    expect(inn.strikerId, 'batter3');
    expect(inn.nonStrikerId, 'non_striker');
    final strikerStats =
        inn.batsmen.firstWhere((b) => b.playerId == 'striker');
    expect(strikerStats.runs, 1);
    expect(strikerStats.balls, 1);
  });

  test('run out striker after 2 runs keeps ends', () {
    final result = recordSequence(baseMatch(), [
      runOut(dismissed: 'striker', runs: 2),
      lineupChange(strikerId: 'batter3', nonStrikerId: 'non_striker'),
    ]);

    final inn = result.match.currentInnings!;
    expect(inn.totalRuns, 2);
    expect(inn.strikerId, 'batter3');
    expect(inn.nonStrikerId, 'non_striker');
  });

  test('run out non-striker 0 runs', () {
    final result = recordSequence(baseMatch(), [
      runOut(dismissed: 'non_striker'),
      lineupChange(strikerId: 'striker', nonStrikerId: 'batter3'),
    ]);

    final inn = result.match.currentInnings!;
    expect(inn.strikerId, 'striker');
    expect(inn.nonStrikerId, 'batter3');
    expect(inn.batsmen.firstWhere((b) => b.playerId == 'non_striker').isOut,
        isTrue);
  });

  test('run out non-striker after 1 run', () {
    final result = recordSequence(baseMatch(), [
      runOut(dismissed: 'non_striker', runs: 1),
      lineupChange(strikerId: 'striker', nonStrikerId: 'batter3'),
    ]);

    final inn = result.match.currentInnings!;
    expect(inn.totalRuns, 1);
    expect(inn.strikerId, 'striker');
    expect(inn.nonStrikerId, 'batter3');
  });

  test('run out on last ball of over rotates at end of over', () {
    final priorBalls = List.generate(
      5,
      (_) => const BallEventInput(type: BallEventType.runs, runs: 0),
    );
    final result = recordSequence(baseMatch(), [
      ...priorBalls,
      runOut(dismissed: 'striker'),
      lineupChange(strikerId: 'batter3', nonStrikerId: 'non_striker'),
    ]);

    final inn = result.match.currentInnings!;
    expect(inn.legalBalls, 6);
    // Wicket on last ball leaves crease incomplete — no end-of-over swap yet.
    expect(inn.strikerId, 'batter3');
    expect(inn.nonStrikerId, 'non_striker');
  });

  test('lineup change for next-over bowler is replay-safe', () {
    final priorBalls = List.generate(
      6,
      (_) => const BallEventInput(type: BallEventType.runs, runs: 0),
    );
    final result = recordSequence(baseMatch(), [
      ...priorBalls,
      BallEventInput(
        type: BallEventType.lineupChange,
        creaseStrikerId: 'non_striker',
        creaseNonStrikerId: 'striker',
        creaseStrikerName: 'Non-striker',
        creaseNonStrikerName: 'Striker',
        bowlerId: 'bowler2',
        bowlerName: 'Bowler 2',
      ),
    ]);

    final inn = result.match.currentInnings!;
    expect(inn.currentBowlerId, 'bowler2');
    expect(inn.legalBalls, 6);
  });

  test('replay after run out + lineup matches live cache', () {
    final match = baseMatch();
    var m = match;
    final allEvents = <BallEventModel>[];
    final inputs = [
      runOut(dismissed: 'striker'),
      lineupChange(strikerId: 'batter3', nonStrikerId: 'non_striker'),
      const BallEventInput(type: BallEventType.runs, runs: 4),
    ];
    for (var i = 0; i < inputs.length; i++) {
      final r = engine.recordBall(match: m, input: inputs[i], sequence: i + 1);
      m = r.match;
      allEvents.add(r.event);
    }

    final derived = aggregator.projectInnings(
      match: m,
      lineupInnings: match.innings.first,
      allEvents: allEvents,
    );
    final live = m.currentInnings!;
    expect(derived.innings.strikerId, live.strikerId);
    expect(derived.innings.nonStrikerId, live.nonStrikerId);
    expect(derived.innings.totalRuns, live.totalRuns);
    expect(derived.innings.totalWickets, live.totalWickets);
    assertIntegrity(m, allEvents);
  });

  test('chase innings run out maintains target context', () {
    final chaseMatch = MatchModel(
      id: 'm2',
      title: 'Chase',
      teamAId: 'a',
      teamBId: 'b',
      rules: const MatchRulesModel(),
      currentInningsIndex: 1,
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 120,
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.inProgress,
          targetRuns: 121,
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
          ],
          bowlers: const [
            BowlerInningsModel(playerId: 'bowler', playerName: 'Bowler'),
          ],
        ),
      ],
    );

    final result = recordSequence(chaseMatch, [
      runOut(dismissed: 'striker', runs: 1),
      lineupChange(strikerId: 'batter3', nonStrikerId: 'non_striker'),
    ]);

    expect(result.match.currentInnings!.targetRuns, 121);
    expect(result.match.currentInnings!.totalRuns, 1);
  });
}
