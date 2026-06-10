import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/dismissal_fielder.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/scoring/ball_event_aggregator.dart';
import 'package:crickflow/domain/services/dismissal_formatter.dart';
import 'package:crickflow/domain/services/dismissal_sub_type.dart';
import 'package:crickflow/domain/services/scorecard_display_service.dart';
import 'package:crickflow/domain/services/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates the old [_record] bug: only fielderId forwarded, names stripped.
BallEventInput _strippedInput(BallEventInput full) => BallEventInput(
      type: full.type,
      runs: full.runs,
      wicketType: full.wicketType,
      dismissedPlayerId: full.dismissedPlayerId,
      fielderId: full.fielderId,
    );

MatchModel _baseMatch() {
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

void main() {
  final engine = ScoringEngine();

  group('Dismissal pipeline — CAUGHT end-to-end', () {
    const uiFielderId = 'fielder1';
    const uiFielderName = 'Kasun Perera';
    const uiBowlerName = 'Fernando';

    final fullInput = BallEventInput(
      type: BallEventType.wicket,
      wicketType: WicketType.caught,
      dismissedPlayerId: 'striker',
      dismissedPlayerName: 'John Silva',
      fielderId: uiFielderId,
      fielderName: uiFielderName,
      bowlerId: 'bowler',
      bowlerName: uiBowlerName,
      fielders: const [
        DismissalFielder(playerId: uiFielderId, playerName: uiFielderName),
      ],
    );

    test('full input preserves fielder through engine → Firestore map → read', () {
      final result = engine.recordBall(
        match: _baseMatch(),
        input: fullInput,
        sequence: 1,
      );

      // BallEvent from engine
      expect(result.event.primaryFielderId, uiFielderId);
      expect(result.event.primaryFielderName, uiFielderName);
      expect(result.event.fielderId, uiFielderId);
      expect(result.event.fielderName, uiFielderName);
      expect(result.event.fielders.single.playerName, uiFielderName);
      expect(result.event.fielderIds, [uiFielderId]);
      expect(result.event.fielderNames, [uiFielderName]);
      expect(result.event.dismissalText, 'c $uiFielderName b $uiBowlerName');

      // Firestore round-trip
      final stored = result.event.copyWith(id: 'evt1').toMap();
      final read = BallEventModel.fromMap('evt1', stored);
      expect(read.primaryFielderId, uiFielderId);
      expect(read.primaryFielderName, uiFielderName);
      expect(read.fielders.single.playerName, uiFielderName);

      // Replay
      final replayed = engine.replayInnings(
        match: result.match,
        baseInnings: _baseMatch().innings.first,
        events: [read],
      );
      final out = replayed.currentInnings!.batsmen
          .firstWhere((b) => b.playerId == 'striker');
      expect(out.dismissalInfo, 'c $uiFielderName b $uiBowlerName');

      // Aggregator FOW
      final derived = BallEventAggregator().projectInnings(
        match: result.match,
        lineupInnings: _baseMatch().innings.first,
        allEvents: [read],
      );
      expect(derived.fallOfWickets.single.dismissal,
          'c $uiFielderName b $uiBowlerName');

      // Scorecard display
      final display = ScorecardDisplayService.batsmanDismissalText(
        out,
        onCrease: false,
        wicketEvent: read,
      );
      expect(display, 'c $uiFielderName b $uiBowlerName');
    });

    test('stripped input (old _record bug) loses fielder name → b Bowler only', () {
      final stripped = _strippedInput(fullInput);
      final result = engine.recordBall(
        match: _baseMatch(),
        input: stripped,
        sequence: 1,
      );

      expect(result.event.primaryFielderId, uiFielderId);
      expect(result.event.primaryFielderName, isNull);
      expect(result.event.fielders, isEmpty);
      expect(result.event.dismissalText, 'b $uiBowlerName');

      final display = DismissalFormatter.fromWicketEvent(result.event);
      expect(display, 'b $uiBowlerName');
    });
  });

  group('Dismissal pipeline — all wicket types', () {
    final cases = <({
      String label,
      BallEventInput input,
      String expected,
    })>[
      (
        label: 'bowled',
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.bowled,
          dismissedPlayerId: 'striker',
          bowlerName: 'Fernando',
        ),
        expected: 'b Fernando',
      ),
      (
        label: 'lbw',
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.lbw,
          dismissedPlayerId: 'striker',
          bowlerName: 'Fernando',
        ),
        expected: 'lbw b Fernando',
      ),
      (
        label: 'caught',
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.caught,
          dismissedPlayerId: 'striker',
          fielderId: 'f1',
          fielderName: 'Kasun Perera',
          bowlerName: 'Fernando',
          fielders: [
            DismissalFielder(playerId: 'f1', playerName: 'Kasun Perera'),
          ],
        ),
        expected: 'c Kasun Perera b Fernando',
      ),
      (
        label: 'caught behind',
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.caught,
          dismissalSubType: DismissalSubType.caughtBehind,
          dismissedPlayerId: 'striker',
          fielderId: 'wk1',
          fielderName: 'Ravi Kumar',
          wicketKeeperId: 'wk1',
          wicketKeeperName: 'Ravi Kumar',
          bowlerName: 'Fernando',
          fielders: [
            DismissalFielder(playerId: 'wk1', playerName: 'Ravi Kumar'),
          ],
        ),
        expected: 'c †Ravi Kumar b Fernando',
      ),
      (
        label: 'caught and bowled',
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.caughtAndBowled,
          dismissedPlayerId: 'striker',
          fielderId: 'bowler',
          fielderName: 'Fernando',
          bowlerName: 'Fernando',
          fielders: [
            DismissalFielder(playerId: 'bowler', playerName: 'Fernando'),
          ],
        ),
        expected: 'c & b Fernando',
      ),
      (
        label: 'run out',
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.runOut,
          dismissedPlayerId: 'non_striker',
          fielderId: 'f1',
          fielderName: 'Kasun Perera',
          fielders: [
            DismissalFielder(playerId: 'f1', playerName: 'Kasun Perera'),
          ],
        ),
        expected: 'run out Kasun Perera',
      ),
      (
        label: 'mankad',
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.mankad,
          isMankad: true,
          dismissedPlayerId: 'non_striker',
          fielderId: 'bowler',
          fielderName: 'Ashok Rawat',
          bowlerName: 'Ashok Rawat',
          fielders: [
            DismissalFielder(playerId: 'bowler', playerName: 'Ashok Rawat'),
          ],
        ),
        expected: 'run out Ashok Rawat',
      ),
      (
        label: 'stumped',
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.stumped,
          dismissedPlayerId: 'striker',
          fielderId: 'wk1',
          fielderName: 'Ravi Kumar',
          wicketKeeperId: 'wk1',
          wicketKeeperName: 'Ravi Kumar',
          bowlerName: 'Fernando',
          fielders: [
            DismissalFielder(playerId: 'wk1', playerName: 'Ravi Kumar'),
          ],
        ),
        expected: 'st b Fernando',
      ),
      (
        label: 'hit wicket',
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.hitWicket,
          dismissedPlayerId: 'striker',
          bowlerName: 'Fernando',
        ),
        expected: 'hit wicket b Fernando',
      ),
      (
        label: 'retired hurt',
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.retiredHurt,
          dismissedPlayerId: 'striker',
        ),
        expected: 'retired hurt',
      ),
      (
        label: 'retired out',
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.retiredOut,
          dismissedPlayerId: 'striker',
        ),
        expected: 'retired out',
      ),
    ];

    for (final c in cases) {
      test('${c.label}: engine, Firestore, replay, aggregator, scorecard match',
          () {
        final result = engine.recordBall(
          match: _baseMatch(),
          input: c.input,
          sequence: 1,
        );

        expect(result.event.dismissalText, c.expected,
            reason: 'engine dismissalText');

        final stored = result.event.copyWith(id: 'e1').toMap();
        final read = BallEventModel.fromMap('e1', stored);
        expect(DismissalFormatter.fromWicketEvent(read), c.expected,
            reason: 'after Firestore read');

        final replayed = engine.replayInnings(
          match: result.match,
          baseInnings: _baseMatch().innings.first,
          events: [read],
        );
        final dismissedId = c.input.dismissedPlayerId!;
        final out = replayed.currentInnings!.batsmen
            .firstWhere((b) => b.playerId == dismissedId);
        if (c.input.wicketType != WicketType.retiredHurt) {
          expect(out.dismissalInfo, c.expected, reason: 'after replay');
        }

        final derived = BallEventAggregator().projectInnings(
          match: result.match,
          lineupInnings: _baseMatch().innings.first,
          allEvents: [read],
        );
        if (c.input.wicketType != WicketType.retiredHurt &&
            c.label != 'retired out') {
          expect(derived.fallOfWickets.single.dismissal, c.expected,
              reason: 'aggregator FOW');
        }

        if (c.input.wicketType != WicketType.retiredHurt) {
          expect(
            ScorecardDisplayService.batsmanDismissalText(
              out,
              onCrease: false,
              wicketEvent: read,
            ),
            c.expected,
            reason: 'scorecard display',
          );
        }
      });
    }
  });

  group('Legacy data recovery — fielder id only', () {
    test('caught with id-only recovers name from playerNames map', () {
      final event = BallEventModel(
        id: 'e1',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 1,
        eventType: BallEventType.wicket,
        isWicket: true,
        wicketType: WicketType.caught,
        dismissedPlayerId: 'striker',
        fielderId: 'f1',
        primaryFielderId: 'f1',
        bowlerId: 'bowler',
        bowlerName: 'Fernando',
        dismissalText: 'b Fernando',
        sequence: 1,
      );

      final text = DismissalFormatter.fromWicketEvent(
        event,
        playerNames: const {'f1': 'Kasun Perera', 'bowler': 'Fernando'},
      );
      expect(text, 'c Kasun Perera b Fernando');
    });

    test('caught behind with keeper id only recovers from wicketKeeperId', () {
      final event = BallEventModel(
        id: 'e1',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 0,
        ballInOver: 1,
        eventType: BallEventType.wicket,
        isWicket: true,
        wicketType: WicketType.caughtBehind,
        dismissedPlayerId: 'striker',
        wicketKeeperId: 'wk1',
        bowlerId: 'bowler',
        bowlerName: 'Fernando',
        dismissalText: 'b Fernando',
        sequence: 1,
      );

      final text = DismissalFormatter.fromWicketEvent(
        event,
        playerNames: const {'wk1': 'Ravi Kumar'},
      );
      expect(text, 'c †Ravi Kumar b Fernando');
    });
  });

  group('Caught auto-detection via resolveCaughtWicketType', () {
    test('keeper selection stores caught with caught_behind sub-type', () {
      final result = engine.recordBall(
        match: _baseMatch(),
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.caught,
          dismissalSubType: DismissalSubType.caughtBehind,
          dismissedPlayerId: 'striker',
          fielderId: 'wk1',
          fielderName: 'Niroshan',
          wicketKeeperId: 'wk1',
          wicketKeeperName: 'Niroshan',
          bowlerId: 'bowler',
          bowlerName: 'Ashok',
          fielders: [
            DismissalFielder(playerId: 'wk1', playerName: 'Niroshan'),
          ],
        ),
        sequence: 1,
      );

      expect(result.event.wicketType, WicketType.caught);
      expect(result.event.dismissalSubType, DismissalSubType.caughtBehind);
      expect(result.event.dismissalType, 'caught');
      expect(result.event.dismissalText, 'c †Niroshan b Ashok');

      final read = BallEventModel.fromMap(
        'e1',
        result.event.copyWith(id: 'e1').toMap(),
      );
      final replayed = engine.replayInnings(
        match: result.match,
        baseInnings: _baseMatch().innings.first,
        events: [read],
      );
      final out = replayed.currentInnings!.batsmen
          .firstWhere((b) => b.playerId == 'striker');
      expect(out.dismissalInfo, 'c †Niroshan b Ashok');
    });

    test('bowler selection stores caughtAndBowled not caught', () {
      final result = engine.recordBall(
        match: _baseMatch(),
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.caughtAndBowled,
          dismissedPlayerId: 'striker',
          fielderId: 'bowler',
          fielderName: 'Ashok',
          bowlerId: 'bowler',
          bowlerName: 'Ashok',
          fielders: [
            DismissalFielder(playerId: 'bowler', playerName: 'Ashok'),
          ],
        ),
        sequence: 1,
      );

      expect(result.event.wicketType, WicketType.caughtAndBowled);
      expect(result.event.dismissalText, 'c & b Ashok');
      expect(
        DismissalFormatter.fromWicketEvent(result.event),
        'c & b Ashok',
      );
    });
  });

  group('Firestore persistence fields', () {
    test('caught event toMap contains primaryFielderId and primaryFielderName',
        () {
      final result = engine.recordBall(
        match: _baseMatch(),
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.caught,
          dismissedPlayerId: 'striker',
          fielderId: 'f1',
          fielderName: 'Kasun Perera',
          bowlerName: 'Fernando',
          fielders: [
            DismissalFielder(playerId: 'f1', playerName: 'Kasun Perera'),
          ],
        ),
        sequence: 1,
      );

      final map = result.event.toMap();
      expect(map['primaryFielderId'], 'f1');
      expect(map['primaryFielderName'], 'Kasun Perera');
      expect(map['fielderId'], 'f1');
      expect(map['fielderName'], 'Kasun Perera');
      expect(map['dismissalType'], 'caught');
    });

    test('caught behind toMap contains wicketKeeperId and dismissalSubType',
        () {
      final result = engine.recordBall(
        match: _baseMatch(),
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.caught,
          dismissalSubType: DismissalSubType.caughtBehind,
          dismissedPlayerId: 'striker',
          fielderId: 'wk1',
          fielderName: 'Ravi Kumar',
          wicketKeeperId: 'wk1',
          wicketKeeperName: 'Ravi Kumar',
          bowlerName: 'Fernando',
          fielders: [
            DismissalFielder(playerId: 'wk1', playerName: 'Ravi Kumar'),
          ],
        ),
        sequence: 1,
      );

      final map = result.event.toMap();
      expect(map['wicketKeeperId'], 'wk1');
      expect(map['wicketKeeperName'], 'Ravi Kumar');
      expect(map['dismissalSubType'], DismissalSubType.caughtBehind);
      expect(map['wicketType'], 'caught');
      expect(map['dismissalType'], 'caught');
    });

    test('run out toMap contains fielderIds and fielderNames', () {
      final result = engine.recordBall(
        match: _baseMatch(),
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.runOut,
          dismissedPlayerId: 'non_striker',
          fielderId: 'f1',
          fielderName: 'Kasun Perera',
          fielders: [
            DismissalFielder(playerId: 'f1', playerName: 'Kasun Perera'),
          ],
        ),
        sequence: 1,
      );

      final map = result.event.toMap();
      expect(map['fielderIds'], ['f1']);
      expect(map['fielderNames'], ['Kasun Perera']);
      expect(map['isMankad'], isNull);
    });

    test('mankad toMap persists isMankad flag', () {
      final result = engine.recordBall(
        match: _baseMatch(),
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.mankad,
          isMankad: true,
          dismissedPlayerId: 'non_striker',
          fielderId: 'bowler',
          fielderName: 'Ashok Rawat',
          bowlerName: 'Ashok Rawat',
          fielders: [
            DismissalFielder(playerId: 'bowler', playerName: 'Ashok Rawat'),
          ],
        ),
        sequence: 1,
      );

      final map = result.event.toMap();
      expect(map['isMankad'], true);
      expect(map['dismissalType'], 'run_out');
      expect(map['wicketType'], 'runOut');
    });
  });

  group('Undo group — single undo for wicket workflow', () {
    test('wicket + lineup change with shared undoGroupId replay to pre-wicket state', () {
      const groupId = 'undo-group-1';
      final wicketResult = engine.recordBall(
        match: _baseMatch(),
        input: const BallEventInput(
          type: BallEventType.wicket,
          wicketType: WicketType.caught,
          dismissedPlayerId: 'striker',
          fielderId: 'f1',
          fielderName: 'Kasun Perera',
          bowlerName: 'Fernando',
          fielders: [
            DismissalFielder(playerId: 'f1', playerName: 'Kasun Perera'),
          ],
          undoGroupId: groupId,
        ),
        sequence: 1,
      );

      expect(wicketResult.event.undoGroupId, groupId);
      expect(wicketResult.match.currentInnings!.totalWickets, 1);
      expect(wicketResult.match.currentInnings!.strikerId, isNull);

      final lineupResult = engine.recordBall(
        match: wicketResult.match,
        input: const BallEventInput(
          type: BallEventType.lineupChange,
          creaseStrikerId: 'b2',
          creaseNonStrikerId: 'non_striker',
          undoGroupId: groupId,
        ),
        sequence: 2,
      );

      expect(lineupResult.event.undoGroupId, groupId);
      expect(lineupResult.match.currentInnings!.strikerId, 'b2');

      final replayed = engine.replayInnings(
        match: lineupResult.match,
        baseInnings: _baseMatch().innings.first,
        events: const [],
      );
      expect(replayed.currentInnings!.totalWickets, 0);
      expect(replayed.currentInnings!.strikerId, 'striker');
      expect(replayed.currentInnings!.nonStrikerId, 'non_striker');
    });
  });

  group('Wicketkeeper change replay', () {
    test('keeper change updates innings and survives Firestore round-trip', () {
      final match = _baseMatch();
      final changeResult = engine.recordBall(
        match: match,
        input: const BallEventInput(
          type: BallEventType.wicketKeeperChange,
          wicketKeeperId: 'wk2',
          wicketKeeperName: 'Kasun Perera',
          currentWicketKeeperId: 'wk2',
          currentWicketKeeperName: 'Kasun Perera',
        ),
        sequence: 1,
      );

      expect(
        changeResult.match.currentInnings!.currentWicketKeeperId,
        'wk2',
      );
      expect(
        changeResult.match.currentInnings!.currentWicketKeeperName,
        'Kasun Perera',
      );

      final read = BallEventModel.fromMap(
        'e1',
        changeResult.event.copyWith(id: 'e1').toMap(),
      );
      expect(read.wicketKeeperId, 'wk2');
      expect(read.eventType, BallEventType.wicketKeeperChange);

      final replayed = engine.replayInnings(
        match: changeResult.match,
        baseInnings: _baseMatch().innings.first,
        events: [read],
      );
      expect(replayed.currentInnings!.currentWicketKeeperId, 'wk2');
    });
  });
}
