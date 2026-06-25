import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/utils/match_update_merge.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/match_rules_model.dart';

void main() {
  MatchModel tournamentMatch({
    String? tournamentId,
    MatchType matchType = MatchType.tournament,
    List<InningsModel> innings = const [],
  }) {
    return MatchModel(
      id: 'm1',
      title: 'A vs B',
      matchType: matchType,
      tournamentId: tournamentId ?? 't1',
      roundId: 'r1',
      groupId: 'g1',
      roundName: 'League',
      bracketRound: 1,
      bracketSlot: 0,
      rules: const MatchRulesModel(),
      innings: innings,
    );
  }

  test('merge preserves tournament metadata when incoming uses single matchType', () {
    final existing = tournamentMatch();
    final incoming = existing.copyWith(status: MatchStatus.live);
    final merged = MatchUpdateMerge.merge(
      existing,
      MatchModel(
        id: existing.id,
        title: existing.title,
        matchType: MatchType.single,
        status: MatchStatus.live,
        teamAName: existing.teamAName,
        teamBName: existing.teamBName,
        rules: existing.rules,
      ),
    );

    expect(merged.matchType, MatchType.tournament);
    expect(merged.tournamentId, 't1');
    expect(merged.roundId, 'r1');
    expect(merged.groupId, 'g1');
  });

  test('merge blocks toss reset from wiping scored innings', () {
    final scoredInnings = InningsModel(
      inningsNumber: 1,
      battingTeamId: 'a',
      bowlingTeamId: 'b',
      status: InningsStatus.inProgress,
      legalBalls: 6,
      totalRuns: 12,
    );
    final existing = tournamentMatch(innings: [scoredInnings]);
    final incoming = existing.copyWith(
      innings: [
        InningsModel(
          inningsNumber: 1,
          battingTeamId: 'a',
          bowlingTeamId: 'b',
        ),
      ],
    );

    final merged = MatchUpdateMerge.merge(existing, incoming);
    expect(merged.innings.length, 1);
    expect(merged.innings.first.legalBalls, 6);
    expect(merged.innings.first.totalRuns, 12);
  });

  test('mergeMap keeps tournamentId when omitted from ball-commit payload', () {
    final existing = tournamentMatch();
    final payload = {
      'title': existing.title,
      'matchType': MatchType.single.name,
      'status': MatchStatus.live.name,
      'teamAName': existing.teamAName,
      'teamBName': existing.teamBName,
      'rules': existing.rules.toMap(),
      'innings': existing.innings.map((i) => i.toMap()).toList(),
      'currentInningsIndex': 0,
      'location': existing.location.toMap(),
      'venue': '',
      'scorerIds': <String>[],
      'resultSummary': '',
      'badgeIds': <String>[],
      'stream': existing.stream.toMap(),
      'overlayVersion': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final merged = MatchUpdateMerge.mergeMap(existing, payload);
    expect(merged['matchType'], MatchType.tournament.name);
    expect(merged['tournamentId'], 't1');
    expect(merged['roundId'], 'r1');
  });
}
