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
  const striker1 = 's1';
  const striker2 = 's2';
  const nonStriker = 'ns';
  const bowler1 = 'bowler1';
  const bowler2 = 'bowler2';

  MatchModel twoInningsMatch({
    required int inn2Runs,
    required int inn2LegalBalls,
  }) {
    return MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      currentInningsIndex: 1,
      rules: const MatchRulesModel().copyWith(
        ballsPerOver: bpo,
        totalOvers: 20,
      ),
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 12,
          totalWickets: 1,
          legalBalls: bpo,
          strikerId: striker1,
          nonStrikerId: nonStriker,
          currentBowlerId: bowler1,
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.inProgress,
          totalRuns: inn2Runs,
          legalBalls: inn2LegalBalls,
          strikerId: striker2,
          nonStrikerId: nonStriker,
          currentBowlerId: bowler2,
          batsmen: [
            const BatsmanInningsModel(playerId: striker2, playerName: 'Opener'),
            const BatsmanInningsModel(playerId: nonStriker, playerName: 'NS'),
          ],
          bowlers: [
            const BowlerInningsModel(playerId: bowler2, playerName: 'Bowler 2'),
          ],
        ),
      ],
    );
  }

  List<BallEventModel> inn1Events() {
    return List.generate(bpo, (i) {
      return BallEventModel(
        id: 'i1_$i',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: i + 1,
        eventType: BallEventType.runs,
        runs: 2,
        batsmanRuns: 2,
        isLegalDelivery: true,
        strikerId: striker1,
        nonStrikerId: nonStriker,
        bowlerId: bowler1,
        sequence: i + 1,
      );
    });
  }

  List<BallEventModel> inn2Events() {
    return [
      BallEventModel(
        id: 'i2_0',
        matchId: 'm1',
        inningsNumber: 2,
        overNumber: 0,
        ballInOver: 1,
        eventType: BallEventType.runs,
        runs: 1,
        batsmanRuns: 1,
        isLegalDelivery: true,
        strikerId: striker2,
        nonStrikerId: nonStriker,
        bowlerId: bowler2,
        sequence: bpo + 1,
      ),
      BallEventModel(
        id: 'i2_1',
        matchId: 'm1',
        inningsNumber: 2,
        overNumber: 0,
        ballInOver: 2,
        eventType: BallEventType.runs,
        runs: 4,
        batsmanRuns: 4,
        isLegalDelivery: true,
        strikerId: striker2,
        nonStrikerId: nonStriker,
        bowlerId: bowler2,
        sequence: bpo + 2,
      ),
      BallEventModel(
        id: 'i2_2',
        matchId: 'm1',
        inningsNumber: 2,
        overNumber: 0,
        ballInOver: 3,
        eventType: BallEventType.runs,
        runs: 6,
        batsmanRuns: 6,
        isLegalDelivery: true,
        strikerId: striker2,
        nonStrikerId: nonStriker,
        bowlerId: bowler2,
        sequence: bpo + 3,
      ),
    ];
  }

  test('undo in second innings only replays current innings events', () {
    final match = twoInningsMatch(inn2Runs: 11, inn2LegalBalls: 3);
    final allEvents = [...inn1Events(), ...inn2Events()];
    allEvents.removeLast();

    final inningsEvents =
        allEvents.where((e) => e.inningsNumber == 2).toList();
    final base = engine.baseInningsFrom(
      match.currentInnings!,
      events: inningsEvents,
    );
    final replayed = engine.replayInnings(
      match: match,
      baseInnings: base,
      events: inningsEvents,
    );

    final first = replayed.innings.first;
    final second = replayed.currentInnings!;

    expect(first.totalRuns, 12);
    expect(first.totalWickets, 1);
    expect(first.legalBalls, bpo);
    expect(second.totalRuns, 5);
    expect(second.legalBalls, 2);
    expect(
      ScoringDisplayUtils.isInningsComplete(replayed, second),
      isFalse,
    );
  });

  test('replay ignores first innings events when rebuilding second innings', () {
    final match = twoInningsMatch(inn2Runs: 11, inn2LegalBalls: 3);
    final allEvents = [...inn1Events(), ...inn2Events()];

    final base = engine.baseInningsFrom(
      match.currentInnings!,
      events: allEvents,
    );
    final replayed = engine.replayInnings(
      match: match,
      baseInnings: base,
      events: allEvents,
    );

    final second = replayed.currentInnings!;
    expect(second.totalRuns, 11);
    expect(second.legalBalls, 3);
    expect(
      ScoringDisplayUtils.isInningsComplete(replayed, second),
      isFalse,
    );
  });
}
