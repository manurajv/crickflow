import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchRulesModel overs per bowler', () {
    test('calculateOversPerBowler uses ceil(totalOvers / 5)', () {
      expect(MatchRulesModel.calculateOversPerBowler(5), 1);
      expect(MatchRulesModel.calculateOversPerBowler(6), 2);
      expect(MatchRulesModel.calculateOversPerBowler(10), 2);
      expect(MatchRulesModel.calculateOversPerBowler(11), 3);
      expect(MatchRulesModel.calculateOversPerBowler(20), 4);
      expect(MatchRulesModel.calculateOversPerBowler(30), 6);
    });

    test('withTotalOvers auto-updates when not manual', () {
      final rules = MatchRulesModel.standardT20();
      final updated = rules.withTotalOvers(12);
      expect(updated.totalOvers, 12);
      expect(updated.oversPerBowler, 3);
      expect(updated.isManualOversPerBowler, isFalse);
    });

    test('withTotalOvers preserves manual overs per bowler', () {
      final rules = MatchRulesModel.standardT20()
          .withManualOversPerBowler(3);
      final updated = rules.withTotalOvers(12);
      expect(updated.totalOvers, 12);
      expect(updated.oversPerBowler, 3);
      expect(updated.isManualOversPerBowler, isTrue);
    });

    test('resetOversPerBowlerToAuto clears manual lock', () {
      final rules = MatchRulesModel.standardT20()
          .withManualOversPerBowler(3)
          .withTotalOvers(15);
      final reset = rules.resetOversPerBowlerToAuto();
      expect(reset.oversPerBowler, 3);
      expect(reset.isManualOversPerBowler, isFalse);
    });

    test('serializes isManualOversPerBowler and ballType', () {
      final rules = MatchRulesModel.standardT20().withManualOversPerBowler(3);
      final map = rules.toMap();
      expect(map['ballType'], 'tennis');
      expect(map['isManualOversPerBowler'], isTrue);
      expect(map['oversPerBowler'], 3);

      final restored = MatchRulesModel.fromMap(map);
      expect(restored.isManualOversPerBowler, isTrue);
      expect(restored.oversPerBowler, 3);
    });

    test('clampOversPerBowler enforces 1..totalOvers', () {
      expect(MatchRulesModel.clampOversPerBowler(0, 10), 1);
      expect(MatchRulesModel.clampOversPerBowler(12, 10), 10);
      expect(MatchRulesModel.clampOversPerBowler(4, 10), 4);
    });
  });
}
