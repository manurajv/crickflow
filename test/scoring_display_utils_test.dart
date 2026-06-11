import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
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

  group('ballBubbleLabel', () {
    test('run out with no runs shows W', () {
      final event = BallEventModel(
        id: 'e1',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 1,
        eventType: BallEventType.wicket,
        isWicket: true,
        wicketType: WicketType.runOut,
        runs: 0,
        sequence: 1,
      );
      expect(ScoringDisplayUtils.ballBubbleLabel(event), 'W');
    });

    test('run out with completed runs shows W+runs', () {
      final event = BallEventModel(
        id: 'e1',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 1,
        eventType: BallEventType.wicket,
        isWicket: true,
        wicketType: WicketType.runOut,
        runs: 2,
        batsmanRuns: 2,
        sequence: 1,
      );
      expect(ScoringDisplayUtils.ballBubbleLabel(event), 'W+2');
    });

    test('non run out wicket shows W regardless of runs', () {
      final event = BallEventModel(
        id: 'e1',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 1,
        eventType: BallEventType.wicket,
        isWicket: true,
        wicketType: WicketType.caught,
        runs: 0,
        sequence: 1,
      );
      expect(ScoringDisplayUtils.ballBubbleLabel(event), 'W');
    });
  });

  group('batsmanOverStats', () {
    BallEventModel _event({
      required String strikerId,
      BallEventType type = BallEventType.runs,
      int batsmanRuns = 0,
      int runs = 0,
      bool isLegal = true,
      WicketType? wicketType,
      bool isWicket = false,
    }) {
      return BallEventModel(
        id: 'e',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 1,
        eventType: type,
        runs: runs > 0 ? runs : batsmanRuns,
        batsmanRuns: batsmanRuns,
        isLegalDelivery: isLegal,
        strikerId: strikerId,
        isWicket: isWicket,
        wicketType: wicketType,
        sequence: 1,
      );
    }

    test('sums runs and balls for striker deliveries in the over', () {
      final events = [
        _event(strikerId: 's1', batsmanRuns: 4, runs: 4),
        _event(strikerId: 's1', batsmanRuns: 0, runs: 0),
        _event(strikerId: 's1', batsmanRuns: 1, runs: 1),
        _event(strikerId: 's2', batsmanRuns: 2, runs: 2),
      ];
      expect(
        ScoringDisplayUtils.batsmanOverStats('s1', events),
        (runs: 5, balls: 3),
      );
      expect(
        ScoringDisplayUtils.batsmanOverStats('s2', events),
        (runs: 2, balls: 1),
      );
    });

    test('wide and no-ball credit runs but not balls faced', () {
      final wide = BallEventModel(
        id: 'w',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 1,
        eventType: BallEventType.wide,
        runs: 2,
        batsmanRuns: 0,
        isLegalDelivery: false,
        strikerId: 's1',
        sequence: 1,
      );
      final nb = BallEventModel(
        id: 'n',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 1,
        eventType: BallEventType.noBall,
        runs: 2,
        batsmanRuns: 1,
        isLegalDelivery: false,
        strikerId: 's1',
        sequence: 2,
      );
      expect(
        ScoringDisplayUtils.batsmanOverStats('s1', [wide, nb]),
        (runs: 1, balls: 0),
      );
    });

    test('run out with completed runs credits striker', () {
      final ro = _event(
        strikerId: 's1',
        type: BallEventType.wicket,
        batsmanRuns: 2,
        runs: 2,
        wicketType: WicketType.runOut,
        isWicket: true,
      );
      expect(
        ScoringDisplayUtils.batsmanOverStats('s1', [ro]),
        (runs: 2, balls: 1),
      );
    });
  });
}
