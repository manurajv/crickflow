import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/scoring/ball_event_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = MatchRulesModel.standardT20();

  MatchModel _matchWithInnings(InningsModel innings) {
    return MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'ta',
      teamBId: 'tb',
      teamAName: 'Team A',
      teamBName: 'Team B',
      rules: rules,
      innings: [innings],
      currentInningsIndex: 0,
      status: MatchStatus.live,
    );
  }

  InningsModel _baseInnings() {
    return InningsModel(
      inningsNumber: 1,
      battingTeamId: 'ta',
      bowlingTeamId: 'tb',
      status: InningsStatus.inProgress,
      strikerId: 'b1',
      nonStrikerId: 'b2',
      currentBowlerId: 'bowl1',
      batsmen: const [
        BatsmanInningsModel(playerId: 'b1', playerName: 'Striker'),
        BatsmanInningsModel(playerId: 'b2', playerName: 'NonStriker'),
      ],
      bowlers: const [
        BowlerInningsModel(playerId: 'bowl1', playerName: 'Bowler'),
      ],
    );
  }

  BallEventModel _event({
    required int sequence,
    required BallEventType type,
    int runs = 0,
    int batsmanRuns = 0,
    int extraRuns = 0,
    bool isLegal = true,
    DateTime? timestamp,
    String? dismissedId,
    WicketType? wicketType,
  }) {
    return BallEventModel(
      id: 'e$sequence',
      matchId: 'm1',
      inningsNumber: 1,
      overNumber: 0,
      ballInOver: sequence,
      eventType: type,
      runs: runs,
      batsmanRuns: batsmanRuns,
      extraRuns: extraRuns,
      isLegalDelivery: isLegal,
      strikerId: 'b1',
      nonStrikerId: 'b2',
      bowlerId: 'bowl1',
      timestamp: timestamp,
      sequence: sequence,
      dismissedPlayerId: dismissedId,
      wicketType: wicketType,
      isWicket: type == BallEventType.wicket,
    );
  }

  group('BallEventAggregator.batterMinutesFromEvents', () {
    test('computes minutes for dismissed and not-out batters', () {
      final t0 = DateTime(2026, 6, 1, 14, 0);
      final t15 = t0.add(const Duration(minutes: 15));
      final t30 = t0.add(const Duration(minutes: 30));
      final now = t0.add(const Duration(minutes: 45));

      final events = [
        _event(
          sequence: 1,
          type: BallEventType.runs,
          runs: 1,
          batsmanRuns: 1,
          timestamp: t0,
        ),
        _event(
          sequence: 2,
          type: BallEventType.wicket,
          dismissedId: 'b1',
          wicketType: WicketType.bowled,
          timestamp: t15,
        ),
        _event(
          sequence: 3,
          type: BallEventType.runs,
          runs: 4,
          batsmanRuns: 4,
          timestamp: t30,
        ),
      ];

      final mins = BallEventAggregator.batterMinutesFromEvents(
        events,
        creaseIds: {'b2'},
        now: now,
      );

      expect(mins['b1'], 15);
      expect(mins['b2'], 45);
    });
  });

  group('BallEventAggregator.maidenOversFromEvents', () {
    test('counts maiden when bowler concedes zero in a legal over', () {
      final events = [
        _event(sequence: 1, type: BallEventType.runs, runs: 0, batsmanRuns: 0),
        _event(sequence: 2, type: BallEventType.runs, runs: 0, batsmanRuns: 0),
        _event(sequence: 3, type: BallEventType.runs, runs: 0, batsmanRuns: 0),
        _event(sequence: 4, type: BallEventType.runs, runs: 0, batsmanRuns: 0),
        _event(sequence: 5, type: BallEventType.runs, runs: 0, batsmanRuns: 0),
        _event(sequence: 6, type: BallEventType.runs, runs: 0, batsmanRuns: 0),
      ];

      final maidens =
          BallEventAggregator.maidenOversFromEvents(events, rules);
      expect(maidens['bowl1'], 1);
    });

    test('no maiden when runs conceded in over', () {
      final events = [
        _event(sequence: 1, type: BallEventType.runs, runs: 4, batsmanRuns: 4),
        _event(sequence: 2, type: BallEventType.runs, runs: 0, batsmanRuns: 0),
      ];

      final maidens =
          BallEventAggregator.maidenOversFromEvents(events, rules);
      expect(maidens['bowl1'], isNull);
    });
  });

  group('BallEventAggregator derived lists', () {
    test('fallOfWickets and fielders from wicket events', () {
      final t0 = DateTime(2026, 6, 1, 14, 0);
      final events = [
        BallEventModel(
          id: 'e1',
          matchId: 'm1',
          inningsNumber: 1,
          overNumber: 0,
          ballInOver: 1,
          eventType: BallEventType.wicket,
          isWicket: true,
          wicketType: WicketType.caught,
          dismissedPlayerId: 'b1',
          fielderId: 'f1',
          fielderName: 'Fielder',
          dismissalText: 'c Fielder b Bowler',
          strikerId: 'b1',
          nonStrikerId: 'b2',
          timestamp: t0,
          sequence: 1,
        ),
      ];
      final names = {'b1': 'Batter One'};
      expect(
        BallEventAggregator.fallOfWicketsFromEvents(events, names).single
            .dismissal,
        'c Fielder b Bowler',
      );
      expect(
        BallEventAggregator.fieldersFromEvents(events).single.catches,
        1,
      );
    });
  });

  group('BallEventAggregator.projectInnings', () {
    test('replay matches event totals for batting and team score', () {
      final innings = _baseInnings();
      final match = _matchWithInnings(innings);
      final events = [
        _event(sequence: 1, type: BallEventType.runs, runs: 4, batsmanRuns: 4),
        _event(sequence: 2, type: BallEventType.runs, runs: 6, batsmanRuns: 6),
        _event(
          sequence: 3,
          type: BallEventType.wide,
          runs: 1,
          extraRuns: 1,
          isLegal: false,
        ),
      ];

      final proj = BallEventAggregator().projectInnings(
        match: match,
        lineupInnings: innings,
        allEvents: events,
      );

      expect(proj.innings.totalRuns, 11);
      expect(proj.innings.batsmen.first.runs, 10);
      expect(proj.innings.batsmen.first.fours, 1);
      expect(proj.innings.batsmen.first.sixes, 1);
      expect(proj.extrasBreakdown.wides, 1);
    });
  });

  group('BallEventAggregator.overSymbols', () {
    test('builds over symbols from events', () {
      final events = [
        _event(sequence: 1, type: BallEventType.runs, runs: 4, batsmanRuns: 4),
        _event(
          sequence: 2,
          type: BallEventType.wicket,
          dismissedId: 'b1',
          wicketType: WicketType.caught,
        ),
      ];

      final symbols = BallEventAggregator.overSymbols(events, rules);
      expect(symbols[0], ['4', 'W']);
    });

    test('run out with runs shows W+runs in over symbols', () {
      final events = [
        _event(
          sequence: 1,
          type: BallEventType.wicket,
          dismissedId: 'b1',
          wicketType: WicketType.runOut,
          runs: 1,
          batsmanRuns: 1,
        ),
      ];

      final symbols = BallEventAggregator.overSymbols(events, rules);
      expect(symbols[0], ['W+1']);
    });
  });
}
