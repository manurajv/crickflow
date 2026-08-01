import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/services/commentary_feed_models.dart';
import 'package:crickflow/domain/services/commentary_feed_service.dart';
import 'package:flutter_test/flutter_test.dart';

BallEventModel _ball({
  required int sequence,
  required int overNumber,
  required int ballInOver,
  String id = '',
}) {
  return BallEventModel(
    id: id.isEmpty ? 'e$sequence' : id,
    matchId: 'm1',
    inningsNumber: 1,
    overNumber: overNumber,
    ballInOver: ballInOver,
    eventType: BallEventType.runs,
    runs: 1,
    batsmanRuns: 1,
    countsAsBallFaced: true,
    sequence: sequence,
    strikerId: 's1',
    bowlerId: 'b1',
    bowlerName: 'Bowler',
  );
}

MatchModel _match({List<List<int>>? powerplaySlots}) {
  return MatchModel(
    id: 'm1',
    title: 'Test',
    teamAId: 'a',
    teamBId: 'b',
    teamAName: 'Alpha',
    teamBName: 'Beta',
    rules: MatchRulesModel(
      ballsPerOver: 6,
      powerplaySlots: powerplaySlots ??
          [
            [1, 2],
            [],
            [],
          ],
      powerplayLabels: const ['Power Play 1', 'Power Play 2', 'Death Overs'],
    ),
    innings: [
      InningsModel(
        inningsNumber: 1,
        battingTeamId: 'a',
        bowlingTeamId: 'b',
        status: InningsStatus.inProgress,
        strikerId: 's1',
        nonStrikerId: 's2',
        currentBowlerId: 'b1',
        batsmen: const [
          BatsmanInningsModel(playerId: 's1', playerName: 'Striker'),
          BatsmanInningsModel(playerId: 's2', playerName: 'Non'),
        ],
        bowlers: const [
          BowlerInningsModel(playerId: 'b1', playerName: 'Bowler'),
        ],
      ),
    ],
  );
}

void main() {
  test('powerplay banner sits before first ball; only once for multi-over PP', () {
    final events = [
      for (var i = 1; i <= 6; i++)
        _ball(sequence: i, overNumber: 1, ballInOver: i),
      for (var i = 1; i <= 3; i++)
        _ball(sequence: 6 + i, overNumber: 2, ballInOver: i),
    ];

    final feed = CommentaryFeedService.build(match: _match(), allEvents: events);
    final items = feed.itemsForInnings(1);
    // Newest first.
    final chronological = items.reversed.toList();

    final ppStarts = chronological
        .whereType<MatchEventCommentaryItem>()
        .where((i) => i.eventKind == CommentaryMatchEventKind.powerplayStarted)
        .toList();
    expect(ppStarts, hasLength(1));
    expect(ppStarts.first.title, 'Power Play 1 Running');

    final firstBall = chronological.whereType<BallCommentaryItem>().first;
    final ppIndex = chronological.indexOf(ppStarts.first);
    final ballIndex = chronological.indexOf(firstBall);
    expect(ppIndex, lessThan(ballIndex));
    expect(firstBall.ballLabel, '0.1');
  });

  test('end of over comes after 0.6; in-progress over is THIS OVER', () {
    final events = [
      for (var i = 1; i <= 6; i++)
        _ball(sequence: i, overNumber: 1, ballInOver: i),
      for (var i = 1; i <= 2; i++)
        _ball(sequence: 6 + i, overNumber: 2, ballInOver: i),
    ];

    final feed = CommentaryFeedService.build(match: _match(), allEvents: events);
    final chronological = feed.itemsForInnings(1).reversed.toList();

    final ball06 = chronological.whereType<BallCommentaryItem>().firstWhere(
          (i) => i.ballLabel == '0.6',
        );
    final endOver1 = chronological.whereType<OverSummaryCommentaryItem>().firstWhere(
          (i) => i.overNumber == 1 && i.isComplete,
        );
    expect(chronological.indexOf(ball06), lessThan(chronological.indexOf(endOver1)));

    final thisOver = chronological.whereType<OverSummaryCommentaryItem>().firstWhere(
          (i) => !i.isComplete,
        );
    expect(thisOver.overNumber, 2);
    expect(thisOver.ballEvents, hasLength(2));
  });
}
