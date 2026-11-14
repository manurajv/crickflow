// Golden parity for the org leaderboard.
//
// The Flutter app is the source of truth: this test runs the app's own engines
// (org_standings + PointsTableEngineService + PlayerRankingsService) over
// test/fixtures/org_leaderboard_golden.json and compares with the `expected`
// half of the same file. The Cloud Function digest builder
// (functions/src/series/orgMatchDigest.test.js) and the web leaderboard
// (crickflow-web/tests/org-leaderboard.test.ts) must reproduce the same
// expected values from the same file.
//
// Regenerate expected after an intentional rule change:
//   UPDATE_GOLDEN=1 flutter test test/org_leaderboard_golden_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/ball_event_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/player_model.dart';
import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/domain/services/player_rankings/player_rankings_models.dart';
import 'package:crickflow/domain/services/player_rankings/player_rankings_service.dart';
import 'package:crickflow/domain/services/series/org_competition_lists.dart';
import 'package:crickflow/domain/services/series/org_standings.dart';
import 'package:flutter_test/flutter_test.dart';

const _path = 'test/fixtures/org_leaderboard_golden.json';
const _service = PlayerRankingsService();

Map<String, dynamic> _row(dynamic entry) => {
      'teamId': entry.teamId,
      'teamName': entry.teamName,
      'played': entry.played,
      'won': entry.won,
      'lost': entry.lost,
      'tied': entry.tied,
      'noResult': entry.noResult,
      'points': entry.points,
      'netRunRate': entry.netRunRate,
      'position': entry.position,
    };

CricketBallType _ballOf(MatchModel m) {
  final explicit = m.rules.ballType;
  if (explicit != null) {
    return explicit == CricketBallType.indoor
        ? CricketBallType.tennis
        : explicit;
  }
  if (m.rules.format == MatchFormat.tennis ||
      m.rules.format == MatchFormat.custom) {
    return CricketBallType.tennis;
  }
  return CricketBallType.leather;
}

void main() {
  final fixture =
      jsonDecode(File(_path).readAsStringSync()) as Map<String, dynamic>;

  final teams = [
    for (final t in fixture['teams'] as List)
      SeriesClubModel.fromMap(
        (t as Map<String, dynamic>)['id'] as String,
        t,
      ),
  ];
  final matches = [
    for (final m in fixture['matches'] as List)
      MatchModel.fromMap(
        (m as Map<String, dynamic>)['id'] as String,
        m,
      ),
  ];
  final events = <String, List<BallEventModel>>{
    for (final e in (fixture['ballEvents'] as Map<String, dynamic>).entries)
      e.key: [
        for (var i = 0; i < (e.value as List).length; i++)
          BallEventModel.fromMap(
            '${e.key}_$i',
            (e.value as List)[i] as Map<String, dynamic>,
          ),
      ],
  };
  final players = [
    for (final p in fixture['players'] as List)
      PlayerModel.fromMap(
        (p as Map<String, dynamic>)['id'] as String,
        {'name': p['name'], 'userId': p['userId']},
      ),
  ];
  final registered =
      players.where((p) => (p.userId ?? '').trim().isNotEmpty).toList();
  final rules = SeriesRankingRulesModel.fromMap(
    (fixture['series'] as Map<String, dynamic>)['rankingRules']
        as Map<String, dynamic>,
  );

  Map<String, dynamic> computeExpected() {
    final tournaments = (fixture['tournaments'] as List)
        .map((t) => (t as Map<String, dynamic>))
        .toList();
    Map<String, List<Map<String, dynamic>>> tables = {};
    for (final f in <String?>[null, kOrgStandaloneFilter, 'tn1']) {
      final seed = f == 'tn1'
          ? (tournaments.first['teamIds'] as List).cast<String>().toSet()
          : null;
      final rows = buildOrgPointsTable(
        teams: teams,
        matches: matches,
        rules: rules,
        tournamentFilter: f,
        seedTeamIds: seed,
      );
      tables[f ?? 'all'] = [for (final r in rows) _row(r)];
    }

    // Per-match digest: what the server must store for each finished org match.
    final digests = <String, dynamic>{};
    for (final m in matches.where(countsForOrgStandings)) {
      final replay = <String, PlayerRankingReplayStats>{};
      final stats = _service.aggregateFromMatches(
        matches: [m],
        filter: PlayerRankingsFilter(ballType: _ballOf(m)),
        ballEventsByMatchId: events,
        replayStatsOut: replay,
      );
      final out = <String, dynamic>{};
      final ids = {...stats.keys, ...replay.keys};
      for (final id in ids.toList()..sort()) {
        final s = stats[id];
        final r = replay[id];
        final row = {
          'catches': s?.catches ?? 0,
          'runOuts': s?.runOuts ?? 0,
          'stumpings': s?.stumpings ?? 0,
          'dotBalls': r?.dotBalls ?? 0,
          'maidens': r?.maidens ?? 0,
          'fastestFiftyBalls': r?.fastestFiftyBalls,
          'fastestHundredBalls': r?.fastestHundredBalls,
        };
        final empty = row['catches'] == 0 &&
            row['runOuts'] == 0 &&
            row['stumpings'] == 0 &&
            row['dotBalls'] == 0 &&
            row['maidens'] == 0 &&
            row['fastestFiftyBalls'] == null &&
            row['fastestHundredBalls'] == null;
        if (!empty) out[id] = row;
      }
      digests[m.id] = out;
    }

    // Rankings: every category, per ball type and competition filter.
    final rankings = <String, dynamic>{};
    for (final ball in [CricketBallType.leather, CricketBallType.tennis]) {
      for (final f in <String?>[null, kOrgStandaloneFilter, 'tn1']) {
        final scoped = orgRankingMatches(matches, tournamentFilter: f);
        for (final category in PlayerRankingsCategory.values) {
          final filter = PlayerRankingsFilter(
            ballType: ball,
            section: category.section,
            category: category,
          );
          final bowlingInnings = <String, int>{};
          final replay = <String, PlayerRankingReplayStats>{};
          final stats = _service.aggregateFromMatches(
            matches: scoped,
            filter: filter,
            bowlingInningsOut: bowlingInnings,
            ballEventsByMatchId: events,
            replayStatsOut: replay,
          );
          final ranked = _service.rank(
            players: registered,
            filter: filter,
            teamNamesById: const {},
            statsByPlayerId: stats,
            bowlingInningsByPlayerId: bowlingInnings,
            replayStatsByPlayerId: replay,
          );
          rankings['${ball.name}|${f ?? 'all'}|${category.name}'] = [
            for (final e in ranked)
              {
                'playerId': e.playerDocId,
                'rank': e.rank,
                'value': e.value,
                'valueLabel': e.valueLabel,
                'detail': [
                  for (final d in e.detailStats) [d.label, d.value],
                ],
              },
          ];
        }
      }
    }
    return {'table': tables, 'digests': digests, 'rankings': rankings};
  }

  test('app engines reproduce the golden expectations', () {
    final actual = computeExpected();
    if (Platform.environment['UPDATE_GOLDEN'] == '1') {
      fixture['expected'] = actual;
      File(_path).writeAsStringSync(
        '${const JsonEncoder.withIndent(' ').convert(fixture)}\n',
      );
      return;
    }
    final expected = jsonDecode(jsonEncode(fixture['expected']));
    expect(jsonDecode(jsonEncode(actual)), expected);
  });

  test('golden scenario covers what it claims to', () {
    final e = (jsonDecode(jsonEncode(computeExpected())) as Map<String, dynamic>);
    final table = (e['table'] as Map<String, dynamic>)['all'] as List;
    // Pending / quick / one-sided / live matches never count.
    expect(table.map((r) => r['teamId']), isNot(contains('t4')));
    final played = {for (final r in table) r['teamId']: r['played']};
    expect(played, {'t1': 3, 't2': 3, 't3': 2});
    // Walk-ins never rank, registered players do.
    final all = jsonEncode(e['rankings']);
    expect(all, isNot(contains('guest_g1')));
    expect(all, isNot(contains('"w1"')));
    expect(all, contains('"p9"'));
    // Replay-only categories have entries.
    final r = e['rankings'] as Map<String, dynamic>;
    for (final k in [
      'fastestFifty',
      'fastestHundred',
      'bestBowlingFigures',
      'maidens',
      'dotBalls',
      'mostCatches',
      'mostStumpings',
      'mostRunOuts',
    ]) {
      expect((r['leather|all|$k'] as List), isNotEmpty, reason: k);
    }
  });
}
