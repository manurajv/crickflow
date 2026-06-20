import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/services/match_mvp_models.dart';
import 'package:crickflow/domain/services/match_mvp_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const format = MvpFormatContext(
    totalOvers: 20,
    ballsPerOver: 6,
    totalLegalBalls: 120,
    isTestMatch: false,
    parRunsPerInnings: 140,
    parStrikeRate: 115,
    parEconomy: 7,
    strikeRateWeight: 0.72,
    economyWeight: 0.85,
    runsWeight: 1,
  );

  MvpPlayerScore player({
    required String id,
    required String teamId,
    required double total,
    int rank = 0,
  }) {
    return MvpPlayerScore(
      playerId: id,
      playerName: id,
      teamId: teamId,
      teamName: teamId,
      rank: rank,
      battingMvp: total,
      bowlingMvp: 0,
      fieldingMvp: 0,
      clutchBonus: 0,
      partnershipBonus: 0,
      totalMvp: total,
    );
  }

  group('MVP awards', () {
    test('Player Of The Match is rank 1', () {
      final board = MatchMvpService.applyAwards(
        players: [
          player(id: 'a1', teamId: 'a', total: 6.2, rank: 1),
          player(id: 'a2', teamId: 'a', total: 5.1, rank: 2),
        ],
        losingTeamId: 'b',
        winnerTeamId: 'a',
        teamAId: 'a',
        teamBId: 'b',
        format: format,
      );

      expect(board.playerOfTheMatch?.playerId, 'a1');
    });

    test('Fighter is highest overall rank from losing top 3', () {
      final board = MatchMvpService.applyAwards(
        players: [
          player(id: 'a1', teamId: 'a', total: 6.2, rank: 1),
          player(id: 'a2', teamId: 'a', total: 5.6, rank: 2),
          player(id: 'b1', teamId: 'b', total: 4.8, rank: 3),
          player(id: 'b2', teamId: 'b', total: 4.1, rank: 4),
        ],
        losingTeamId: 'b',
        winnerTeamId: 'a',
        teamAId: 'a',
        teamBId: 'b',
        format: format,
      );

      expect(board.fighterOfTheMatch?.playerId, 'b1');
      expect(board.fighterOfTheMatch?.rank, 3);
    });

    test('No Fighter when MVP winner is from losing team', () {
      final board = MatchMvpService.applyAwards(
        players: [
          player(id: 'b1', teamId: 'b', total: 6.2, rank: 1),
          player(id: 'a1', teamId: 'a', total: 5.6, rank: 2),
        ],
        losingTeamId: 'b',
        winnerTeamId: 'a',
        teamAId: 'a',
        teamBId: 'b',
        format: format,
      );

      expect(board.playerOfTheMatch?.playerId, 'b1');
      expect(board.fighterOfTheMatch, isNull);
    });
  });

  group('format-aware scoring', () {
    final service = MatchMvpService();

    InningsModel lineup({
      required String strikerId,
      required String bowlerId,
    }) {
      return InningsModel(
        inningsNumber: 1,
        battingTeamId: 'a',
        bowlingTeamId: 'b',
        status: InningsStatus.inProgress,
        strikerId: strikerId,
        nonStrikerId: 'a2',
        batsmen: [
          BatsmanInningsModel(playerId: strikerId, playerName: 'Striker'),
          const BatsmanInningsModel(playerId: 'a2', playerName: 'Non'),
        ],
        bowlers: [
          BowlerInningsModel(playerId: bowlerId, playerName: 'Bowler'),
        ],
      );
    }

    List<BallEventModel> thirtyRunKnock({required int ballsPerOver}) {
      final events = <BallEventModel>[];
      for (var i = 0; i < 12; i++) {
        events.add(
          BallEventModel(
            id: 'e$i',
            matchId: 'm1',
            inningsNumber: 1,
            overNumber: (i ~/ ballsPerOver) + 1,
            ballInOver: (i % ballsPerOver) + 1,
            eventType: BallEventType.runs,
            runs: i < 10 ? 2 : 1,
            batsmanRuns: i < 10 ? 2 : 1,
            isLegalDelivery: true,
            countsInOver: true,
            countsToBowler: true,
            sequence: i + 1,
            strikerId: 'a1',
            nonStrikerId: 'a2',
            bowlerId: 'b1',
          ),
        );
      }
      return events;
    }

    MatchModel matchWith({required int totalOvers, required int ballsPerOver}) {
      return MatchModel(
        id: 'm1',
        title: 'A vs B',
        teamAId: 'a',
        teamBId: 'b',
        teamAName: 'A',
        teamBName: 'B',
        status: MatchStatus.completed,
        winnerTeamId: 'a',
        rules: MatchRulesModel(
          totalOvers: totalOvers,
          ballsPerOver: ballsPerOver,
        ),
        innings: [
          lineup(strikerId: 'a1', bowlerId: 'b1'),
        ],
      );
    }

    test('30 runs worth more in 5-over than 50-over match', () {
      final shortBoard = service.build(
        match: matchWith(totalOvers: 5, ballsPerOver: 6),
        ballEvents: thirtyRunKnock(ballsPerOver: 6),
      );
      final longBoard = service.build(
        match: matchWith(totalOvers: 50, ballsPerOver: 6),
        ballEvents: thirtyRunKnock(ballsPerOver: 6),
      );

      final shortScore = shortBoard.players
          .firstWhere((p) => p.playerId == 'a1')
          .battingMvp;
      final longScore = longBoard.players
          .firstWhere((p) => p.playerId == 'a1')
          .battingMvp;

      expect(shortScore, greaterThan(longScore));
    });

    test('supports custom balls per over', () {
      final board = service.build(
        match: matchWith(totalOvers: 8, ballsPerOver: 8),
        ballEvents: thirtyRunKnock(ballsPerOver: 8),
      );

      expect(board.hasData, isTrue);
      expect(board.formatContext?.ballsPerOver, 8);
    });
  });
}
