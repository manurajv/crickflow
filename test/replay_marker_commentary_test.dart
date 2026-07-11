import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/domain/streaming/batting_milestone_detector.dart';
import 'package:crickflow/domain/streaming/replay_marker_commentary.dart';
import 'package:crickflow/features/streaming/data/models/replay_marker_model.dart';
import 'package:crickflow/features/streaming/domain/streaming_enums.dart';

void main() {
  test('crossedMilestone detects batter fifty and century only', () {
    expect(BattingMilestoneDetector.crossedMilestone(42, 50), 50);
    expect(BattingMilestoneDetector.crossedMilestone(95, 100), 100);
    expect(BattingMilestoneDetector.crossedMilestone(49, 51), 50);
    expect(BattingMilestoneDetector.crossedMilestone(50, 55), isNull);
    expect(BattingMilestoneDetector.crossedMilestone(12, 18), isNull);
  });

  test('wicket commentary uses bowler and dismissed batter', () {
    final text = ReplayMarkerCommentary.format(
      const ReplayMarkerModel(
        id: '1',
        matchId: 'm',
        kind: ReplayMarkerKind.wicket,
        label: 'New Bowler',
        streamOffsetMs: 0,
        createdBy: 'u',
      ),
    );
    expect(text.toLowerCase(), contains('wicket'));
    expect(text, isNot(contains('reaches fifty')));
  });

  test('milestone commentary describes batter fifty', () {
    final text = ReplayMarkerCommentary.format(
      const ReplayMarkerModel(
        id: '1',
        matchId: 'm',
        kind: ReplayMarkerKind.milestone,
        label: 'Kohli reaches fifty',
        streamOffsetMs: 0,
        createdBy: 'u',
      ),
    );
    expect(text, 'FIFTY • Kohli reaches 50');
  });
}
