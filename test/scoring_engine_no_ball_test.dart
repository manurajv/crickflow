import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = ScoringEngine();

  MatchModel baseMatch() {
    const strikerId = 's1';
    const bowlerId = 'b1';
    return MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          strikerId: strikerId,
          nonStrikerId: 's2',
          currentBowlerId: bowlerId,
          batsmen: [
            const BatsmanInningsModel(playerId: strikerId, playerName: 'Striker'),
            const BatsmanInningsModel(playerId: 's2', playerName: 'Non'),
          ],
          bowlers: [
            const BowlerInningsModel(playerId: bowlerId, playerName: 'Bowler'),
          ],
        ),
      ],
    );
  }

  test('NB+1 from bat: total 2, extras 1, batsman 1', () {
    final result = engine.recordBall(
      match: baseMatch(),
      input: const BallEventInput(
        type: BallEventType.noBall,
        runs: 1,
        noBallRunsMode: NoBallRunsMode.bat,
      ),
      sequence: 1,
    );
    final inn = result.match.currentInnings!;
    final striker = inn.batsmen.firstWhere((b) => b.playerId == 's1');

    expect(result.event.runs, 2);
    expect(result.event.batsmanRuns, 1);
    expect(result.event.extraRuns, 1);
    expect(inn.totalRuns, 2);
    expect(inn.extras, 1);
    expect(striker.runs, 1);
  });

  test('NB+1 bye: total 2, extras 2, batsman 0', () {
    final result = engine.recordBall(
      match: baseMatch(),
      input: const BallEventInput(
        type: BallEventType.noBall,
        runs: 1,
        noBallRunsMode: NoBallRunsMode.bye,
      ),
      sequence: 1,
    );
    final inn = result.match.currentInnings!;
    final striker = inn.batsmen.firstWhere((b) => b.playerId == 's1');

    expect(inn.totalRuns, 2);
    expect(inn.extras, 2);
    expect(striker.runs, 0);
    expect(striker.balls, 0);
  });

  test('bye increments striker balls faced (same as leg bye)', () {
    final result = engine.recordBall(
      match: baseMatch(),
      input: const BallEventInput(type: BallEventType.bye, runs: 1),
      sequence: 1,
    );
    final striker =
        result.match.currentInnings!.batsmen.firstWhere((b) => b.playerId == 's1');

    expect(striker.runs, 0);
    expect(striker.balls, 1);
    expect(result.match.currentInnings!.extras, 1);
  });

  test('leg bye increments striker balls faced', () {
    final result = engine.recordBall(
      match: baseMatch(),
      input: const BallEventInput(type: BallEventType.legBye, runs: 1),
      sequence: 1,
    );
    final striker =
        result.match.currentInnings!.batsmen.firstWhere((b) => b.playerId == 's1');

    expect(striker.runs, 0);
    expect(striker.balls, 1);
  });

  test('NB+1 leg bye: total 2, extras 2, batsman 0', () {
    final result = engine.recordBall(
      match: baseMatch(),
      input: const BallEventInput(
        type: BallEventType.noBall,
        runs: 1,
        noBallRunsMode: NoBallRunsMode.legBye,
      ),
      sequence: 1,
    );
    final inn = result.match.currentInnings!;

    expect(inn.totalRuns, 2);
    expect(inn.extras, 2);
    expect(inn.batsmen.firstWhere((b) => b.playerId == 's1').runs, 0);
  });
}
