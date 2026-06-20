import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/services/match_analytics_models.dart';
import 'package:crickflow/domain/services/match_phase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MatchRulesModel rules({required int totalOvers, int? powerplayOvers}) {
    return MatchRulesModel(
      cricketMatchType: CricketMatchType.limitedOvers,
      totalOvers: totalOvers,
      ballsPerOver: 6,
      powerplayOvers: powerplayOvers,
    );
  }

  group('dynamic phase ranges', () {
    test('20 overs uses 1-6, 7-15, 16-20', () {
      final ranges = MatchPhaseService.forRules(rules(totalOvers: 20));
      expect(ranges.powerplayLabel, 'Powerplay (1-6)');
      expect(ranges.middleLabel, 'Middle Overs (7-15)');
      expect(ranges.deathLabel, 'Death Overs (16-20)');
      expect(ranges.lastNOversCount, 5);
      expect(ranges.lastNOversStart, 16);
    });

    test('15 overs uses 1-5, 6-11, 12-15', () {
      final ranges = MatchPhaseService.forRules(rules(totalOvers: 15));
      expect(ranges.powerplayLabel, 'Powerplay (1-5)');
      expect(ranges.middleLabel, 'Middle Overs (6-11)');
      expect(ranges.deathLabel, 'Death Overs (12-15)');
    });

    test('10 overs uses 1-3, 4-7, 8-10', () {
      final ranges = MatchPhaseService.forRules(rules(totalOvers: 10));
      expect(ranges.powerplayLabel, 'Powerplay (1-3)');
      expect(ranges.middleLabel, 'Middle Overs (4-7)');
      expect(ranges.deathLabel, 'Death Overs (8-10)');
      expect(ranges.lastNOversCount, 5);
      expect(ranges.lastNOversStart, 6);
    });

    test('8 overs uses 1-2, 3-6, 7-8', () {
      final ranges = MatchPhaseService.forRules(rules(totalOvers: 8));
      expect(ranges.powerplayLabel, 'Powerplay (1-2)');
      expect(ranges.middleLabel, 'Middle Overs (3-6)');
      expect(ranges.deathLabel, 'Death Overs (7-8)');
    });

    test('6 overs uses 1-2, 3-4, 5-6', () {
      final ranges = MatchPhaseService.forRules(rules(totalOvers: 6));
      expect(ranges.powerplayLabel, 'Powerplay (1-2)');
      expect(ranges.middleLabel, 'Middle Overs (3-4)');
      expect(ranges.deathLabel, 'Death Overs (5-6)');
    });

    test('3 overs last N overs adapts to 3', () {
      final ranges = MatchPhaseService.forRules(rules(totalOvers: 3));
      expect(ranges.lastNOversCount, 3);
      expect(ranges.lastNOversStart, 1);
      expect(ranges.lastNOversLabel, 'Last 3 Overs');
    });

    test('2 overs last N overs adapts to 2', () {
      final ranges = MatchPhaseService.forRules(rules(totalOvers: 2));
      expect(ranges.lastNOversCount, 2);
      expect(ranges.lastNOversLabel, 'Last 2 Overs');
    });
  });

  group('classifyOver', () {
    test('classifies 20-over match dynamically', () {
      final r = rules(totalOvers: 20);
      expect(MatchPhaseService.classifyOver(1, r), OverPhaseKind.powerplay);
      expect(MatchPhaseService.classifyOver(6, r), OverPhaseKind.powerplay);
      expect(MatchPhaseService.classifyOver(7, r), OverPhaseKind.middle);
      expect(MatchPhaseService.classifyOver(15, r), OverPhaseKind.middle);
      expect(MatchPhaseService.classifyOver(16, r), OverPhaseKind.death);
      expect(MatchPhaseService.classifyOver(20, r), OverPhaseKind.death);
    });

    test('respects custom powerplay slots', () {
      final r = rules(totalOvers: 10).copyWith(
        powerplaySlots: const [
          [1, 2],
          [],
          [9, 10],
        ],
      );
      expect(MatchPhaseService.classifyOver(2, r), OverPhaseKind.powerplay);
      expect(MatchPhaseService.classifyOver(9, r), OverPhaseKind.death);
      expect(MatchPhaseService.classifyOver(5, r), OverPhaseKind.middle);
    });

    test('test match returns normal for all overs', () {
      final r = MatchRulesModel(
        cricketMatchType: CricketMatchType.testMatch,
        totalOvers: 50,
      );
      expect(MatchPhaseService.classifyOver(1, r), OverPhaseKind.normal);
      expect(MatchPhaseService.classifyOver(20, r), OverPhaseKind.normal);
    });
  });
}
