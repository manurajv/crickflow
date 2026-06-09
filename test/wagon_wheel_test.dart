import 'dart:math' as math;

import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/data/models/wagon_wheel_data.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:crickflow/domain/wagon_wheel/wagon_wheel_analytics_service.dart';
import 'package:crickflow/domain/wagon_wheel/wagon_wheel_coordinate_mapper.dart';
import 'package:crickflow/domain/wagon_wheel/wagon_wheel_eligibility.dart';
import 'package:crickflow/domain/wagon_wheel/wagon_wheel_field_geometry.dart';
import 'package:crickflow/domain/wagon_wheel/wagon_wheel_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _fieldSize = WagonWheelCoordinateMapper.referenceSize;

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

  group('WagonWheelFieldGeometry zones', () {
    test('singles clamp inside boundary on square field', () {
      final clamped = WagonWheelFieldGeometry.clampCoordinate(90, 50, 1, _fieldSize);
      expect(
        WagonWheelFieldGeometry.zoneAt(clamped.dx, clamped.dy, _fieldSize),
        WagonWheelZone.insideField,
      );
      expect(
        WagonWheelFieldGeometry.boundaryDistance(clamped.dx, clamped.dy, _fieldSize),
        lessThan(WagonWheelFieldGeometry.zoneAInnerMax),
      );
    });

    test('singles clamp inside on wide aspect ratio', () {
      const wide = Size(400, 300);
      final clamped = WagonWheelFieldGeometry.clampCoordinate(15, 50, 1, wide);
      expect(
        WagonWheelFieldGeometry.boundaryDistance(clamped.dx, clamped.dy, wide),
        lessThan(WagonWheelFieldGeometry.zoneAInnerMax),
      );
    });

    test('triples cannot sit on boundary rope', () {
      final onRope = WagonWheelFieldGeometry.clampCoordinate(50, 13, 3, _fieldSize);
      expect(
        WagonWheelFieldGeometry.zoneAt(onRope.dx, onRope.dy, _fieldSize),
        WagonWheelZone.insideField,
      );
    });

    test('fours may land outside boundary', () {
      final outside = WagonWheelFieldGeometry.clampCoordinate(50, 1, 4, _fieldSize);
      expect(
        WagonWheelFieldGeometry.boundaryDistance(outside.dx, outside.dy, _fieldSize),
        greaterThanOrEqualTo(WagonWheelFieldGeometry.zoneBMax),
      );
    });

    test('sixes preserve landing distance when outside boundary', () {
      final mapper = WagonWheelCoordinateMapper(_fieldSize);
      const angle = 1.2;
      final exit = mapper.boundaryExitDistancePixels(angle);
      final nearOutside = mapper.pixelToPercentUnclamped(
        Offset(
          mapper.strikerWicketPixel.dx + (exit + 12) * math.cos(angle),
          mapper.strikerWicketPixel.dy + (exit + 12) * math.sin(angle),
        ),
      );
      final deepOutside = mapper.pixelToPercentUnclamped(
        Offset(
          mapper.strikerWicketPixel.dx + (exit + 48) * math.cos(angle),
          mapper.strikerWicketPixel.dy + (exit + 48) * math.sin(angle),
        ),
      );
      expect(
        WagonWheelFieldGeometry.boundaryDistance(
          nearOutside.dx,
          nearOutside.dy,
          _fieldSize,
        ),
        greaterThan(WagonWheelFieldGeometry.zoneBMax),
      );
      final placedNear = WagonWheelFieldGeometry.clampCoordinate(
        nearOutside.dx,
        nearOutside.dy,
        6,
        _fieldSize,
      );
      final placedDeep = WagonWheelFieldGeometry.clampCoordinate(
        deepOutside.dx,
        deepOutside.dy,
        6,
        _fieldSize,
      );
      expect(
        WagonWheelFieldGeometry.boundaryDistance(
          placedNear.dx,
          placedNear.dy,
          _fieldSize,
        ),
        greaterThan(WagonWheelFieldGeometry.zoneBMax),
      );
      expect(
        WagonWheelFieldGeometry.boundaryDistance(
          placedDeep.dx,
          placedDeep.dy,
          _fieldSize,
        ),
        greaterThan(
          WagonWheelFieldGeometry.boundaryDistance(
            placedNear.dx,
            placedNear.dy,
            _fieldSize,
          ),
        ),
      );
      expect(placedNear.dx, closeTo(nearOutside.dx, 0.01));
      expect(placedNear.dy, closeTo(nearOutside.dy, 0.01));
      expect(
        WagonWheelFieldGeometry.boundaryDistance(
          placedDeep.dx,
          placedDeep.dy,
          _fieldSize,
        ),
        greaterThan(
          WagonWheelFieldGeometry.boundaryDistance(
            placedNear.dx,
            placedNear.dy,
            _fieldSize,
          ),
        ),
      );
    });

    test('sixes inside boundary snap to nearest outside along angle', () {
      final mapper = WagonWheelCoordinateMapper(_fieldSize);
      const angle = 0.9;
      final insideTap = mapper.pixelToPercentUnclamped(
        Offset(
          mapper.strikerWicketPixel.dx + 40 * math.cos(angle),
          mapper.strikerWicketPixel.dy + 40 * math.sin(angle),
        ),
      );
      final placed = WagonWheelFieldGeometry.clampCoordinate(
        insideTap.dx,
        insideTap.dy,
        6,
        _fieldSize,
      );
      expect(
        WagonWheelFieldGeometry.zoneAt(placed.dx, placed.dy, _fieldSize),
        WagonWheelZone.outsideBoundary,
      );
      expect(
        WagonWheelFieldGeometry.boundaryDistance(placed.dx, placed.dy, _fieldSize),
        greaterThan(WagonWheelFieldGeometry.zoneBMax),
      );
      expect(
        mapper.angleFromStriker(placed.dx, placed.dy),
        closeTo(angle, 0.05),
      );
    });

    test('striker wicket is below pitch centre', () {
      expect(
        WagonWheelFieldGeometry.strikerWicketYPercent,
        greaterThan(WagonWheelFieldGeometry.groundCenterYPercent),
      );
    });

    test('same percent maps to same pixel ratio on any width', () {
      const x = 67.2;
      const y = 24.1;
      for (final width in [200.0, 300.0, 400.0]) {
        final size = WagonWheelFieldGeometry.fieldSizeFromWidth(width);
        final mapper = WagonWheelCoordinateMapper(size);
        final p = mapper.percentToPixel(x, y);
        expect(p.dx / size.width, closeTo(x / 100, 0.001));
        expect(p.dy / size.height, closeTo(y / 100, 0.001));
      }
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
