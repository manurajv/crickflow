import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/dismissal_fielder.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/scoring/ball_event_aggregator.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = ScoringEngine();

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
            BatsmanInningsModel(playerId: 'striker', playerName: 'John Silva'),
            BatsmanInningsModel(
              playerId: 'non_striker',
              playerName: 'Jane Doe',
            ),
          ],
          bowlers: const [
            BowlerInningsModel(playerId: 'bowler', playerName: 'Fernando'),
          ],
        ),
      ],
    );
  }

  test('caught wicket stores striker as dismissed; fielding derived from event', () {
    final match = baseMatch();
    final result = engine.recordBall(
      match: match,
      input: const BallEventInput(
        type: BallEventType.wicket,
        wicketType: WicketType.caught,
        dismissedPlayerId: 'striker',
        fielderId: 'fielder1',
        fielderName: 'Kasun Perera',
        bowlerName: 'Fernando',
        fielders: [
          DismissalFielder(playerId: 'fielder1', playerName: 'Kasun Perera'),
        ],
      ),
      sequence: 1,
    );

    final inn = result.match.currentInnings!;
    expect(inn.totalWickets, 1);
    expect(inn.strikerId, isNull);
    expect(inn.nonStrikerId, 'non_striker');
    expect(result.event.strikerAfterBall, isNull);
    expect(result.event.nonStrikerAfterBall, 'non_striker');
    final outBatter = inn.batsmen.firstWhere((b) => b.playerId == 'striker');
    expect(outBatter.isOut, isTrue);
    expect(outBatter.dismissalInfo, 'c Kasun Perera b Fernando');
    expect(inn.fielders, isEmpty);

    final derived = BallEventAggregator().projectInnings(
      match: result.match,
      lineupInnings: match.innings.first,
      allEvents: [result.event],
    );
    expect(derived.fielders.single.catches, 1);
    expect(derived.fallOfWickets.single.dismissal, 'c Kasun Perera b Fernando');
  });

  test('run out non-striker dismisses correct batter', () {
    final result = engine.recordBall(
      match: baseMatch(),
      input: const BallEventInput(
        type: BallEventType.wicket,
        wicketType: WicketType.runOut,
        dismissedPlayerId: 'non_striker',
        fielderId: 'fielder1',
        fielderName: 'Kasun Perera',
        fielders: [
          DismissalFielder(playerId: 'fielder1', playerName: 'Kasun Perera'),
        ],
      ),
      sequence: 1,
    );

    final inn = result.match.currentInnings!;
    expect(inn.strikerId, 'striker');
    expect(inn.nonStrikerId, isNull);
    expect(inn.bowlers.single.wickets, 0);

    final derived = BallEventAggregator().projectInnings(
      match: result.match,
      lineupInnings: baseMatch().innings.first,
      allEvents: [result.event],
    );
    expect(derived.fielders.single.runOuts, 1);
    final outBatter =
        inn.batsmen.firstWhere((b) => b.playerId == 'non_striker');
    expect(outBatter.isOut, isTrue);
  });

  test('undo replay removes wicket and restores batters', () {
    final match = baseMatch();
    final caught = engine.recordBall(
      match: match,
      input: const BallEventInput(
        type: BallEventType.wicket,
        wicketType: WicketType.caught,
        dismissedPlayerId: 'striker',
        fielderId: 'fielder1',
        fielderName: 'Kasun Perera',
        bowlerName: 'Fernando',
        fielders: [
          DismissalFielder(playerId: 'fielder1', playerName: 'Kasun Perera'),
        ],
      ),
      sequence: 1,
    );

    final event = caught.event;
    final base = engine.baseInningsFrom(match.innings.first);
    final replayed = engine.replayInnings(
      match: caught.match,
      baseInnings: base,
      events: const [],
    );

    final inn = replayed.currentInnings!;
    expect(inn.totalWickets, 0);
    expect(inn.strikerId, 'striker');
    expect(inn.nonStrikerId, 'non_striker');
    expect(inn.fielders, isEmpty);
    expect(inn.fallOfWickets, isEmpty);
    final striker =
        inn.batsmen.firstWhere((b) => b.playerId == 'striker');
    expect(striker.isOut, isFalse);
    expect(striker.dismissalInfo, isEmpty);
    expect(event.dismissedPlayerId, 'striker');
  });

  test('retired hurt does not count as wicket and batter may return', () {
    final result = engine.recordBall(
      match: baseMatch(),
      input: const BallEventInput(
        type: BallEventType.wicket,
        wicketType: WicketType.retiredHurt,
        dismissedPlayerId: 'striker',
      ),
      sequence: 1,
    );

    final inn = result.match.currentInnings!;
    expect(inn.totalWickets, 0);
    expect(inn.bowlers.single.wickets, 0);
    expect(result.event.isWicket, isFalse);
    expect(result.event.retiredHurt, isTrue);
    expect(result.event.isEligibleToReturn, isTrue);

    final striker =
        inn.batsmen.firstWhere((b) => b.playerId == 'striker');
    expect(striker.isOut, isFalse);
    expect(striker.retiredHurt, isTrue);
    expect(striker.isEligibleToReturn, isTrue);
    expect(striker.dismissalInfo, 'retired hurt');
    expect(inn.strikerId, isNull);
  });

  test('mankad stores as run out with bowler display and no bowler wicket', () {
    final result = engine.recordBall(
      match: baseMatch(),
      input: const BallEventInput(
        type: BallEventType.wicket,
        wicketType: WicketType.mankad,
        isMankad: true,
        dismissedPlayerId: 'non_striker',
        fielderId: 'bowler',
        fielderName: 'Fernando',
        bowlerName: 'Fernando',
        fielders: [
          DismissalFielder(playerId: 'bowler', playerName: 'Fernando'),
        ],
      ),
      sequence: 1,
    );

    expect(result.event.wicketType, WicketType.runOut);
    expect(result.event.isMankad, isTrue);
    expect(result.event.dismissalType, 'run_out');
    expect(result.event.dismissalText, 'run out Fernando');
    expect(result.match.currentInnings!.bowlers.single.wickets, 0);

    final outBatter =
        result.match.currentInnings!.batsmen.firstWhere((b) => b.playerId == 'non_striker');
    expect(outBatter.dismissalInfo, 'run out Fernando');
  });

  test('createdBy is stored on event', () {
    final result = engine.recordBall(
      match: baseMatch(),
      input: const BallEventInput(
        type: BallEventType.runs,
        runs: 1,
        createdBy: 'scorer_uid_1',
      ),
      sequence: 1,
    );
    expect(result.event.createdBy, 'scorer_uid_1');
  });
}
