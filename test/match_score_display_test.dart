import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/utils/match_score_display.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MatchModel twoInningsMatch() {
    return MatchModel(
      id: 'm1',
      title: 'A vs B',
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      status: MatchStatus.live,
      currentInningsIndex: 1,
      innings: [
        const InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 120,
          totalWickets: 3,
          legalBalls: 120,
        ),
        const InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.inProgress,
          totalRuns: 45,
          totalWickets: 1,
          legalBalls: 30,
        ),
      ],
    );
  }

  test('shows both team scores after innings swap', () {
    final match = twoInningsMatch();
    expect(MatchScoreDisplay.scoreForTeam(match, 'a'), '120/3');
    expect(MatchScoreDisplay.scoreForTeam(match, 'b'), '45/1');
    expect(MatchScoreDisplay.isTeamBattingNow(match, 'b'), isTrue);
    expect(MatchScoreDisplay.isTeamBattingNow(match, 'a'), isFalse);
  });

  test('first innings summary includes target and RR', () {
    final match = MatchModel(
      id: 'm1',
      title: 'A vs B',
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      status: MatchStatus.inningsBreak,
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 150,
          totalWickets: 5,
          legalBalls: 120,
        ),
      ],
    );
    final summary = MatchScoreDisplay.completedFirstInnings(match)!;
    expect(summary.runs, 150);
    expect(summary.target, 151);
    expect(summary.battingTeamName, 'Team A');
    expect(summary.runRate, closeTo(7.5, 0.01));
  });

  test('completed result line for finished match', () {
    final match = MatchModel(
      id: 'm1',
      title: 'A vs B',
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Team A',
      teamBName: 'Team B',
      status: MatchStatus.completed,
      winnerTeamId: 'a',
      innings: const [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 160,
          totalWickets: 6,
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.completed,
          totalRuns: 145,
          totalWickets: 10,
        ),
      ],
    );
    expect(
      MatchScoreDisplay.completedResultLine(match),
      'Team A won by 15 runs',
    );
    expect(MatchScoreDisplay.isTeamWinner(match, 'a'), isTrue);
    expect(MatchScoreDisplay.isTeamWinner(match, 'b'), isFalse);
  });
}
