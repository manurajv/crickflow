import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/services/player_typed_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregates bowler dots, wides, and no balls', () {
    const playerId = 'bowler';
    final match = MatchModel(
      id: 'match',
      title: 'Bowling stats',
      status: MatchStatus.completed,
      teamAId: 'bat',
      teamBId: 'bowl',
      rules: const MatchRulesModel(ballType: CricketBallType.leather),
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'bat',
          bowlingTeamId: 'bowl',
          status: InningsStatus.completed,
          bowlers: [
            BowlerInningsModel(
              playerId: playerId,
              oversBowledBalls: 6,
              runsConceded: 8,
              wickets: 1,
              wides: 2,
              noBalls: 1,
            ),
          ],
        ),
      ],
    );
    const events = [
      BallEventModel(
        id: 'dot1',
        matchId: 'match',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 1,
        eventType: BallEventType.runs,
        bowlerId: playerId,
        sequence: 1,
      ),
      BallEventModel(
        id: 'dot2',
        matchId: 'match',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 2,
        eventType: BallEventType.wicket,
        bowlerId: playerId,
        isWicket: true,
        bowlerGetsWicket: true,
        sequence: 2,
      ),
      BallEventModel(
        id: 'notBowlerDot',
        matchId: 'match',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 3,
        eventType: BallEventType.runs,
        bowlerId: playerId,
        countsToBowler: false,
        sequence: 3,
      ),
    ];

    final result = const PlayerTypedStatsService().aggregateOverallDetailed(
      completedMatches: [match],
      playerId: playerId,
      playerTeamId: 'bowl',
      userTeamIds: const {'bowl'},
      ballEventsByMatchId: const {'match': events},
    );

    expect(result.dotBalls, 2);
    expect(result.wides, 2);
    expect(result.noBalls, 1);
  });
}
