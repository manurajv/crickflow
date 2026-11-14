import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('indoor free hit default', () {
    test('indoor match type defaults free hit off', () {
      final rules = MatchRulesModel.forMatchType(CricketMatchType.indoor);
      expect(rules.isIndoor, isTrue);
      expect(rules.freeHitEnabled, isFalse);
    });

    test('tennis/indoor preset defaults free hit off', () {
      expect(MatchRulesModel.tennisCricket().freeHitEnabled, isFalse);
    });

    test('outdoor match types keep free hit on', () {
      expect(
        MatchRulesModel.forMatchType(CricketMatchType.limitedOvers)
            .freeHitEnabled,
        isTrue,
      );
      expect(
        MatchRulesModel.forMatchType(CricketMatchType.testMatch).freeHitEnabled,
        isTrue,
      );
    });

    test('user can still enable free hit for indoor', () {
      final rules = MatchRulesModel.forMatchType(CricketMatchType.indoor)
          .copyWith(freeHitEnabled: true);
      expect(rules.freeHitEnabled, isTrue);
      expect(MatchRulesModel.fromMap(rules.toMap()).freeHitEnabled, isTrue);
    });
  });
}
