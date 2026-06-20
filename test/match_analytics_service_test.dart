import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/services/match_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = MatchAnalyticsService();

  MatchModel baseMatch({
    CricketMatchType type = CricketMatchType.limitedOvers,
    int ballsPerOver = 6,
  }) {
    return MatchModel(
      id: 'm1',
      title: 'Team A vs Team B',
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      status: MatchStatus.live,
      rules: MatchRulesModel(
        cricketMatchType: type,
        ballsPerOver: ballsPerOver,
        totalOvers: 20,
        wagonWheelEnabled: true,
      ),
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          totalRuns: 8,
          legalBalls: 6,
        ),
      ],
    );
  }

  BallEventModel runEvent({
    required int sequence,
    required int over,
    required int ball,
    int batsmanRuns = 1,
  }) {
    return BallEventModel(
      id: 'e$sequence',
      matchId: 'm1',
      inningsNumber: 1,
      overNumber: over,
      ballInOver: ball,
      eventType: BallEventType.runs,
      runs: batsmanRuns,
      batsmanRuns: batsmanRuns,
      isLegalDelivery: true,
      countsInOver: true,
      countsToBowler: true,
      sequence: sequence,
    );
  }

  test('builds summary from ball events', () {
    final events = [
      runEvent(sequence: 1, over: 1, ball: 1, batsmanRuns: 4),
      runEvent(sequence: 2, over: 1, ball: 2, batsmanRuns: 0),
      runEvent(sequence: 3, over: 1, ball: 3, batsmanRuns: 6),
      runEvent(sequence: 4, over: 1, ball: 4, batsmanRuns: 1),
      runEvent(sequence: 5, over: 1, ball: 5, batsmanRuns: 0),
      runEvent(sequence: 6, over: 1, ball: 6, batsmanRuns: 1),
    ];

    final snapshot = service.build(
      match: baseMatch(),
      ballEvents: events,
    );

    expect(snapshot.hasData, isTrue);
    expect(snapshot.summary.extras, 0);
    expect(snapshot.boundaries.fours, 1);
    expect(snapshot.boundaries.sixes, 1);
    expect(snapshot.manhattan.innings.first.bars.first.runs, 12);
  });

  test('hides phase analysis for test matches', () {
    final events = [
      runEvent(sequence: 1, over: 1, ball: 1),
    ];

    final snapshot = service.build(
      match: baseMatch(type: CricketMatchType.testMatch),
      ballEvents: events,
    );

    expect(snapshot.isTestMatch, isTrue);
    expect(snapshot.phases, isEmpty);
    expect(snapshot.runRate.showRequiredRunRate, isFalse);
  });

  test('respects custom balls per over', () {
    final events = List.generate(
      8,
      (i) => runEvent(
        sequence: i + 1,
        over: 1,
        ball: i + 1,
        batsmanRuns: 1,
      ),
    );

    final snapshot = service.build(
      match: baseMatch(ballsPerOver: 8),
      ballEvents: events,
    );

    expect(snapshot.ballsPerOver, 8);
    expect(snapshot.manhattan.innings.first.bars.first.runs, 8);
  });

  test('builds dynamic phase labels for 10-over match', () {
    final events = [
      runEvent(sequence: 1, over: 1, ball: 1, batsmanRuns: 4),
      runEvent(sequence: 2, over: 9, ball: 1, batsmanRuns: 2),
    ];

    final snapshot = service.build(
      match: baseMatch().copyWith(
        rules: MatchRulesModel(
          cricketMatchType: CricketMatchType.limitedOvers,
          totalOvers: 10,
          ballsPerOver: 6,
        ),
      ),
      ballEvents: events,
    );

    expect(snapshot.phaseRanges?.powerplayLabel, 'Powerplay (1-3)');
    expect(snapshot.phaseRanges?.deathLabel, 'Death Overs (8-10)');
    expect(snapshot.phases.length, 3);
    expect(snapshot.phases.first.label, contains('Powerplay'));
  });

  test('last N overs uses min(5, totalOvers)', () {
    final events = List.generate(
      6,
      (i) => runEvent(sequence: i + 1, over: 1, ball: i + 1),
    );

    final snapshot = service.build(
      match: baseMatch().copyWith(
        rules: MatchRulesModel(
          cricketMatchType: CricketMatchType.limitedOvers,
          totalOvers: 3,
          ballsPerOver: 6,
        ),
      ),
      ballEvents: events,
    );

    expect(snapshot.phaseRanges?.lastNOversCount, 3);
    expect(snapshot.worm.innings.first.summary.lastFiveOversRuns, 6);
  });

  test('builds test-specific analytics for test matches', () {
    final events = [
      runEvent(sequence: 1, over: 1, ball: 1, batsmanRuns: 4),
      runEvent(sequence: 2, over: 1, ball: 2),
      runEvent(sequence: 3, over: 2, ball: 1, batsmanRuns: 1),
    ];

    final snapshot = service.build(
      match: baseMatch(type: CricketMatchType.testMatch),
      ballEvents: events,
    );

    expect(snapshot.isTestMatch, isTrue);
    expect(snapshot.phases, isEmpty);
    expect(snapshot.phaseRanges, isNull);
    expect(snapshot.testAnalytics, isNotNull);
    expect(snapshot.testAnalytics!.newBall, isNotEmpty);
    expect(snapshot.testAnalytics!.battingControl.controlLabel, isNot('—'));
  });
}
