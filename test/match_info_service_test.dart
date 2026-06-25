import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/utils/match_public_id_utils.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';
import 'package:crickflow/data/models/match_setup_draft_models.dart';
import 'package:crickflow/domain/services/match_info_service.dart';

void main() {
  final service = MatchInfoService();

  MatchModel sampleMatch({String? publicMatchId}) {
    return MatchModel(
      id: 'firebase-doc-id-xyz',
      title: 'Team A vs Team B',
      teamAName: 'Silverbacks',
      teamBName: 'Lightning Legends',
      teamAId: 'team-a',
      teamBId: 'team-b',
      tournamentId: 't-1',
      matchType: MatchType.tournament,
      status: MatchStatus.completed,
      venue: 'WFO Cricket Hub',
      publicMatchId: publicMatchId,
      resultSummary: 'Silverbacks won by 26 runs',
      rules: const MatchRulesModel(
        cricketMatchType: CricketMatchType.limitedOvers,
        totalOvers: 20,
        ballsPerOver: 6,
        playersPerTeam: 11,
        ballType: CricketBallType.leather,
      ),
      setup: MatchSetupData(
        scorers: const [
          MatchOfficialEntry(name: 'Manuraj Vimukthi', playerId: 'u1', slotLabel: 'Scorer'),
        ],
      ),
      scheduledAt: DateTime(2026, 6, 14, 17, 43),
    );
  }

  test('generatePublicMatchId returns 8 digits', () {
    final id = generatePublicMatchId(Random(1));
    expect(id.length, 8);
    expect(int.tryParse(id), isNotNull);
  });

  test('overview shows public match id not firebase id', () {
    final info = service.build(
      match: sampleMatch(publicMatchId: '26061442'),
      tournamentName: 'WFO Champions Trophy',
    );

    expect(info.overview.any((r) => r.label == 'Match ID' && r.value == '26061442'), isTrue);
    expect(info.overview.any((r) => r.value.contains('firebase')), isFalse);
  });

  test('overview hides match id before public id is assigned', () {
    final info = service.build(match: sampleMatch());
    expect(info.overview.any((r) => r.label == 'Match ID'), isFalse);
  });

  test('venue row opens directions in maps', () {
    final info = service.build(match: sampleMatch(publicMatchId: '26061442'));
    final venue = info.overview.firstWhere((r) => r.label == 'Venue');
    expect(venue.openDirectionsInMaps, isTrue);
  });

  test('overview shows match type and round for live tournament matches', () {
    final live = sampleMatch(publicMatchId: '26061442').copyWith(
      status: MatchStatus.live,
    );
    final info = service.build(
      match: live,
      tournamentName: 'WFO Champions Trophy',
    );

    expect(
      info.overview.any((r) => r.label == 'Match type'),
      isTrue,
    );
    expect(
      info.overview.any((r) => r.label == 'Tournament'),
      isFalse,
    );
  });

  test('overview shows match type and round for completed tournament matches', () {
    final info = service.build(
      match: sampleMatch(publicMatchId: '26061442'),
      tournamentName: 'WFO Champions Trophy',
    );

    expect(
      info.overview.any((r) => r.label == 'Match type'),
      isTrue,
    );
    expect(
      info.overview.any((r) => r.label == 'Tournament'),
      isFalse,
    );
  });

  test('overview shows match type and round for knockout fixtures', () {
    final knockout = MatchModel(
      id: 'm-ko',
      title: 'Team A vs Team B',
      teamAName: 'Silverbacks',
      teamBName: 'Lightning Legends',
      teamAId: 'team-a',
      teamBId: 'team-b',
      tournamentId: 't-1',
      matchType: MatchType.tournament,
      status: MatchStatus.scheduled,
      bracketRound: 0,
      rules: const MatchRulesModel(totalOvers: 20),
    );

    final info = service.build(
      match: knockout,
      tournamentName: 'WFO Champions Trophy',
    );

    expect(
      info.overview.any((r) => r.label == 'Match type' && r.value == 'Knockout'),
      isTrue,
    );
    expect(
      info.overview.any((r) => r.label == 'Round' && r.value == 'Round 1'),
      isTrue,
    );
  });

  test('overview and configuration avoid duplicate labels', () {
    final info = service.build(
      match: sampleMatch(publicMatchId: '26061442'),
      tournamentName: 'WFO Champions Trophy',
    );

    final overviewLabels = info.overview.map((r) => r.label).toSet();
    final configLabels = info.configuration.map((r) => r.label).toSet();
    final conditionLabels = info.conditions.map((r) => r.label).toSet();

    expect(overviewLabels.contains('Match type'), isTrue);
    expect(overviewLabels.contains('Match format'), isFalse);
    expect(overviewLabels.contains('Format'), isTrue);
    expect(configLabels.contains('Match type'), isFalse);
    expect(configLabels.contains('Match format'), isFalse);
    expect(configLabels.contains('Ball type'), isTrue);
    expect(overviewLabels.intersection(configLabels), isEmpty);
    expect(conditionLabels.contains('Ground'), isFalse);
    expect(conditionLabels.contains('Ball type'), isFalse);
  });
}
