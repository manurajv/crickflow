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
    String strikerId = 'b1',
    String nonStrikerId = 'b2',
    bool? isWicket,
    bool retiredHurt = false,
    bool countsInOver = true,
    bool countsToBowler = true,
    int overNumber = 0,
    String bowlerId = 'bowl1',
  }) {
    final resolvedIsWicket = isWicket ??
        (type == BallEventType.wicket &&
            wicketType != WicketType.retiredHurt &&
            !retiredHurt);
    return BallEventModel(
      id: 'e$sequence',
      matchId: 'm1',
      inningsNumber: 1,
      overNumber: overNumber,
      ballInOver: sequence,
      eventType: type,
      runs: runs,
      batsmanRuns: batsmanRuns,
      extraRuns: extraRuns,
      isLegalDelivery: isLegal,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      bowlerId: bowlerId,
      timestamp: timestamp,
      sequence: sequence,
      dismissedPlayerId: dismissedId,
      wicketType: wicketType,
      isWicket: resolvedIsWicket,
      retiredHurt: retiredHurt || wicketType == WicketType.retiredHurt,
      isEligibleToReturn: retiredHurt || wicketType == WicketType.retiredHurt,
      countsInOver: countsInOver,
      countsToBowler: countsToBowler,
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

    test('does not count an incomplete zero-run over', () {
      final events = [
        _event(sequence: 1, type: BallEventType.runs),
        _event(sequence: 2, type: BallEventType.runs),
      ];

      final maidens =
          BallEventAggregator.maidenOversFromEvents(events, rules);
      expect(maidens, isEmpty);
    });

    test('uses custom balls per over and ignores split overs', () {
      const fourBallRules = MatchRulesModel(ballsPerOver: 4);
      final events = [
        for (var i = 1; i <= 4; i++)
          _event(
            sequence: i,
            type: BallEventType.runs,
            overNumber: 0,
          ),
        for (var i = 5; i <= 8; i++)
          _event(
            sequence: i,
            type: BallEventType.runs,
            overNumber: 1,
            bowlerId: i < 7 ? 'bowl1' : 'bowl2',
          ),
      ];

      final maidens = BallEventAggregator.maidenOversFromEvents(
        events,
        fourBallRules,
      );
      expect(maidens['bowl1'], 1);
      expect(maidens['bowl2'], isNull);
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

  group('Retired Hurt / Retired Out partnerships & FOW', () {
    test('RH does not close partnership or create FOW; stand continues', () {
      final names = {
        'b1': 'Alice',
        'b2': 'Bob',
        'b3': 'Chris',
      };
      final events = [
        _event(
          sequence: 1,
          type: BallEventType.runs,
          runs: 4,
          batsmanRuns: 4,
        ),
        _event(
          sequence: 2,
          type: BallEventType.runs,
          runs: 2,
          batsmanRuns: 2,
        ),
        // Alice retires hurt — partnership must continue.
        _event(
          sequence: 3,
          type: BallEventType.wicket,
          dismissedId: 'b1',
          wicketType: WicketType.retiredHurt,
          isWicket: false,
          retiredHurt: true,
          countsInOver: false,
          isLegal: false,
        ),
        BallEventModel(
          id: 'e4',
          matchId: 'm1',
          inningsNumber: 1,
          overNumber: 0,
          ballInOver: 0,
          eventType: BallEventType.lineupChange,
          strikerId: 'b3',
          nonStrikerId: 'b2',
          sequence: 4,
          countsInOver: false,
          isLegalDelivery: false,
        ),
        _event(
          sequence: 5,
          type: BallEventType.runs,
          runs: 3,
          batsmanRuns: 3,
          strikerId: 'b3',
          nonStrikerId: 'b2',
        ),
        // Bob out — closes the continuous partnership (6+3=9).
        _event(
          sequence: 6,
          type: BallEventType.wicket,
          dismissedId: 'b2',
          wicketType: WicketType.bowled,
          strikerId: 'b3',
          nonStrikerId: 'b2',
        ),
      ];

      final fow =
          BallEventAggregator.fallOfWicketsFromEvents(events, names);
      expect(fow, hasLength(1));
      expect(fow.single.batsmanId, 'b2');
      expect(fow.single.wicketNumber, 1);

      final parts =
          BallEventAggregator.partnershipsFromEvents(events, names);
      expect(parts, hasLength(1));
      expect(parts.single.runs, 9);
      expect(parts.single.balls, 4); // 2 before RH + 1 after + wicket ball
      // Current crease pair at the closing wicket.
      expect(
        {parts.single.batterAId, parts.single.batterBId},
        {'b2', 'b3'},
      );
    });

    test('RH without retiredHurt flag still excluded via wicketType', () {
      final names = {'b1': 'Alice', 'b2': 'Bob'};
      final events = [
        _event(sequence: 1, type: BallEventType.runs, runs: 1, batsmanRuns: 1),
        BallEventModel(
          id: 'e2',
          matchId: 'm1',
          inningsNumber: 1,
          overNumber: 0,
          ballInOver: 2,
          eventType: BallEventType.wicket,
          wicketType: WicketType.retiredHurt,
          dismissedPlayerId: 'b1',
          strikerId: 'b1',
          nonStrikerId: 'b2',
          // Legacy / partial write: flag missing, isWicket wrongly true.
          retiredHurt: false,
          isWicket: true,
          sequence: 2,
          countsInOver: false,
          isLegalDelivery: false,
        ),
      ];

      expect(
        BallEventAggregator.fallOfWicketsFromEvents(events, names),
        isEmpty,
      );
      expect(
        BallEventAggregator.partnershipsFromEvents(events, names),
        isEmpty,
      );
    });

    test('RO closes partnership, creates FOW, no fielder credit', () {
      final names = {'b1': 'Alice', 'b2': 'Bob'};
      final events = [
        _event(sequence: 1, type: BallEventType.runs, runs: 5, batsmanRuns: 5),
        _event(
          sequence: 2,
          type: BallEventType.wicket,
          dismissedId: 'b1',
          wicketType: WicketType.retiredOut,
          isWicket: true,
          countsInOver: false,
          isLegal: false,
        ),
      ];

      final fow =
          BallEventAggregator.fallOfWicketsFromEvents(events, names);
      expect(fow, hasLength(1));
      expect(fow.single.batsmanId, 'b1');

      final parts =
          BallEventAggregator.partnershipsFromEvents(events, names);
      expect(parts, hasLength(1));
      expect(parts.single.runs, 5);

      expect(BallEventAggregator.fieldersFromEvents(events), isEmpty);
    });
  });
}
