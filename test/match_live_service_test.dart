import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/services/commentary_feed_models.dart';
import 'package:crickflow/domain/services/match_live_service.dart';
import 'package:crickflow/features/matches/presentation/match_hub_tabs.dart';

void main() {
  group('MatchHubTabConfig', () {
    MatchModel matchWithStatus(MatchStatus status) {
      return MatchModel(
        id: 'm1',
        title: 'Test',
        status: status,
        teamAName: 'Team A',
        teamBName: 'Team B',
        teamAId: 'a',
        teamBId: 'b',
        rules: const MatchRulesModel(totalOvers: 20, ballsPerOver: 6),
        innings: const [
          InningsModel(
            inningsNumber: 1,
            battingTeamId: 'a',
            bowlingTeamId: 'b',
            status: InningsStatus.inProgress,
            totalRuns: 120,
            totalWickets: 3,
            legalBalls: 72,
          ),
        ],
      );
    }

    test('live match shows Live tab and hides Summary', () {
      final match = matchWithStatus(MatchStatus.live);
      final config = MatchHubTabConfig.forMatch(match);

      expect(config.contains(MatchHubTabId.live), isTrue);
      expect(config.contains(MatchHubTabId.summary), isFalse);
      expect(config.tabIds.first, MatchHubTabId.info);
      expect(config.tabIds[1], MatchHubTabId.live);
    });

    test('completed match shows Summary and hides Live', () {
      final match = matchWithStatus(MatchStatus.completed);
      final config = MatchHubTabConfig.forMatch(match);

      expect(config.contains(MatchHubTabId.summary), isTrue);
      expect(config.contains(MatchHubTabId.live), isFalse);
    });

    test('abandoned match shows Summary and hides Live', () {
      final match = matchWithStatus(MatchStatus.abandoned);
      final config = MatchHubTabConfig.forMatch(match);

      expect(config.contains(MatchHubTabId.summary), isTrue);
      expect(config.contains(MatchHubTabId.live), isFalse);
    });

    test('pre-match hides both Live and Summary', () {
      final match = matchWithStatus(MatchStatus.scheduled);
      final config = MatchHubTabConfig.forMatch(match);

      expect(config.contains(MatchHubTabId.live), isFalse);
      expect(config.contains(MatchHubTabId.summary), isFalse);
    });

    test('upcoming match shows only Match Info and Squads', () {
      final match = matchWithStatus(MatchStatus.scheduled);
      final config = MatchHubTabConfig.forMatch(match);

      expect(config.tabIds, [MatchHubTabId.info, MatchHubTabId.squads]);
      expect(config.tabIds.length, 2);
      expect(
        MatchHubTabConfig.defaultTab(match),
        MatchHubTabId.info,
      );
      expect(
        config.resolveInitialIndex(match, 'summary'),
        config.indexOf(MatchHubTabId.info),
      );
    });

    test('resolves live deep link only when live', () {
      final live = matchWithStatus(MatchStatus.live);
      final completed = matchWithStatus(MatchStatus.completed);

      expect(
        MatchHubTabConfig.forMatch(live).resolveInitialIndex(live, 'live'),
        MatchHubTabConfig.forMatch(live).indexOf(MatchHubTabId.live),
      );
      expect(
        MatchHubTabConfig.forMatch(completed).resolveInitialIndex(
          completed,
          'live',
        ),
        MatchHubTabConfig.forMatch(completed).indexOf(MatchHubTabId.summary),
      );
    });
  });

  group('MatchLiveService', () {
    test('builds chase snapshot for live second innings', () {
      final match = MatchModel(
        id: 'm1',
        title: 'Chase',
        status: MatchStatus.live,
        teamAName: 'Silverbacks',
        teamBName: 'Legends',
        teamAId: 'a',
        teamBId: 'b',
        currentInningsIndex: 1,
        rules: const MatchRulesModel(totalOvers: 20, ballsPerOver: 6),
        innings: [
          const InningsModel(
            inningsNumber: 1,
            battingTeamId: 'a',
            bowlingTeamId: 'b',
            status: InningsStatus.completed,
            totalRuns: 183,
            totalWickets: 7,
            legalBalls: 120,
          ),
          InningsModel(
            inningsNumber: 2,
            battingTeamId: 'b',
            bowlingTeamId: 'a',
            status: InningsStatus.inProgress,
            totalRuns: 167,
            totalWickets: 9,
            legalBalls: 114,
            strikerId: 's1',
            nonStrikerId: 's2',
            currentBowlerId: 'b1',
            partnershipRuns: 56,
            partnershipBalls: 27,
            batsmen: const [
              BatsmanInningsModel(
                playerId: 's1',
                playerName: 'Ram Krishan Sharma',
                runs: 16,
                balls: 10,
                fours: 2,
              ),
              BatsmanInningsModel(
                playerId: 's2',
                playerName: 'Gunpreet Singh',
                runs: 40,
                balls: 17,
                fours: 4,
              ),
            ],
            bowlers: const [
              BowlerInningsModel(
                playerId: 'b1',
                playerName: 'Gurnek Singh',
                oversBowledBalls: 30,
                runsConceded: 55,
                wickets: 1,
              ),
            ],
          ),
        ],
      );

      final snapshot = MatchLiveService().build(
        match: match,
        feed: CommentaryFeed.empty,
      );

      expect(snapshot.hasData, isTrue);
      expect(snapshot.battingTeamName, 'Legends');
      expect(snapshot.scoreLine, '167/9');
      expect(snapshot.batters.length, 2);
      expect(snapshot.bowlers.length, 1);
      expect(snapshot.partnershipRuns, 56);
      expect(snapshot.target, isNotNull);
      expect(snapshot.runsNeeded, isNotNull);
      expect(snapshot.currentRunRate, greaterThan(0));
    });
  });
}
