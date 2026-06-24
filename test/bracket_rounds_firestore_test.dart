import 'package:crickflow/data/models/bracket_models.dart';
import 'package:crickflow/domain/services/fixture_generator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bracketRounds Firestore encoding', () {
    test('round-trip preserves slots without nested arrays', () {
      const slot = BracketSlotModel(
        matchId: 'm1',
        teamAId: 'a',
        teamBId: 'b',
        teamAName: 'Team A',
        teamBName: 'Team B',
      );
      const tbd = BracketSlotModel(teamAName: 'TBD', teamBName: 'TBD');

      final rounds = [
        [slot],
        [tbd],
      ];

      final encoded = bracketRoundsToFirestore(rounds);
      expect(encoded, isNot(contains(isA<List<List>>())));

      for (final round in encoded) {
        expect(round['slots'], isA<List>());
        for (final slotMap in round['slots'] as List) {
          expect(slotMap, isA<Map>());
        }
      }

      final decoded = bracketRoundsFromFirestore(encoded);
      expect(decoded.length, 2);
      expect(decoded[0].single.teamAName, 'Team A');
      expect(decoded[1].single.teamAName, 'TBD');
    });
  });

  group('knockout fixture generator', () {
    final service = FixtureGeneratorService();

    test('builds bracket skeleton for 3 teams (bye to power of 2)', () {
      final roundOne = [
        const BracketSlotModel(
          matchId: 'm1',
          teamAName: 'A',
          teamBName: 'B',
        ),
        const BracketSlotModel(
          matchId: 'm2',
          teamAName: 'C',
          teamBName: 'BYE',
          winnerTeamId: 'c',
          winnerTeamName: 'C',
        ),
      ];

      final skeleton = service.buildBracketSkeleton(
        teamCount: 3,
        roundOneSlots: roundOne,
      );

      expect(skeleton.length, 2);
      expect(skeleton[0].length, 2);
      expect(skeleton[1].length, 1);
      expect(skeleton[1].single.teamAName, 'TBD');
    });

    test('first round pairings pad to next power of two', () {
      final pairings = service.knockoutFirstRoundPairings([
        (id: '1', name: 'One'),
        (id: '2', name: 'Two'),
        (id: '3', name: 'Three'),
      ]);

      expect(pairings.length, 2);
      expect(pairings.any((p) => p.teamBName == 'BYE'), isTrue);
    });
  });
}
