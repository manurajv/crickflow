import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/features/scoring/presentation/utils/scoring_display_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  InningsModel inn({
    required List<BatsmanInningsModel> batsmen,
    String? strikerId,
    String? nonStrikerId,
  }) {
    return InningsModel(
      inningsNumber: 1,
      battingTeamId: 'a',
      bowlingTeamId: 'b',
      status: InningsStatus.inProgress,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      batsmen: batsmen,
    );
  }

  test('just-retired hurt batter excluded from immediate incoming picker', () {
    final innings = inn(
      strikerId: null,
      nonStrikerId: 'ns',
      batsmen: const [
        BatsmanInningsModel(
          playerId: 'rh1',
          playerName: 'Hurt',
          runs: 20,
          balls: 15,
          retiredHurt: true,
          isEligibleToReturn: true,
        ),
        BatsmanInningsModel(playerId: 'ns', playerName: 'Non'),
        BatsmanInningsModel(playerId: 'fresh', playerName: 'Fresh'),
      ],
    );

    final squad = ['rh1', 'ns', 'fresh', 'fresh2'];
    final eligible = ScoringDisplayUtils.eligibleBatters(
      innings,
      squad,
      idOf: (id) => id,
      excludePlayerId: 'ns',
      excludeRecentlyRetiredHurtId: 'rh1',
    );

    expect(eligible, isNot(contains('rh1')));
    expect(eligible, contains('fresh'));
    expect(eligible, contains('fresh2'));
  });

  test('previously retired hurt becomes selectable after later vacancy', () {
    final innings = inn(
      strikerId: null,
      nonStrikerId: 'ns',
      batsmen: const [
        BatsmanInningsModel(
          playerId: 'rh1',
          playerName: 'Hurt',
          runs: 20,
          balls: 15,
          retiredHurt: true,
          isEligibleToReturn: true,
        ),
        BatsmanInningsModel(
          playerId: 'out1',
          playerName: 'Out',
          isOut: true,
          dismissalInfo: 'bowled',
        ),
        BatsmanInningsModel(playerId: 'ns', playerName: 'Non'),
        BatsmanInningsModel(playerId: 'fresh', playerName: 'Fresh'),
      ],
    );

    // After a real wicket — no excludeRecently — RH returnable is included.
    final eligible = ScoringDisplayUtils.eligibleBatters(
      innings,
      ['rh1', 'out1', 'ns', 'fresh'],
      idOf: (id) => id,
      excludePlayerId: 'ns',
    );

    expect(eligible, contains('rh1'));
    expect(eligible, contains('fresh'));
    expect(eligible, isNot(contains('out1')));
  });

  test('retired out never returns; RH returns when no fresh batters remain', () {
    final innings = inn(
      strikerId: null,
      nonStrikerId: 'ns',
      batsmen: const [
        BatsmanInningsModel(
          playerId: 'rh1',
          retiredHurt: true,
          isEligibleToReturn: true,
          runs: 10,
        ),
        BatsmanInningsModel(
          playerId: 'ro1',
          isOut: true,
          dismissalInfo: 'Retired Out',
        ),
        BatsmanInningsModel(playerId: 'ns'),
      ],
    );

    final eligible = ScoringDisplayUtils.eligibleBatters(
      innings,
      ['rh1', 'ro1', 'ns'],
      idOf: (id) => id,
      excludePlayerId: 'ns',
      includeReturningRetiredHurt: false,
    );

    expect(eligible, contains('rh1'));
    expect(eligible, isNot(contains('ro1')));
  });
}
