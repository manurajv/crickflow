import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/utils/match_setup_navigation.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/data/models/match_setup_draft_models.dart';
import 'package:crickflow/domain/scoring/match_lifecycle.dart';
import 'package:crickflow/shared/providers/start_match_draft_provider.dart';

void main() {
  MatchModel match({
    MatchStatus status = MatchStatus.tossCompleted,
    List<InningsModel> innings = const [],
  }) {
    return MatchModel(
      id: 'm1',
      title: 'A vs B',
      status: status,
      teamAName: 'A',
      teamBName: 'B',
      rules: const MatchRulesModel(),
      innings: innings,
    );
  }

  test('hasScoringStarted detects balls under tossCompleted', () {
    final m = match(
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          legalBalls: 4,
          totalRuns: 8,
          strikerId: 's1',
          nonStrikerId: 's2',
          currentBowlerId: 'b1',
        ),
      ],
    );

    expect(MatchLifecycle.hasScoringStarted(m), isTrue);
    expect(MatchLifecycle.canOpenScoringScreen(m), isTrue);
    expect(MatchLifecycle.needsStartInnings(m), isFalse);
    expect(MatchLifecycle.isActivelyLive(m), isTrue);
  });

  test('pure tossCompleted still needs start innings', () {
    final m = match(
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
        ),
      ],
    );

    expect(MatchLifecycle.hasScoringStarted(m), isFalse);
    expect(MatchLifecycle.needsStartInnings(m), isTrue);
    expect(MatchLifecycle.isActivelyLive(m), isFalse);
    expect(MatchLifecycle.isEffectivelyLive(m), isTrue);
  });

  test('buildMatchAfterToss does not regress live status', () {
    final existing = match(
      status: MatchStatus.live,
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          legalBalls: 4,
          totalRuns: 8,
        ),
      ],
    );
    final draft = StartMatchDraft(
      matchId: existing.id,
      teamAName: 'A',
      teamBName: 'B',
      rules: existing.rules,
      isExistingMatch: true,
    );
    final setup = const MatchSetupData(
      coinResult: 'heads',
      tossWinnerIsTeamA: true,
      tossWinnerBatsFirst: true,
    );

    final saved = buildMatchAfterToss(
      draft: draft,
      setup: setup,
      existing: existing,
    );

    expect(saved.status, MatchStatus.live);
    expect(saved.innings.first.legalBalls, 4);
  });

  test('statusAfterToss promotes scored tossCompleted to live', () {
    final existing = match(
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          legalBalls: 4,
        ),
      ],
    );
    expect(statusAfterToss(existing), MatchStatus.live);
  });
}
