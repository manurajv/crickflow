import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/data/models/wagon_wheel_data.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:crickflow/domain/wagon_wheel/wagon_wheel_analytics_service.dart';
import 'package:crickflow/domain/wagon_wheel/wagon_wheel_eligibility.dart';
import 'package:crickflow/domain/wagon_wheel/wagon_wheel_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WagonWheelEligibility', () {
    final rulesOn = MatchRulesModel.standardT20().copyWith(
      wagonWheelEnabled: true,
    );
    final rulesOff = MatchRulesModel.standardT20();

    test('captures runs 1-6 when enabled', () {
      for (var r = 1; r <= 6; r++) {
        expect(
          WagonWheelEligibility.shouldCapture(
            BallEventInput(type: BallEventType.runs, runs: r),
            rulesOn,
          ),
          isTrue,
          reason: 'run $r',
        );
      }
    });

    test('skips dot ball', () {
      expect(
        WagonWheelEligibility.shouldCapture(
          BallEventInput(type: BallEventType.runs, runs: 0),
          rulesOn,
        ),
        isFalse,
      );
    });

    test('skips when disabled', () {
      expect(
        WagonWheelEligibility.shouldCapture(
          BallEventInput(type: BallEventType.runs, runs: 4),
          rulesOff,
        ),
        isFalse,
      );
    });

    test('skips wide and bye', () {
      expect(
        WagonWheelEligibility.shouldCapture(
          BallEventInput(type: BallEventType.wide, runs: 1),
          rulesOn,
        ),
        isFalse,
      );
      expect(
        WagonWheelEligibility.shouldCapture(
          BallEventInput(type: BallEventType.bye, runs: 2),
          rulesOn,
        ),
        isFalse,
      );
    });

    test('no-ball from bat with runs shows', () {
      expect(
        WagonWheelEligibility.shouldCapture(
          BallEventInput(
            type: BallEventType.noBall,
            runs: 4,
            noBallRunsMode: NoBallRunsMode.bat,
          ),
          rulesOn,
        ),
        isTrue,
      );
    });

    test('no-ball bye does not show', () {
      expect(
        WagonWheelEligibility.shouldCapture(
          BallEventInput(
            type: BallEventType.noBall,
            runs: 2,
            noBallRunsMode: NoBallRunsMode.bye,
          ),
          rulesOn,
        ),
        isFalse,
      );
    });
  });

  group('WagonWheelData serialization', () {
    test('round-trips percentage coordinates', () {
      const data = WagonWheelData(
        x: 67.2,
        y: 24.1,
        shotType: WagonWheelShotType.four,
      );
      final map = data.toMap();
      final parsed = WagonWheelData.fromMap(map);
      expect(parsed.x, 67.2);
      expect(parsed.y, 24.1);
      expect(parsed.shotType, WagonWheelShotType.four);
    });

    test('ball event stores wagon wheel nested', () {
      final event = BallEventModel(
        id: 'e1',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 1,
        eventType: BallEventType.runs,
        runs: 4,
        batsmanRuns: 4,
        wagonWheel: const WagonWheelData(
          x: 70,
          y: 30,
          shotType: WagonWheelShotType.four,
        ),
      );
      final map = event.toMap();
      expect(map['wagonWheel'], isNotNull);
      final restored = BallEventModel.fromMap('e1', map);
      expect(restored.wagonWheel?.x, 70);
    });
  });

  group('WagonWheelAnalyticsService', () {
    final service = WagonWheelAnalyticsService();

    test('filters by batter and run type', () {
      final events = [
        BallEventModel(
          id: '1',
          matchId: 'm1',
          inningsNumber: 1,
          overNumber: 0,
          ballInOver: 1,
          eventType: BallEventType.runs,
          runs: 4,
          batsmanRuns: 4,
          strikerId: 'b1',
          wagonWheel: const WagonWheelData(x: 80, y: 40),
        ),
        BallEventModel(
          id: '2',
          matchId: 'm1',
          inningsNumber: 1,
          overNumber: 0,
          ballInOver: 2,
          eventType: BallEventType.runs,
          runs: 1,
          batsmanRuns: 1,
          strikerId: 'b2',
          wagonWheel: const WagonWheelData(x: 30, y: 50),
        ),
      ];

      final matches = [
        const MatchModel(id: 'm1', title: 'Test'),
      ];
      final foursOnly = service.extractShots(
        events: events,
        matches: matches,
        filter: const WagonWheelFilter(
          batterId: 'b1',
          runFilter: WagonWheelRunFilter.fours,
        ),
      );
      expect(foursOnly.length, 1);
      expect(foursOnly.first.batsmanRuns, 4);
    });
  });
}
