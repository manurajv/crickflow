import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/features/streaming/domain/stream_event_detector.dart';
import 'package:crickflow/features/streaming/domain/streaming_enums.dart';
import 'package:flutter_test/flutter_test.dart';

BallEventModel _event({
  required BallEventType type,
  int runs = 0,
  int batsmanRuns = 0,
  String? boundaryType,
  String? strikerId,
  String? nonStrikerId,
  String? lineupStrikerName,
  String? lineupNonStrikerName,
  String? dismissedPlayerId,
  bool isBowlerChange = false,
  String? bowlerName,
  String? nextStrikerId,
  String? nextStrikerName,
}) {
  return BallEventModel(
    id: 'e1',
    matchId: 'm1',
    inningsNumber: 1,
    overNumber: 1,
    ballInOver: 1,
    eventType: type,
    runs: runs,
    batsmanRuns: batsmanRuns,
    boundaryType: boundaryType,
    strikerId: strikerId,
    nonStrikerId: nonStrikerId,
    lineupStrikerName: lineupStrikerName,
    lineupNonStrikerName: lineupNonStrikerName,
    dismissedPlayerId: dismissedPlayerId,
    isBowlerChange: isBowlerChange,
    bowlerName: bowlerName,
    nextStrikerId: nextStrikerId,
    nextStrikerName: nextStrikerName,
  );
}

void main() {
  const detector = StreamEventDetector();

  test('no-ball six off the bat shows SIX overlay', () {
    final graphic = detector.detect(
      _event(type: BallEventType.noBall, runs: 7, batsmanRuns: 6),
    );
    expect(graphic?.type, StreamEventOverlayType.hugeSix);
  });

  test('bye four shows FOUR overlay', () {
    final graphic = detector.detect(
      _event(type: BallEventType.bye, runs: 4),
    );
    expect(graphic?.type, StreamEventOverlayType.boundaryFour);
  });

  test('leg bye four shows FOUR overlay', () {
    final graphic = detector.detect(
      _event(type: BallEventType.legBye, runs: 4),
    );
    expect(graphic?.type, StreamEventOverlayType.boundaryFour);
  });

  test('normal boundary six still shows SIX overlay', () {
    final graphic = detector.detect(
      _event(
        type: BallEventType.runs,
        runs: 6,
        batsmanRuns: 6,
        boundaryType: 'six',
      ),
    );
    expect(graphic?.type, StreamEventOverlayType.hugeSix);
  });

  test('lineup change after wicket shows new batter intro', () {
    final wicket = _event(
      type: BallEventType.wicket,
      strikerId: 'b1',
      nonStrikerId: 'b2',
      dismissedPlayerId: 'b1',
    );
    final lineup = _event(
      type: BallEventType.lineupChange,
      strikerId: 'b3',
      nonStrikerId: 'b2',
      lineupStrikerName: 'New Batter',
    );
    final graphic = detector.detect(lineup, previous: wicket);
    expect(graphic?.type, StreamEventOverlayType.newBatter);
    expect(graphic?.playerName, 'New Batter');
    expect(graphic?.playerId, 'b3');
  });

  test('bowler-only lineup change does not show new batter intro', () {
    final previous = _event(
      type: BallEventType.runs,
      strikerId: 'b1',
      nonStrikerId: 'b2',
    );
    final lineup = _event(
      type: BallEventType.lineupChange,
      strikerId: 'b1',
      nonStrikerId: 'b2',
      isBowlerChange: true,
      bowlerName: 'New Bowler',
    );
    final graphic = detector.detect(lineup, previous: previous);
    expect(graphic?.type, StreamEventOverlayType.newBowler);
  });
}
