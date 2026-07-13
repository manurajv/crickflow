import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/domain/scoring/ball_event_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';

BallEventModel _event({
  required String id,
  required int sequence,
  int runs = 1,
}) {
  return BallEventModel(
    id: id,
    matchId: 'm1',
    inningsNumber: 1,
    overNumber: 1,
    ballInOver: sequence,
    eventType: BallEventType.runs,
    runs: runs,
    batsmanRuns: runs,
    strikerId: 'a',
    nonStrikerId: 'b',
    bowlerId: 'c',
    sequence: sequence,
  );
}

void main() {
  test('mergeEventLogs unions remote-only events with local pending event', () {
    final remote = [
      _event(id: 'remote-1', sequence: 1, runs: 6),
      _event(id: 'remote-2', sequence: 2, runs: 4),
      _event(id: 'remote-3', sequence: 3, runs: 1),
    ];
    final local = [
      _event(id: 'remote-1', sequence: 1, runs: 6),
      _event(id: 'remote-2', sequence: 2, runs: 4),
      _event(id: 'local-4', sequence: 4, runs: 6),
    ];

    final merged = BallEventAggregator.mergeEventLogs(local, remote);

    expect(merged.map((e) => e.id).toList(), [
      'remote-1',
      'remote-2',
      'remote-3',
      'local-4',
    ]);
    expect(merged.last.sequence, 4);
  });

  test('mergeEventLogs prefers local copy on duplicate id', () {
    final remote = [_event(id: 'same', sequence: 1, runs: 4)];
    final local = [_event(id: 'same', sequence: 1, runs: 6)];

    final merged = BallEventAggregator.mergeEventLogs(local, remote);

    expect(merged.single.runs, 6);
  });
}
