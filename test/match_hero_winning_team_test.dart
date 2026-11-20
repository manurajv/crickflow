import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/domain/services/badge_service.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _match({String? winner, String? potm}) => MatchModel(
      id: 'm1',
      title: 'A vs B',
      teamAId: 'a',
      teamBId: 'b',
      winnerTeamId: winner,
      playerOfMatchId: potm,
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          batsmen: [
            BatsmanInningsModel(playerId: 'a1', playerName: 'A1', runs: 40),
          ],
          bowlers: [
            BowlerInningsModel(playerId: 'b2', playerName: 'B2', wickets: 1),
          ],
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          batsmen: [
            // Losing-team top scorer outscores everyone.
            BatsmanInningsModel(playerId: 'b1', playerName: 'B1', runs: 85),
          ],
          bowlers: [
            BowlerInningsModel(playerId: 'a2', playerName: 'A2', wickets: 1),
          ],
        ),
      ],
    );

void main() {
  final service = BadgeService();

  group('Man of the Match selection', () {
    test('decided match: hero comes from the winning team', () {
      final hero = service.pickMatchHero(_match(winner: 'a'));
      expect(hero?.playerId, 'a1');
    });

    test('winner passed explicitly (completion path) is respected', () {
      final hero = service.pickMatchHero(_match(), winnerTeamId: 'a');
      expect(hero?.playerId, 'a1');
    });

    test('tie / no result: best performer from either team', () {
      final hero = service.pickMatchHero(_match());
      expect(hero?.playerId, 'b1');
    });
  });

  group('MoM badge eligibility', () {
    test('winning-team POTM is eligible', () {
      expect(
        BadgeService.isEligibleManOfTheMatch(
          _match(winner: 'a', potm: 'a1'),
          'a1',
        ),
        isTrue,
      );
    });

    test('legacy losing-team POTM does not unlock the badge', () {
      expect(
        BadgeService.isEligibleManOfTheMatch(
          _match(winner: 'a', potm: 'b1'),
          'b1',
        ),
        isFalse,
      );
    });

    test('other players never qualify', () {
      expect(
        BadgeService.isEligibleManOfTheMatch(
          _match(winner: 'a', potm: 'a1'),
          'a2',
        ),
        isFalse,
      );
    });

    test('no result: stored POTM is eligible', () {
      expect(
        BadgeService.isEligibleManOfTheMatch(_match(potm: 'b1'), 'b1'),
        isTrue,
      );
    });
  });
}
