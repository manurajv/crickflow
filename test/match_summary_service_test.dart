import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/domain/services/match_analytics_models.dart';
import 'package:crickflow/domain/services/match_mvp_models.dart';
import 'package:crickflow/domain/services/match_summary_models.dart';
import 'package:crickflow/domain/services/match_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = MatchSummaryService();

  MatchModel completedMatch({
    required String winnerId,
    String resultSummary = 'Team A won by 26 runs',
  }) {
    return MatchModel(
      id: 'm1',
      title: 'Test Match',
      status: MatchStatus.completed,
      teamAId: 'a',
      teamBId: 'b',
      teamAName: 'Silverbacks',
      teamBName: 'Lightning Legends',
      winnerTeamId: winnerId,
      resultSummary: resultSummary,
      venue: 'Central Ground',
      scheduledAt: DateTime(2026, 6, 20, 14, 0),
      rules: const MatchRulesModel(
        totalOvers: 20,
        ballsPerOver: 6,
      ),
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
          status: InningsStatus.completed,
          totalRuns: 183,
          totalWickets: 8,
          legalBalls: 120,
          batsmen: [
            const BatsmanInningsModel(
              playerId: 'a1',
              playerName: 'Varun',
              runs: 53,
              balls: 23,
              fours: 4,
              sixes: 5,
            ),
          ],
          bowlers: [
            const BowlerInningsModel(
              playerId: 'b2',
              playerName: 'Bittu',
              wickets: 3,
              runsConceded: 26,
              oversBowledBalls: 18,
            ),
          ],
        ),
        InningsModel(
          inningsNumber: 2,
          battingTeamId: 'b',
          bowlingTeamId: 'a',
          status: InningsStatus.completed,
          totalRuns: 157,
          totalWickets: 10,
          legalBalls: 108,
        ),
      ],
    );
  }

  MvpPlayerScore mvpPlayer({
    required String id,
    required String teamId,
    required String teamName,
    required double total,
    required int rank,
    bool potm = false,
    bool fighter = false,
    double batting = 0,
    double bowling = 0,
    double fielding = 0,
  }) {
    return MvpPlayerScore(
      playerId: id,
      playerName: id == 'a1' ? 'Varun' : id,
      teamId: teamId,
      teamName: teamName,
      rank: rank,
      battingMvp: batting,
      bowlingMvp: bowling,
      fieldingMvp: fielding,
      clutchBonus: 0,
      partnershipBonus: 0,
      totalMvp: total,
      isPlayerOfTheMatch: potm,
      isFighterOfTheMatch: fighter,
    );
  }

  group('MatchSummaryService', () {
    test('builds result card and heroes for completed match', () {
      final match = completedMatch(winnerId: 'a');
      final mvp = MatchMvpSnapshot(
        hasData: true,
        teamAId: 'a',
        teamBId: 'b',
        losingTeamId: 'b',
        players: [
          mvpPlayer(
            id: 'a1',
            teamId: 'a',
            teamName: 'Silverbacks',
            total: 6.22,
            rank: 1,
            potm: true,
            batting: 5.46,
          ),
          mvpPlayer(
            id: 'b1',
            teamId: 'b',
            teamName: 'Lightning Legends',
            total: 4.76,
            rank: 3,
            fighter: true,
            batting: 4.1,
          ),
          mvpPlayer(
            id: 'b2',
            teamId: 'b',
            teamName: 'Lightning Legends',
            total: 4.5,
            rank: 4,
            bowling: 4.76,
          ),
        ],
      );
      const analytics = MatchAnalyticsSnapshot(
        hasData: true,
        partnerships: [
          PartnershipAnalytics(
            inningsNumber: 1,
            wicketNumber: 2,
            runs: 103,
            balls: 58,
            batterAId: 'a1',
            batterBId: 'a2',
            batterAName: 'Varun',
            batterBName: 'Raje',
            batterARuns: 53,
            batterABalls: 23,
            batterBRuns: 50,
            batterBBalls: 35,
            isHighest: true,
          ),
        ],
        boundaries: BoundaryAnalytics(fours: 12, sixes: 6),
      );

      final snapshot = service.build(
        match: match,
        analytics: analytics,
        mvp: mvp,
      );

      expect(snapshot.hasData, isTrue);
      expect(snapshot.isCompleted, isTrue);
      expect(snapshot.result?.teamAName, 'Silverbacks');
      expect(snapshot.result?.resultLine, contains('won'));
      expect(snapshot.result?.playerOfMatchName, 'Varun');
      expect(snapshot.insight, isNotNull);
      expect(snapshot.insight!.headline, 'Performance Insights');

      final heroKinds = snapshot.heroes.map((h) => h.kind).toList();
      expect(heroKinds, contains(SummaryHeroKind.playerOfMatch));
      expect(heroKinds, contains(SummaryHeroKind.fighterOfMatch));
      expect(snapshot.bestPartnership?.runs, 103);
      expect(snapshot.awards, isNotEmpty);
      expect(snapshot.timeline, isNotEmpty);
    });

    test('uses hero-style result line when summary is not a match result', () {
      final match = completedMatch(
        winnerId: 'a',
        resultSummary: 'Varun — Top scorer with 53 runs',
      );
      final mvp = MatchMvpSnapshot(
        hasData: true,
        teamAId: 'a',
        teamBId: 'b',
        players: [
          mvpPlayer(
            id: 'a1',
            teamId: 'a',
            teamName: 'Silverbacks',
            total: 6.22,
            rank: 1,
            potm: true,
          ),
          mvpPlayer(
            id: 'a2',
            teamId: 'a',
            teamName: 'Silverbacks',
            total: 3.0,
            rank: 2,
          ),
        ],
      );

      final snapshot = service.build(
        match: match,
        analytics: const MatchAnalyticsSnapshot(hasData: true),
        mvp: mvp,
      );

      expect(snapshot.result?.resultLine, contains('won'));
      expect(snapshot.result?.resultLine, isNot(contains('Top scorer')));
    });

    test('personalizes insight with team effort percentage', () {
      final match = completedMatch(winnerId: 'a');
      final mvp = MatchMvpSnapshot(
        hasData: true,
        teamAId: 'a',
        teamBId: 'b',
        players: [
          mvpPlayer(
            id: 'a1',
            teamId: 'a',
            teamName: 'Silverbacks',
            total: 6.22,
            rank: 1,
            potm: true,
            batting: 5.46,
          ),
          mvpPlayer(
            id: 'a2',
            teamId: 'a',
            teamName: 'Silverbacks',
            total: 3.78,
            rank: 2,
          ),
        ],
      );

      final snapshot = service.build(
        match: match,
        analytics: const MatchAnalyticsSnapshot(hasData: true),
        mvp: mvp,
        viewerPlayerId: 'a1',
        viewerName: 'Varun',
      );

      expect(snapshot.insight?.isPersonalized, isTrue);
      expect(snapshot.insight?.contributionPercent, closeTo(62.2, 0.1));
      expect(snapshot.insight?.plainText, contains('you contributed'));
      expect(snapshot.insight?.plainText, contains('%'));
    });
  });
}
