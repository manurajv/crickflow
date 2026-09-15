import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/data/models/player_model.dart';
import 'package:crickflow/domain/services/player_rankings/player_rankings_models.dart';
import 'package:crickflow/domain/services/player_rankings/player_rankings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PlayerRankingsService();
  const rules = MatchRulesModel(
    ballType: CricketBallType.leather,
    totalOvers: 20,
    ballsPerOver: 6,
  );

  final innings = InningsModel(
    inningsNumber: 1,
    battingTeamId: 'bat',
    bowlingTeamId: 'bowl',
    status: InningsStatus.completed,
    batsmen: const [
      BatsmanInningsModel(
        playerId: 'batter',
        playerName: 'Batter',
        runs: 100,
        balls: 25,
      ),
    ],
    bowlers: const [
      BowlerInningsModel(
        playerId: 'bowlerA',
        playerName: 'Bowler A',
        wickets: 4,
        runsConceded: 30,
      ),
      BowlerInningsModel(
        playerId: 'bowlerB',
        playerName: 'Bowler B',
        wickets: 4,
        runsConceded: 25,
      ),
    ],
  );
  final match = MatchModel(
    id: 'match',
    title: 'Replay rankings',
    status: MatchStatus.completed,
    teamAId: 'bat',
    teamBId: 'bowl',
    rules: rules,
    innings: [innings],
  );

  final events = <BallEventModel>[
    for (var i = 1; i <= 25; i++)
      BallEventModel(
        id: 'run$i',
        matchId: 'match',
        inningsNumber: 1,
        overNumber: (i - 1) ~/ 6,
        ballInOver: ((i - 1) % 6) + 1,
        eventType: BallEventType.runs,
        runs: 4,
        batsmanRuns: 4,
        countsAsBallFaced: true,
        strikerId: 'batter',
        bowlerId: 'bowlerA',
        sequence: i,
      ),
    for (var i = 1; i <= 6; i++)
      BallEventModel(
        id: 'dot$i',
        matchId: 'match',
        inningsNumber: 1,
        overNumber: 10,
        ballInOver: i,
        eventType: BallEventType.runs,
        runs: 0,
        batsmanRuns: 0,
        countsAsBallFaced: true,
        strikerId: 'otherBatter',
        bowlerId: 'bowlerB',
        sequence: 25 + i,
      ),
    const BallEventModel(
      id: 'notAttributed',
      matchId: 'match',
      inningsNumber: 1,
      overNumber: 11,
      ballInOver: 1,
      eventType: BallEventType.runs,
      runs: 0,
      countsToBowler: false,
      bowlerId: 'bowlerB',
      sequence: 32,
    ),
  ];

  test('aggregates all delivery-level player ranking metrics', () {
    final replay = <String, PlayerRankingReplayStats>{};

    service.aggregateFromMatches(
      matches: [match],
      filter: const PlayerRankingsFilter(),
      ballEventsByMatchId: {'match': events},
      replayStatsOut: replay,
    );

    expect(replay['batter']?.fastestFiftyBalls, 13);
    expect(replay['batter']?.fastestHundredBalls, 25);
    expect(replay['bowlerB']?.bestBowlingWickets, 4);
    expect(replay['bowlerB']?.bestBowlingRuns, 25);
    expect(replay['bowlerB']?.maidens, 1);
    expect(replay['bowlerB']?.dotBalls, 6);
  });

  test('ranks and labels every replay-backed category', () {
    final replay = <String, PlayerRankingReplayStats>{};
    final stats = service.aggregateFromMatches(
      matches: [match],
      filter: const PlayerRankingsFilter(),
      ballEventsByMatchId: {'match': events},
      replayStatsOut: replay,
    );
    const players = [
      PlayerModel(id: 'batter', name: 'Batter', userId: 'user1'),
      PlayerModel(id: 'bowlerA', name: 'Bowler A', userId: 'user2'),
      PlayerModel(id: 'bowlerB', name: 'Bowler B', userId: 'user3'),
    ];

    String topLabel(PlayerRankingsCategory category) => service
        .rank(
          players: players,
          filter: PlayerRankingsFilter(
            section: category.section,
            category: category,
          ),
          teamNamesById: const {},
          statsByPlayerId: stats,
          replayStatsByPlayerId: replay,
        )
        .first
        .valueLabel;

    expect(topLabel(PlayerRankingsCategory.fastestFifty), '13 balls');
    expect(topLabel(PlayerRankingsCategory.fastestHundred), '25 balls');
    expect(topLabel(PlayerRankingsCategory.bestBowlingFigures), '4/25');
    expect(topLabel(PlayerRankingsCategory.maidens), '1');
    expect(topLabel(PlayerRankingsCategory.dotBalls), '6');
  });
}
