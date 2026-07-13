import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/dismissal_fielder.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/scoring/ball_event_aggregator.dart';
import 'package:crickflow/domain/scoring/scoring_integrity_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MatchModel baseMatch() {
    return MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      rules: const MatchRulesModel(),
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          strikerId: 'striker',
          nonStrikerId: 'non_striker',
          currentBowlerId: 'bowler',
          batsmen: const [
            BatsmanInningsModel(playerId: 'striker', playerName: 'Striker'),
            BatsmanInningsModel(
              playerId: 'non_striker',
              playerName: 'Non-striker',
            ),
            BatsmanInningsModel(playerId: 'batter3', playerName: 'Batter 3'),
          ],
          bowlers: const [
            BowlerInningsModel(playerId: 'bowler', playerName: 'Bowler'),
          ],
        ),
      ],
    );
  }

  BallEventModel event({
    required int sequence,
    required BallEventType type,
    int runs = 0,
    String? strikerId,
    String? nonStrikerId,
    WicketType? wicketType,
    String? dismissedPlayerId,
    bool preserveCreaseOnEndOver = false,
  }) {
    return BallEventModel(
      id: 'e$sequence',
      matchId: 'm1',
      inningsNumber: 1,
      overNumber: 1,
      ballInOver: sequence,
      eventType: type,
      runs: runs,
      batsmanRuns: runs,
      strikerId: strikerId ?? 'striker',
      nonStrikerId: nonStrikerId ?? 'non_striker',
      bowlerId: 'bowler',
      wicketType: wicketType,
      dismissedPlayerId: dismissedPlayerId,
      isWicket: wicketType != null,
      preserveCreaseOnEndOver: preserveCreaseOnEndOver,
      sequence: sequence,
      fielders: wicketType == WicketType.runOut
          ? const [
              DismissalFielder(playerId: 'fielder1', playerName: 'Fielder'),
            ]
          : const [],
    );
  }

  test('reprojectMatchFromEvents repairs stale striker on cached innings', () {
    final events = [
      event(sequence: 1, type: BallEventType.runs, runs: 1),
      event(
        sequence: 2,
        type: BallEventType.wicket,
        wicketType: WicketType.runOut,
        dismissedPlayerId: 'striker',
      ),
      BallEventModel(
        id: 'e3',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 1,
        ballInOver: 3,
        eventType: BallEventType.lineupChange,
        runs: 0,
        batsmanRuns: 0,
        strikerId: 'non_striker',
        nonStrikerId: 'batter3',
        bowlerId: 'bowler',
        sequence: 3,
      ),
    ];

    final stale = MatchModel(
      id: 'm1',
      title: 'Test',
      teamAId: 'a',
      teamBId: 'b',
      rules: const MatchRulesModel(),
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.inProgress,
          strikerId: 'batter3',
          nonStrikerId: 'non_striker',
          currentBowlerId: 'bowler',
          batsmen: baseMatch().innings.first.batsmen,
          bowlers: baseMatch().innings.first.bowlers,
        ),
      ],
    );

    final repaired = BallEventAggregator.reprojectMatchFromEvents(stale, events);
    final inn = repaired.currentInnings!;

    expect(inn.strikerId, 'non_striker');
    expect(inn.nonStrikerId, 'batter3');
    expect(
      ScoringIntegrityCheck.verify(match: repaired, allEvents: events),
      isEmpty,
    );
  });

  test('reproject preserves run-out end-over crease when flagged', () {
    final prior = List.generate(
      5,
      (i) => event(sequence: i + 1, type: BallEventType.runs, runs: 0),
    );
    final events = [
      ...prior,
      event(
        sequence: 6,
        type: BallEventType.wicket,
        wicketType: WicketType.runOut,
        dismissedPlayerId: 'striker',
      ),
      BallEventModel(
        id: 'e7',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 1,
        ballInOver: 7,
        eventType: BallEventType.lineupChange,
        runs: 0,
        batsmanRuns: 0,
        strikerId: 'batter3',
        nonStrikerId: 'non_striker',
        bowlerId: 'bowler',
        sequence: 7,
      ),
      event(
        sequence: 8,
        type: BallEventType.endOver,
        preserveCreaseOnEndOver: true,
      ),
    ];

    final repaired = BallEventAggregator.reprojectMatchFromEvents(
      baseMatch(),
      events,
    );
    final inn = repaired.currentInnings!;

    expect(inn.strikerId, 'batter3');
    expect(inn.nonStrikerId, 'non_striker');
    expect(inn.legalBalls, 6);
  });
}
