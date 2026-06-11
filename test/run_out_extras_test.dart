import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/dismissal_fielder.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/scoring/ball_event_aggregator.dart';
import 'package:crickflow/domain/scoring/scoring_integrity_check.dart';
import 'package:crickflow/domain/services/scorecard_display_service.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:crickflow/features/scoring/presentation/utils/scoring_display_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = ScoringEngine();
  final aggregator = BallEventAggregator(engine: engine);

  const fielders = [
    DismissalFielder(playerId: 'fielder1', playerName: 'Fielder'),
  ];

  MatchModel baseMatch({MatchRulesModel? rules}) {
    return MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      rules: rules ?? const MatchRulesModel(wideRuns: 2, noBallRuns: 2),
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
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
  }

  BallEventInput runOut({
    int completedRuns = 0,
    RunOutDeliveryKind deliveryKind = RunOutDeliveryKind.normal,
    NoBallRunsMode? noBallRunsMode,
  }) {
    return BallEventInput(
      type: BallEventType.wicket,
      runs: completedRuns,
      wicketType: WicketType.runOut,
      dismissedPlayerId: 'striker',
      fielderId: 'fielder1',
      fielderName: 'Fielder',
      fielders: fielders,
      runOutDeliveryKind: deliveryKind,
      completedRuns: completedRuns,
      noBallRunsMode: noBallRunsMode,
    );
  }

  void assertExtrasBreakdown(MatchModel match, List<BallEventModel> events) {
    final inn = match.currentInnings!;
    final breakdown = ScorecardDisplayService.extrasBreakdown(
      innings: inn,
      events: events,
      rules: match.rules,
    );
    final sum = breakdown.wides +
        breakdown.noBalls +
        breakdown.byes +
        breakdown.legByes +
        breakdown.penalties;
    expect(
      sum,
      breakdown.total,
      reason: 'extras categories must sum to total '
          '(wd=${breakdown.wides} nb=${breakdown.noBalls} '
          'b=${breakdown.byes} lb=${breakdown.legByes} '
          'p=${breakdown.penalties} total=${breakdown.total})',
    );
    expect(breakdown.total, inn.extras);
  }

  group('Run out + extras accounting', () {
    final cases = <({
      String name,
      BallEventInput input,
      int expectedTotal,
      int expectedExtras,
      int expectedWide,
      int expectedNoBall,
      int expectedBye,
      int expectedLegBye,
      int expectedBatsmanRuns,
      String indicator,
      bool countsInOver,
    })>[
      (
        name: 'normal + run out',
        input: runOut(),
        expectedTotal: 0,
        expectedExtras: 0,
        expectedWide: 0,
        expectedNoBall: 0,
        expectedBye: 0,
        expectedLegBye: 0,
        expectedBatsmanRuns: 0,
        indicator: 'W',
        countsInOver: true,
      ),
      (
        name: 'normal + 1 + run out',
        input: runOut(completedRuns: 1),
        expectedTotal: 1,
        expectedExtras: 0,
        expectedWide: 0,
        expectedNoBall: 0,
        expectedBye: 0,
        expectedLegBye: 0,
        expectedBatsmanRuns: 1,
        indicator: 'W+1',
        countsInOver: true,
      ),
      (
        name: 'wide + run out',
        input: runOut(deliveryKind: RunOutDeliveryKind.wide),
        expectedTotal: 2,
        expectedExtras: 2,
        expectedWide: 2,
        expectedNoBall: 0,
        expectedBye: 0,
        expectedLegBye: 0,
        expectedBatsmanRuns: 0,
        indicator: 'Wd+W',
        countsInOver: true,
      ),
      (
        name: 'wide + 2 + run out',
        input: runOut(completedRuns: 2, deliveryKind: RunOutDeliveryKind.wide),
        expectedTotal: 4,
        expectedExtras: 4,
        expectedWide: 4,
        expectedNoBall: 0,
        expectedBye: 0,
        expectedLegBye: 0,
        expectedBatsmanRuns: 0,
        indicator: 'Wd+2+W',
        countsInOver: true,
      ),
      (
        name: 'no ball + run out',
        input: runOut(deliveryKind: RunOutDeliveryKind.noBall),
        expectedTotal: 2,
        expectedExtras: 2,
        expectedWide: 0,
        expectedNoBall: 2,
        expectedBye: 0,
        expectedLegBye: 0,
        expectedBatsmanRuns: 0,
        indicator: 'Nb+W',
        countsInOver: true,
      ),
      (
        name: 'no ball + 1 bat + run out',
        input: runOut(
          completedRuns: 1,
          deliveryKind: RunOutDeliveryKind.noBall,
          noBallRunsMode: NoBallRunsMode.bat,
        ),
        expectedTotal: 3,
        expectedExtras: 2,
        expectedWide: 0,
        expectedNoBall: 2,
        expectedBye: 0,
        expectedLegBye: 0,
        expectedBatsmanRuns: 1,
        indicator: 'Nb+1+W',
        countsInOver: true,
      ),
      (
        name: 'no ball + bye 2 + run out',
        input: runOut(
          completedRuns: 2,
          deliveryKind: RunOutDeliveryKind.noBall,
          noBallRunsMode: NoBallRunsMode.bye,
        ),
        expectedTotal: 4,
        expectedExtras: 4,
        expectedWide: 0,
        expectedNoBall: 2,
        expectedBye: 2,
        expectedLegBye: 0,
        expectedBatsmanRuns: 0,
        indicator: 'Nb+B2+W',
        countsInOver: true,
      ),
      (
        name: 'no ball + leg bye 2 + run out',
        input: runOut(
          completedRuns: 2,
          deliveryKind: RunOutDeliveryKind.noBall,
          noBallRunsMode: NoBallRunsMode.legBye,
        ),
        expectedTotal: 4,
        expectedExtras: 4,
        expectedWide: 0,
        expectedNoBall: 2,
        expectedBye: 0,
        expectedLegBye: 2,
        expectedBatsmanRuns: 0,
        indicator: 'Nb+LB2+W',
        countsInOver: true,
      ),
      (
        name: 'bye + run out',
        input: runOut(deliveryKind: RunOutDeliveryKind.bye),
        expectedTotal: 0,
        expectedExtras: 0,
        expectedWide: 0,
        expectedNoBall: 0,
        expectedBye: 0,
        expectedLegBye: 0,
        expectedBatsmanRuns: 0,
        indicator: 'W',
        countsInOver: true,
      ),
      (
        name: 'bye + 2 + run out',
        input: runOut(completedRuns: 2, deliveryKind: RunOutDeliveryKind.bye),
        expectedTotal: 2,
        expectedExtras: 2,
        expectedWide: 0,
        expectedNoBall: 0,
        expectedBye: 2,
        expectedLegBye: 0,
        expectedBatsmanRuns: 0,
        indicator: 'B2+W',
        countsInOver: true,
      ),
      (
        name: 'leg bye + 2 + run out',
        input: runOut(
          completedRuns: 2,
          deliveryKind: RunOutDeliveryKind.legBye,
        ),
        expectedTotal: 2,
        expectedExtras: 2,
        expectedWide: 0,
        expectedNoBall: 0,
        expectedBye: 0,
        expectedLegBye: 2,
        expectedBatsmanRuns: 0,
        indicator: 'LB2+W',
        countsInOver: true,
      ),
    ];

    for (final c in cases) {
      test(c.name, () {
        final match = baseMatch();
        final result = engine.recordBall(match: match, input: c.input, sequence: 1);
        final inn = result.match.currentInnings!;
        final events = [result.event];

        expect(inn.totalRuns, c.expectedTotal, reason: 'total runs');
        expect(inn.extras, c.expectedExtras, reason: 'extras total');
        expect(result.event.batsmanRuns, c.expectedBatsmanRuns);

        final breakdown = ScorecardDisplayService.extrasBreakdown(
          innings: inn,
          events: events,
          rules: match.rules,
        );
        expect(breakdown.wides, c.expectedWide);
        expect(breakdown.noBalls, c.expectedNoBall);
        expect(breakdown.byes, c.expectedBye);
        expect(breakdown.legByes, c.expectedLegBye);
        assertExtrasBreakdown(result.match, events);

        expect(
          ScoringDisplayUtils.ballBubbleLabel(result.event),
          c.indicator,
        );
        expect(result.event.countsInOver, c.countsInOver);
        expect(
          ScoringDisplayUtils.countsTowardOverDisplay(result.event),
          c.countsInOver,
        );

        final derived = aggregator.projectInnings(
          match: result.match,
          lineupInnings: match.innings.first,
          allEvents: events,
        );
        expect(derived.innings.totalRuns, inn.totalRuns);
        expect(derived.innings.extras, inn.extras);
        expect(derived.innings.totalWickets, inn.totalWickets);

        final replayed = engine.replayInnings(
          match: result.match,
          baseInnings: engine.baseInningsFrom(
            match.innings.first,
            events: events,
          ),
          events: events,
        );
        expect(replayed.currentInnings!.totalRuns, inn.totalRuns);
        expect(replayed.currentInnings!.extras, inn.extras);

        final issues = ScoringIntegrityCheck.verify(
          match: result.match,
          allEvents: events,
        );
        expect(issues, isEmpty, reason: issues.join('; '));
      });
    }
  });

  test('bye run out does not add runs against bowler', () {
    final result = engine.recordBall(
      match: baseMatch(),
      input: runOut(completedRuns: 2, deliveryKind: RunOutDeliveryKind.bye),
      sequence: 1,
    );
    expect(result.match.currentInnings!.bowlers.single.runsConceded, 0);
  });

  test('wide run out counts as wide for bowler', () {
    final result = engine.recordBall(
      match: baseMatch(),
      input: runOut(deliveryKind: RunOutDeliveryKind.wide),
      sequence: 1,
    );
    final bowler = result.match.currentInnings!.bowlers.single;
    expect(bowler.wides, 1);
    expect(bowler.runsConceded, 2);
  });
}
