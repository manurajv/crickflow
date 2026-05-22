import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = ScoringEngine();
  const bpo = 6;
  const bowlerA = 'bowler_a';
  const bowlerB = 'bowler_b';
  const strikerId = 's1';

  MatchModel matchWithNextOverBowlerSelected() {
    final rules = const MatchRulesModel().copyWith(ballsPerOver: bpo);
    return MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      rules: rules,
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          totalRuns: 6,
          legalBalls: bpo,
          strikerId: strikerId,
          nonStrikerId: 's2',
          currentBowlerId: bowlerB,
          batsmen: [
            const BatsmanInningsModel(playerId: strikerId, playerName: 'Striker'),
            const BatsmanInningsModel(playerId: 's2', playerName: 'Non'),
          ],
          bowlers: [
            const BowlerInningsModel(
              playerId: bowlerA,
              playerName: 'Bowler A',
              oversBowledBalls: bpo,
            ),
            const BowlerInningsModel(playerId: bowlerB, playerName: 'Bowler B'),
          ],
        ),
      ],
    );
  }

  List<BallEventModel> sixBallOver({required String bowlerId}) {
    return List.generate(bpo, (i) {
      return BallEventModel(
        id: 'e$i',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: i + 1,
        eventType: BallEventType.runs,
        runs: 1,
        batsmanRuns: 1,
        isLegalDelivery: true,
        strikerId: strikerId,
        nonStrikerId: 's2',
        bowlerId: bowlerId,
        sequence: i + 1,
      );
    });
  }

  test('replay keeps over 1 on bowler A when next-over B was selected', () {
    final match = matchWithNextOverBowlerSelected();
    final events = sixBallOver(bowlerId: bowlerA);
    final base = engine.baseInningsFrom(match.currentInnings!, events: events);
    final replayed = engine.replayInnings(
      match: match,
      baseInnings: base,
      events: events,
    );
    final inn = replayed.currentInnings!;

    final a = inn.bowlers.firstWhere((b) => b.playerId == bowlerA);
    final b = inn.bowlers.firstWhere((b) => b.playerId == bowlerB);

    expect(a.oversBowledBalls, bpo);
    expect(a.runsConceded, bpo);
    expect(b.oversBowledBalls, 0);
    expect(b.runsConceded, 0);
    expect(inn.currentBowlerId, bowlerA);
  });

  test('undo last ball of over 1 clears next-over bowler selection', () {
    final match = matchWithNextOverBowlerSelected();
    final events = sixBallOver(bowlerId: bowlerA)..removeLast();
    final base = engine.baseInningsFrom(match.currentInnings!, events: events);
    final replayed = engine.replayInnings(
      match: match,
      baseInnings: base,
      events: events,
    );
    final inn = replayed.currentInnings!;

    expect(inn.legalBalls, bpo - 1);
    expect(inn.currentBowlerId, bowlerA);
    expect(
      inn.bowlers.firstWhere((b) => b.playerId == bowlerA).oversBowledBalls,
      bpo - 1,
    );
    expect(
      inn.bowlers.firstWhere((b) => b.playerId == bowlerB).oversBowledBalls,
      0,
    );
  });
}
