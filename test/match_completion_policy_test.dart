import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/scoring/innings_completion_policy.dart';
import 'package:crickflow/domain/scoring/match_completion_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MatchModel baseMatch({
    List<InningsModel> innings = const [],
    MatchRulesModel rules = const MatchRulesModel(),
    int currentInningsIndex = 0,
  }) {
    return MatchModel(
      id: 'm1',
      title: 'A vs B',
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      rules: rules,
      innings: innings,
      currentInningsIndex: currentInningsIndex,
    );
  }

  test('second innings target reached ends innings', () {
    final match = baseMatch(
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 152,
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.inProgress,
          totalRuns: 153,
          targetRuns: 153,
        ),
      ],
      currentInningsIndex: 1,
    );
    final chase = match.innings[1];
    expect(InningsCompletionPolicy.isTargetReached(match, chase), isTrue);
    expect(InningsCompletionPolicy.isInningsComplete(match, chase), isTrue);
    expect(
      InningsCompletionPolicy.completionReasonLabel(match, chase),
      'Target reached',
    );
  });

  test('won by wickets when target chased', () {
    final match = baseMatch(
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 152,
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.completed,
          totalRuns: 153,
          totalWickets: 4,
        ),
      ],
    );
    final result = MatchCompletionPolicy.compute(match);
    expect(result.winnerTeamId, 'b');
    expect(result.summary, 'Team B won by 6 wickets');
    expect(result.method, MatchResultMethod.wickets);
  });

  test('won by runs when chase falls short', () {
    final match = baseMatch(
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 180,
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.completed,
          totalRuns: 156,
          totalWickets: 10,
        ),
      ],
    );
    final result = MatchCompletionPolicy.compute(match);
    expect(result.winnerTeamId, 'a');
    expect(result.summary, 'Team A won by 24 runs');
    expect(result.method, MatchResultMethod.runs);
  });

  test('tie offers super over when enabled', () {
    final match = baseMatch(
      rules: const MatchRulesModel(superOverEnabled: true),
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 150,
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.completed,
          totalRuns: 150,
          totalWickets: 10,
        ),
      ],
    );
    expect(MatchCompletionPolicy.shouldOfferSuperOver(match), isTrue);
    final result = MatchCompletionPolicy.compute(match);
    expect(result.isTie, isTrue);
    expect(result.offerSuperOver, isTrue);
  });

  test('tie without super over flag', () {
    final match = baseMatch(
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 100,
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.completed,
          totalRuns: 100,
        ),
      ],
    );
    final result = MatchCompletionPolicy.compute(match);
    expect(result.summary, 'Match tied');
    expect(result.winnerTeamId, isNull);
  });

  test('completed match derives result when innings status lags', () {
    final match = MatchModel(
      id: 'm1',
      title: 'A vs B',
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      status: MatchStatus.completed,
      resultSummary: 'Match completed',
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 160,
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.inProgress,
          totalRuns: 145,
          totalWickets: 10,
        ),
      ],
    );
    final result = MatchCompletionPolicy.compute(match);
    expect(result.summary, 'Team A won by 15 runs');
    expect(result.winnerTeamId, 'a');
  });

  test('chase runs needed decreases as score increases', () {
    final match = baseMatch(
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 150,
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.inProgress,
          totalRuns: 140,
          targetRuns: 151,
        ),
      ],
      currentInningsIndex: 1,
    );
    final chase = match.innings[1];
    expect(InningsCompletionPolicy.remainingRuns(match, chase), 11);

    final updatedChase = InningsModel(
      inningsNumber: 2,
      battingTeamId: 'b',
      bowlingTeamId: 'a',
      status: InningsStatus.inProgress,
      totalRuns: 151,
      targetRuns: 151,
    );
    expect(InningsCompletionPolicy.isTargetReached(match, updatedChase), isTrue);
    expect(InningsCompletionPolicy.remainingRuns(match, updatedChase), 0);
  });

  test('first innings fallback does not use chasing innings as target base', () {
    // Simulates corrupted state: only chasing innings in list with number 2.
    final match = baseMatch(
      innings: const [
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.inProgress,
          totalRuns: 50,
          targetRuns: 151,
        ),
      ],
    );
    final chase = match.innings.first;
    expect(InningsCompletionPolicy.chaseTarget(match, chase), 151);
    expect(InningsCompletionPolicy.remainingRuns(match, chase), 101);
  });

  test('quick match limited overs treats first innings as not match complete', () {
    final match = MatchModel(
      id: 'qm1',
      title: 'A vs B',
      matchMode: MatchMode.quick,
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      rules: const MatchRulesModel(
        cricketMatchType: CricketMatchType.limitedOvers,
        maxInnings: 1,
      ),
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 120,
          totalWickets: 8,
          legalBalls: 120,
        ),
      ],
    );
    expect(match.effectiveMaxInnings, 2);
    expect(MatchCompletionPolicy.isMatchComplete(match), isFalse);
    expect(
      MatchCompletionPolicy.shouldContinueAfterInnings(
        match,
        match.innings.first,
      ),
      isTrue,
    );
  });

  test('quick match indoor first innings continues to chase', () {
    final match = MatchModel(
      id: 'qm-indoor',
      title: 'A vs B',
      matchMode: MatchMode.quick,
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      rules: const MatchRulesModel(
        cricketMatchType: CricketMatchType.indoor,
        maxInnings: 1,
        totalOvers: 6,
      ),
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 48,
          totalWickets: 5,
          legalBalls: 36,
        ),
      ],
    );
    expect(match.effectiveMaxInnings, 2);
    expect(MatchCompletionPolicy.isMatchComplete(match), isFalse);
    expect(
      MatchCompletionPolicy.shouldContinueAfterInnings(
        match,
        match.innings.first,
      ),
      isTrue,
    );
  });

  test('quick match continues after innings 1 even if innings 2 already exists',
      () {
    final match = MatchModel(
      id: 'qm-stale',
      title: 'A vs B',
      matchMode: MatchMode.quick,
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      rules: const MatchRulesModel(
        cricketMatchType: CricketMatchType.limitedOvers,
        maxInnings: 2,
      ),
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 120,
          totalWickets: 8,
          legalBalls: 120,
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.inProgress,
          totalRuns: 0,
          totalWickets: 0,
          legalBalls: 0,
        ),
      ],
    );
    expect(
      MatchCompletionPolicy.shouldContinueAfterInnings(
        match,
        match.innings.first,
      ),
      isTrue,
    );
  });

  test('quick match indoor also requires second innings', () {
    final match = MatchModel(
      id: 'qm2',
      title: 'A vs B',
      matchMode: MatchMode.quick,
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      rules: const MatchRulesModel(
        cricketMatchType: CricketMatchType.indoor,
        maxInnings: 1,
        totalOvers: 6,
        ballsPerOver: 5,
      ),
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 80,
          legalBalls: 30,
        ),
      ],
    );
    expect(match.effectiveMaxInnings, 2);
    expect(MatchCompletionPolicy.isMatchComplete(match), isFalse);
    expect(MatchCompletionPolicy.compute(match).winnerTeamId, isNull);
  });

  test('quick match last over needs full ballsPerOver after long prior over', () {
    // 2 overs × 5 balls; over 1 continued to 6 legal balls, then ended.
    // Last over must still allow 5 balls — must not end on the 4th.
    final match = MatchModel(
      id: 'qm3',
      title: 'A vs B',
      matchMode: MatchMode.quick,
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      rules: const MatchRulesModel(
        totalOvers: 2,
        ballsPerOver: 5,
        maxInnings: 2,
      ),
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          legalBalls: 10, // 6 in over 1 + 4 in over 2
          currentOverNumber: 2,
          currentOverStartLegalBalls: 6,
        ),
      ],
    );
    final inn = match.currentInnings!;
    expect(InningsCompletionPolicy.isOversComplete(match, inn), isFalse);
    expect(InningsCompletionPolicy.isInningsComplete(match, inn), isFalse);
    expect(InningsCompletionPolicy.remainingBalls(match, inn), 1);

    final afterFifth = MatchModel(
      id: 'qm3',
      title: 'A vs B',
      matchMode: MatchMode.quick,
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      rules: const MatchRulesModel(
        totalOvers: 2,
        ballsPerOver: 5,
        maxInnings: 2,
      ),
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          legalBalls: 11, // 6 + 5
          currentOverNumber: 2,
          currentOverStartLegalBalls: 6,
        ),
      ],
    );
    expect(
      InningsCompletionPolicy.isOversComplete(
        afterFifth,
        afterFifth.currentInnings!,
      ),
      isTrue,
    );
  });

  test('normal match overs complete still uses total legal balls', () {
    // Normal match: 2 overs × 5 = 10 balls — complete at 10 even mid "display".
    final match = MatchModel(
      id: 'nm1',
      title: 'A vs B',
      matchMode: MatchMode.normal,
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      rules: const MatchRulesModel(
        totalOvers: 2,
        ballsPerOver: 5,
        maxInnings: 2,
      ),
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          legalBalls: 10,
          currentOverNumber: 2,
          currentOverStartLegalBalls: 6,
        ),
      ],
    );
    expect(
      InningsCompletionPolicy.isOversComplete(match, match.currentInnings!),
      isTrue,
    );
  });
}
