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
      InningsCompletionPolicy.endReasonLabel(match, chase),
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
}
