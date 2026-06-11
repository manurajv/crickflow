import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/dismissal_fielder.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_setup_draft_models.dart';
import 'package:crickflow/domain/services/dismissal_formatter.dart';
import 'package:crickflow/domain/services/scorecard_display_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DismissalFormatter.fromWicketEvent', () {
    test('builds caught with fielder and bowler names', () {
      final event = BallEventModel(
        id: '1',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 3,
        ballInOver: 4,
        eventType: BallEventType.wicket,
        wicketType: WicketType.caught,
        dismissedPlayerId: 'b1',
        fielderName: 'Kasun Perera',
        bowlerName: 'Fernando',
        dismissalText: 'caught',
      );
      expect(
        DismissalFormatter.fromWicketEvent(event),
        'c Kasun Perera b Fernando',
      );
    });

    test('legacy run out Fielder/Bowler shows fielder only not bowler', () {
      final event = BallEventModel(
        id: '2d',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 4,
        ballInOver: 3,
        eventType: BallEventType.wicket,
        wicketType: WicketType.runOut,
        dismissedPlayerId: 'b2',
        bowlerId: 'bowl1',
        bowlerName: 'Fernando',
        dismissalText: 'run out Kasun Perera/Fernando',
        sequence: 2,
      );
      expect(
        DismissalFormatter.fromWicketEvent(event),
        'run out Kasun Perera',
      );
    });

    test('stumped shows bowler only not keeper', () {
      final event = BallEventModel(
        id: '2e',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 2,
        ballInOver: 4,
        eventType: BallEventType.wicket,
        wicketType: WicketType.stumped,
        dismissedPlayerId: 'b1',
        fielderId: 'wk1',
        fielderName: 'Ravi',
        primaryFielderId: 'wk1',
        primaryFielderName: 'Ravi',
        bowlerId: 'bowl1',
        bowlerName: 'Ashok',
        dismissalText: 'st Ravi b Ashok',
      );
      expect(
        DismissalFormatter.fromWicketEvent(event),
        'st b Ashok',
      );
    });

    test('legacy run out single name shows fielder only', () {
      final event = BallEventModel(
        id: '2c',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 4,
        ballInOver: 3,
        eventType: BallEventType.wicket,
        wicketType: WicketType.runOut,
        dismissedPlayerId: 'b2',
        bowlerId: 'bowl1',
        bowlerName: 'Fernando',
        dismissalText: 'run out Kasun Perera',
        sequence: 2,
      );
      expect(
        DismissalFormatter.fromWicketEvent(event),
        'run out Kasun Perera',
      );
    });

    test('builds run out with primary fielder metadata', () {
      final event = BallEventModel(
        id: '2b',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 4,
        ballInOver: 3,
        eventType: BallEventType.wicket,
        wicketType: WicketType.runOut,
        dismissedPlayerId: 'b2',
        primaryFielderId: 'f1',
        primaryFielderName: 'Kasun Perera',
        fielders: const [
          DismissalFielder(playerId: 'f1', playerName: 'Kasun Perera'),
        ],
      );
      expect(
        DismissalFormatter.fromWicketEvent(event),
        'run out Kasun Perera',
      );
    });

    test('builds run out with multiple fielders', () {
      final event = BallEventModel(
        id: '2',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 5,
        ballInOver: 2,
        eventType: BallEventType.wicket,
        wicketType: WicketType.runOut,
        dismissedPlayerId: 'b2',
        fielders: const [
          DismissalFielder(playerId: 'f1', playerName: 'Kasun Perera'),
          DismissalFielder(playerId: 'f2', playerName: 'John Silva'),
        ],
      );
      expect(
        DismissalFormatter.fromWicketEvent(event),
        'run out Kasun Perera / John Silva',
      );
    });

    test('caught without fielder metadata does not show b Bowler only', () {
      final event = BallEventModel(
        id: '3a',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 1,
        ballInOver: 1,
        eventType: BallEventType.wicket,
        wicketType: WicketType.caught,
        dismissedPlayerId: 'b1',
        fielderId: 'f1',
        primaryFielderId: 'f1',
        primaryFielderName: 'Kasun Perera',
        bowlerName: 'Ashok',
        dismissalText: 'b Ashok',
      );
      expect(
        DismissalFormatter.fromWicketEvent(event),
        'c Kasun Perera b Ashok',
      );
    });

    test('mankad displays as run out bowler', () {
      final event = BallEventModel(
        id: '3b',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 1,
        ballInOver: 1,
        eventType: BallEventType.wicket,
        wicketType: WicketType.runOut,
        isMankad: true,
        dismissedPlayerId: 'b4',
        bowlerId: 'bowl1',
        bowlerName: 'Ashok Rawat',
      );
      expect(
        DismissalFormatter.fromWicketEvent(event),
        'run out Ashok Rawat',
      );
    });

    test('prefers stored professional dismissal text', () {
      final event = BallEventModel(
        id: '3',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 1,
        ballInOver: 1,
        eventType: BallEventType.wicket,
        wicketType: WicketType.caughtAndBowled,
        dismissedPlayerId: 'b3',
        bowlerName: 'Fernando',
        dismissalText: 'c & b Fernando',
      );
      expect(
        DismissalFormatter.fromWicketEvent(event),
        'c & b Fernando',
      );
    });
  });

  group('ScorecardDisplayService.batsmanDismissalText', () {
    test('uses wicket event metadata over generic innings dismissalInfo', () {
      const batsman = BatsmanInningsModel(
        playerId: 'b1',
        playerName: 'Darshan',
        isOut: true,
        dismissalInfo: 'caught',
      );
      final event = BallEventModel(
        id: '1',
        matchId: 'm1',
        inningsNumber: 1,
        overNumber: 2,
        ballInOver: 3,
        eventType: BallEventType.wicket,
        wicketType: WicketType.caught,
        dismissedPlayerId: 'b1',
        fielderName: 'Kasun Perera',
        bowlerName: 'Fernando',
      );

      expect(
        ScorecardDisplayService.batsmanDismissalText(
          batsman,
          onCrease: false,
          wicketEvent: event,
        ),
        'c Kasun Perera b Fernando',
      );
    });

    test('shows not out for batter on crease', () {
      const batsman = BatsmanInningsModel(
        playerId: 'b2',
        playerName: 'Virender',
        runs: 42,
        balls: 30,
      );
      expect(
        ScorecardDisplayService.batsmanDismissalText(
          batsman,
          onCrease: true,
        ),
        'not out',
      );
    });
  });

  group('ScorecardDisplayService.toBatNames', () {
    test('uses squad names instead of raw ids', () {
      final match = MatchModel(
        id: 'm1',
        title: 'Test',
        teamAId: 'a',
        teamBId: 'b',
        setup: const MatchSetupData(
          teamASquadIds: ['p1', 'p2', 'p3'],
          teamASquadNames: {'p1': 'Alpha', 'p2': 'Beta', 'p3': 'Gamma'},
        ),
        innings: [
          InningsModel(
            inningsNumber: 1,
            battingTeamId: 'a',
            bowlingTeamId: 'b',
            status: InningsStatus.inProgress,
            strikerId: 'p1',
            nonStrikerId: 'p2',
            batsmen: const [
              BatsmanInningsModel(playerId: 'p1', playerName: 'Alpha'),
              BatsmanInningsModel(playerId: 'p2', playerName: 'Beta'),
            ],
          ),
        ],
      );
      final inn = match.innings.first;
      expect(
        ScorecardDisplayService.toBatNames(match, inn),
        ['Gamma'],
      );
    });

    test('prefers extra squad names when setup map is empty', () {
      final match = MatchModel(
        id: 'm1',
        title: 'Test',
        teamAId: 'a',
        teamBId: 'b',
        setup: const MatchSetupData(
          teamASquadIds: ['p1', 'p2', 'p3'],
        ),
        innings: [
          InningsModel(
            inningsNumber: 1,
            battingTeamId: 'a',
            bowlingTeamId: 'b',
            status: InningsStatus.inProgress,
            strikerId: 'p1',
            nonStrikerId: 'p2',
            batsmen: const [
              BatsmanInningsModel(playerId: 'p1', playerName: 'Alpha'),
              BatsmanInningsModel(playerId: 'p2', playerName: 'Beta'),
            ],
          ),
        ],
      );
      expect(
        ScorecardDisplayService.toBatNames(
          match,
          match.innings.first,
          extraNames: const {'p3': 'Gamma'},
        ),
        ['Gamma'],
      );
    });
  });
}
