import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/scoring/scoring_integrity_check.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verify returns empty when projection matches replay', () {
    final engine = ScoringEngine();
    final match = MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      rules: MatchRulesModel.standardT20(),
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          strikerId: 'b1',
          nonStrikerId: 'b2',
          currentBowlerId: 'bowl1',
          batsmen: const [
            BatsmanInningsModel(playerId: 'b1', playerName: 'A'),
            BatsmanInningsModel(playerId: 'b2', playerName: 'B'),
          ],
          bowlers: const [
            BowlerInningsModel(playerId: 'bowl1', playerName: 'C'),
          ],
        ),
      ],
    );

    final r1 = engine.recordBall(
      match: match,
      input: const BallEventInput(type: BallEventType.runs, runs: 4),
      sequence: 1,
    );
    final r2 = engine.recordBall(
      match: r1.match,
      input: const BallEventInput(type: BallEventType.runs, runs: 2),
      sequence: 2,
    );

    final issues = ScoringIntegrityCheck.verify(
      match: r2.match,
      allEvents: [r1.event, r2.event],
    );
    expect(issues, isEmpty);
  });

  test('innings toMap does not persist derived lists', () {
    const inn = InningsModel(
      inningsNumber: 1,
      battingTeamId: 'a',
      bowlingTeamId: 'b',
      partnerships: [
        PartnershipRecord(batterAId: 'x', batterBId: 'y', runs: 10, balls: 8),
      ],
      fallOfWickets: [
        FallOfWicketRecord(
          wicketNumber: 1,
          batsmanId: 'x',
          teamScore: 10,
          legalBalls: 8,
        ),
      ],
      fielders: [
        FielderInningsModel(playerId: 'f1', catches: 1),
      ],
    );
    final map = inn.toMap();
    expect(map.containsKey('partnerships'), isFalse);
    expect(map.containsKey('fallOfWickets'), isFalse);
    expect(map.containsKey('fielders'), isFalse);
  });
}
