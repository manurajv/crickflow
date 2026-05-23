import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/data/models/match_setup_draft_models.dart';
import 'package:crickflow/features/scoring/presentation/utils/scoring_display_utils.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _matchWithToss({
  int legalBalls = 0,
  InningsStatus status = InningsStatus.inProgress,
  MatchStatus matchStatus = MatchStatus.live,
}) {
  return MatchModel(
    id: 'm1',
    title: 'A vs B',
    matchType: MatchType.single,
    status: matchStatus,
    teamAId: 'a',
    teamBId: 'b',
    teamAName: 'Team A',
    teamBName: 'Team B',
    rules: const MatchRulesModel(),
    innings: [
      InningsModel(
        inningsNumber: 1,
        battingTeamId: 'a',
        bowlingTeamId: 'b',
        status: status,
        legalBalls: legalBalls,
      ),
    ],
    setup: const MatchSetupData(
      tossWinnerIsTeamA: true,
      tossWinnerBatsFirst: true,
    ),
  );
}

void main() {
  group('ScoringDisplayUtils toss', () {
    test('tossSummaryLine formats winner and election', () {
      final line = ScoringDisplayUtils.tossSummaryLine(_matchWithToss());
      expect(line, 'Team A won the toss and elected to bat');
    });

    test('showTossLineDuringFirstInnings true within 3 overs', () {
      final match = _matchWithToss(legalBalls: 11); // 1.5 overs in T20
      final inn = match.innings.first;
      expect(
        ScoringDisplayUtils.showTossLineDuringFirstInnings(
          match,
          inn,
          match.rules,
        ),
        isTrue,
      );
    });

    test('showTossLineDuringFirstInnings false after 3 overs', () {
      final match = _matchWithToss(legalBalls: 18); // 3 overs
      final inn = match.innings.first;
      expect(
        ScoringDisplayUtils.showTossLineDuringFirstInnings(
          match,
          inn,
          match.rules,
        ),
        isFalse,
      );
    });

    test('canEditTossDecision only in initial first innings state', () {
      expect(ScoringDisplayUtils.canEditTossDecision(_matchWithToss()), isTrue);
      expect(
        ScoringDisplayUtils.canEditTossDecision(
          _matchWithToss(legalBalls: 1),
        ),
        isFalse,
      );
      expect(
        ScoringDisplayUtils.canEditTossDecision(
          _matchWithToss(matchStatus: MatchStatus.completed),
        ),
        isFalse,
      );
    });
  });
}
