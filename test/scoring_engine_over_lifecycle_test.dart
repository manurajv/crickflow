import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:crickflow/features/scoring/presentation/utils/scoring_display_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = ScoringEngine();
  const bpo = 6;
  const bowlerA = 'bowler_a';
  const bowlerB = 'bowler_b';
  const strikerId = 's1';
  const nonStrikerId = 's2';

  MatchModel baseMatch({InningsModel? innings}) {
    return MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      rules: const MatchRulesModel().copyWith(ballsPerOver: bpo),
      innings: [
        innings ??
            InningsModel(
              inningsNumber: 1,
              battingTeamId: 'a',
              bowlingTeamId: 'b',
              status: InningsStatus.inProgress,
              strikerId: strikerId,
              nonStrikerId: nonStrikerId,
              currentBowlerId: bowlerA,
              batsmen: const [
                BatsmanInningsModel(playerId: strikerId, playerName: 'Striker'),
                BatsmanInningsModel(
                  playerId: nonStrikerId,
                  playerName: 'Non',
                ),
              ],
              bowlers: [
                const BowlerInningsModel(
                  playerId: bowlerA,
                  playerName: 'Bowler A',
                ),
              ],
            ),
      ],
    );
  }

  ScoringInput recordRun(MatchModel match, {int sequence = 1, String? bowlerId}) {
    return engine.recordBall(
      match: match,
      input: BallEventInput(
        type: BallEventType.runs,
        runs: 1,
        bowlerId: bowlerId,
      ),
      sequence: sequence,
    );
  }

  group('early ended over', () {
    test('next over starts with empty This Over indicators', () {
      var match = baseMatch();
      var seq = 0;
      for (var i = 0; i < 5; i++) {
        seq++;
        match = recordRun(match, sequence: seq).match;
      }
      seq++;
      final ended = engine.recordBall(
        match: match,
        input: const BallEventInput(type: BallEventType.endOver),
        sequence: seq,
      );
      match = ended.match;
      final inn = match.currentInnings!;
      expect(ScoringDisplayUtils.ballsInCurrentOver(inn), 0);
      expect(inn.currentOverNumber, 2);

      seq++;
      match = recordRun(match, sequence: seq).match;
      final events = <BallEventModel>[
        for (var s = 1; s <= seq; s++)
          if (s <= 5)
            BallEventModel(
              id: 'e$s',
              matchId: 'm1',
              inningsNumber: 1,
              overNumber: 1,
              ballInOver: s,
              eventType: BallEventType.runs,
              runs: 1,
              batsmanRuns: 1,
              isLegalDelivery: true,
              strikerId: strikerId,
              nonStrikerId: nonStrikerId,
              bowlerId: bowlerA,
              sequence: s,
            )
          else if (s == 6)
            BallEventModel(
              id: 'e$s',
              matchId: 'm1',
              inningsNumber: 1,
              overNumber: 1,
              ballInOver: 0,
              eventType: BallEventType.endOver,
              sequence: s,
            )
          else
            BallEventModel(
              id: 'e$s',
              matchId: 'm1',
              inningsNumber: 1,
              overNumber: 2,
              ballInOver: 1,
              eventType: BallEventType.runs,
              runs: 1,
              batsmanRuns: 1,
              isLegalDelivery: true,
              strikerId: strikerId,
              nonStrikerId: nonStrikerId,
              bowlerId: bowlerA,
              sequence: s,
            ),
      ];

      final current = ScoringDisplayUtils.currentOverEvents(
        events: events,
        inn: match.currentInnings!,
        ballsPerOver: bpo,
      );
      expect(current.length, 1);
      expect(current.first.overNumber, 2);
    });
  });

  group('continued over', () {
    test('seven legal balls stay in one over indicator', () {
      var match = baseMatch();
      var seq = 0;
      for (var i = 0; i < 7; i++) {
        seq++;
        match = recordRun(match, sequence: seq).match;
      }
      final inn = match.currentInnings!;
      expect(ScoringDisplayUtils.ballsInCurrentOver(inn), 7);
      expect(inn.currentOverNumber, 1);

      final replayed = engine.replayInnings(
        match: match,
        baseInnings: engine.baseInningsFrom(inn),
        events: List.generate(
          7,
          (i) => BallEventModel(
            id: 'e$i',
            matchId: 'm1',
            inningsNumber: 1,
            overNumber: 1,
            ballInOver: i + 1,
            eventType: BallEventType.runs,
            runs: 1,
            batsmanRuns: 1,
            isLegalDelivery: true,
            strikerId: strikerId,
            nonStrikerId: nonStrikerId,
            bowlerId: bowlerA,
            sequence: i + 1,
          ),
        ),
      );
      final replayInn = replayed.currentInnings!;
      expect(replayInn.legalBalls, 7);
      expect(replayInn.currentOverNumber, 1);
    });
  });

  group('mid-over bowler change', () {
    test('creates new segment and preserves all deliveries in over', () {
      var match = baseMatch();
      var seq = 0;
      for (var i = 0; i < 3; i++) {
        seq++;
        match = recordRun(match, sequence: seq).match;
      }
      seq++;
      match = engine.recordBall(
        match: match,
        input: BallEventInput(
          type: BallEventType.lineupChange,
          creaseStrikerId: strikerId,
          creaseNonStrikerId: nonStrikerId,
          bowlerId: bowlerB,
          bowlerName: 'Bowler B',
        ),
        sequence: seq,
      ).match;

      final innAfterChange = match.currentInnings!;
      expect(innAfterChange.currentOverSegment, 2);
      expect(innAfterChange.currentBowlerId, bowlerB);

      for (var i = 0; i < 3; i++) {
        seq++;
        match = recordRun(match, sequence: seq, bowlerId: bowlerB).match;
      }

      final inn = match.currentInnings!;
      expect(ScoringDisplayUtils.ballsInCurrentOver(inn), 6);
      expect(inn.currentOverNumber, 1);
      expect(inn.currentOverSegment, 2);

      final a = inn.bowlers.firstWhere((b) => b.playerId == bowlerA);
      final b = inn.bowlers.firstWhere((b) => b.playerId == bowlerB);
      expect(a.oversBowledBalls, 3);
      expect(b.oversBowledBalls, 3);
    });

    test('returning bowler later starts a fresh over segment', () {
      var match = baseMatch();
      var seq = 0;
      for (var i = 0; i < 3; i++) {
        seq++;
        match = recordRun(match, sequence: seq).match;
      }
      seq++;
      match = engine.recordBall(
        match: match,
        input: BallEventInput(
          type: BallEventType.lineupChange,
          creaseStrikerId: strikerId,
          creaseNonStrikerId: nonStrikerId,
          bowlerId: bowlerB,
          bowlerName: 'Bowler B',
        ),
        sequence: seq,
      ).match;
      for (var i = 0; i < 3; i++) {
        seq++;
        match = recordRun(match, sequence: seq, bowlerId: bowlerB).match;
      }
      seq++;
      match = engine.recordBall(
        match: match,
        input: const BallEventInput(type: BallEventType.endOver),
        sequence: seq,
      ).match;
      seq++;
      match = engine.recordBall(
        match: match,
        input: BallEventInput(
          type: BallEventType.lineupChange,
          creaseStrikerId: strikerId,
          creaseNonStrikerId: nonStrikerId,
          bowlerId: bowlerA,
          bowlerName: 'Bowler A',
        ),
        sequence: seq,
      ).match;

      final inn = match.currentInnings!;
      expect(inn.currentOverNumber, 2);
      expect(inn.currentOverSegment, 1);
      expect(ScoringDisplayUtils.ballsInCurrentOver(inn), 0);
    });
  });

  group('over metadata', () {
    test('endOver emits metadata with actual ball count', () {
      var match = baseMatch();
      var seq = 0;
      for (var i = 0; i < 5; i++) {
        seq++;
        match = recordRun(match, sequence: seq).match;
      }
      seq++;
      final result = engine.recordBall(
        match: match,
        input: const BallEventInput(type: BallEventType.endOver),
        sequence: seq,
      );
      expect(result.overMetadata, isNotNull);
      expect(result.overMetadata!.overNumber, 1);
      expect(result.overMetadata!.actualBallsBowled, 5);
      expect(result.overMetadata!.manuallyEnded, isTrue);
      expect(result.overMetadata!.continuedBeyondLimit, isFalse);
    });

    test('mid-over bowler change emits segment metadata', () {
      var match = baseMatch();
      var seq = 0;
      for (var i = 0; i < 3; i++) {
        seq++;
        match = recordRun(match, sequence: seq).match;
      }
      seq++;
      final result = engine.recordBall(
        match: match,
        input: BallEventInput(
          type: BallEventType.lineupChange,
          creaseStrikerId: strikerId,
          creaseNonStrikerId: nonStrikerId,
          bowlerId: bowlerB,
          bowlerName: 'Bowler B',
        ),
        sequence: seq,
      );
      expect(result.overMetadata, isNotNull);
      expect(result.overMetadata!.segment, 1);
      expect(result.overMetadata!.bowlerId, bowlerA);
      expect(result.overMetadata!.segmentLegalBalls, 3);
    });
  });
}
