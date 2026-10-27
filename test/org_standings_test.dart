import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/data/models/tournament_model.dart';
import 'package:crickflow/domain/services/series/org_competition_lists.dart';
import 'package:crickflow/domain/services/series/org_standings.dart';
import 'package:flutter_test/flutter_test.dart';

const _teams = [
  SeriesClubModel(
    id: 'ca', seriesId: 's', name: 'Aces', linkedTeamId: 'ta',
    status: SeriesClubStatus.approved,
  ),
  SeriesClubModel(
    id: 'cb', seriesId: 's', name: 'Blazers', linkedTeamId: 'tb',
    status: SeriesClubStatus.approved,
  ),
  SeriesClubModel(
    id: 'cc', seriesId: 's', name: 'Comets', linkedTeamId: 'tc',
    status: SeriesClubStatus.approved,
  ),
  SeriesClubModel(
    id: 'cd', seriesId: 's', name: 'Pending FC', linkedTeamId: 'td',
    status: SeriesClubStatus.pending,
  ),
];

MatchModel _match(
  String id, {
  String a = 'ta',
  String b = 'tb',
  String? winner,
  String summary = '',
  MatchStatus status = MatchStatus.completed,
  String official = 'approved',
  MatchMode mode = MatchMode.normal,
  String? tournamentId,
  int aRuns = 150,
  int bRuns = 120,
  int bBalls = 120,
  DateTime? at,
}) {
  final names = {'ta': 'Aces', 'tb': 'Blazers', 'tc': 'Comets'};
  return MatchModel(
    id: id,
    title: id,
    matchMode: mode,
    status: status,
    teamAId: a,
    teamBId: b,
    teamAName: names[a] ?? a,
    teamBName: names[b] ?? b,
    tournamentId: tournamentId,
    winnerTeamId: winner,
    resultSummary: summary,
    completedAt: at ?? DateTime(2026, 1, 1),
    seriesId: 's',
    seriesOfficialStatus: official,
    seriesClubAId: 'c${a.substring(1)}',
    seriesClubBId: 'c${b.substring(1)}',
    innings: [
      InningsModel(
        inningsNumber: 1, battingTeamId: a, bowlingTeamId: b,
        totalRuns: aRuns, totalWickets: 4, legalBalls: 120,
        status: InningsStatus.completed,
      ),
      InningsModel(
        inningsNumber: 2, battingTeamId: b, bowlingTeamId: a,
        totalRuns: bRuns, totalWickets: 6, legalBalls: bBalls,
        status: InningsStatus.completed,
      ),
    ],
  );
}

void main() {
  group('countsForOrgStandings', () {
    test('only approved, finished, non-quick matches between org teams', () {
      expect(countsForOrgStandings(_match('m', winner: 'ta')), isTrue);
      expect(
        countsForOrgStandings(_match('m', official: 'pendingApproval')),
        isFalse,
      );
      expect(
        countsForOrgStandings(_match('m', mode: MatchMode.quick)),
        isFalse,
      );
      expect(
        countsForOrgStandings(_match('m', status: MatchStatus.live)),
        isFalse,
      );
      expect(
        countsForOrgStandings(
          _match('m', status: MatchStatus.abandoned),
        ),
        isTrue,
      );
    });
  });

  group('buildOrgPointsTable', () {
    test('lists every approved linked team, even before they play', () {
      final rows = buildOrgPointsTable(teams: _teams, matches: const []);
      expect(rows.map((r) => r.teamName).toSet(), {'Aces', 'Blazers', 'Comets'});
      expect(rows.every((r) => r.played == 0), isTrue);
    });

    test('win / loss / tie / no result use the org points rules', () {
      final rows = buildOrgPointsTable(
        teams: _teams,
        matches: [
          _match('1', winner: 'ta'),
          _match('2', a: 'ta', b: 'tc', summary: 'Match tied'),
          _match('3', a: 'tb', b: 'tc', status: MatchStatus.abandoned),
        ],
        rules: const SeriesRankingRulesModel(
          winPoints: 3, tiePoints: 1, noResultPoints: 2, lossPoints: 0,
        ),
      );
      final byName = {for (final r in rows) r.teamName: r};
      expect(byName['Aces']!.played, 2);
      expect(byName['Aces']!.won, 1);
      expect(byName['Aces']!.tied, 1);
      expect(byName['Aces']!.points, 4);
      expect(byName['Blazers']!.lost, 1);
      expect(byName['Blazers']!.noResult, 1);
      expect(byName['Blazers']!.points, 2);
      expect(byName['Comets']!.tied, 1);
      expect(byName['Comets']!.noResult, 1);
      expect(byName['Comets']!.points, 3);
      expect(rows.first.teamName, 'Aces');
      expect(rows.map((r) => r.position), [1, 2, 3]);
    });

    test('net run rate breaks points ties; off falls back to wins', () {
      // Aces and Blazers both win one: Aces by a lot, Blazers narrowly.
      final matches = [
        _match('1', a: 'ta', b: 'tc', winner: 'ta', aRuns: 200, bRuns: 100),
        _match('2', a: 'tb', b: 'tc', winner: 'tb', aRuns: 130, bRuns: 129),
      ];
      final withNrr = buildOrgPointsTable(teams: _teams, matches: matches);
      expect(withNrr.first.teamName, 'Aces');
      expect(withNrr.first.netRunRate, greaterThan(withNrr[1].netRunRate));
      expect(withNrr.first.netRunRate, isNot(0));

      final noNrr = buildOrgPointsTable(
        teams: _teams,
        matches: matches,
        rules: const SeriesRankingRulesModel(useNetRunRate: false),
      );
      // Same points and wins → alphabetical.
      expect(noNrr.take(2).map((r) => r.teamName), ['Aces', 'Blazers']);
    });

    test('ignores pending, quick and unfinished matches and unapproved teams',
        () {
      final rows = buildOrgPointsTable(
        teams: _teams,
        matches: [
          _match('1', winner: 'ta', official: 'pendingApproval'),
          _match('2', winner: 'ta', mode: MatchMode.quick),
          _match('3', winner: 'ta', status: MatchStatus.live),
        ],
      );
      expect(rows.every((r) => r.played == 0), isTrue);
      expect(rows.any((r) => r.teamName == 'Pending FC'), isFalse);
    });

    test('tournament and standalone filters', () {
      final matches = [
        _match('1', winner: 'ta', tournamentId: 't1'),
        _match('2', a: 'tb', b: 'tc', winner: 'tb'),
      ];
      final t1 = buildOrgPointsTable(
        teams: _teams,
        matches: matches,
        tournamentFilter: 't1',
        seedTeamIds: {'ta', 'tb', 'tc'},
      );
      expect(t1.map((r) => r.played).fold<int>(0, (a, b) => a + b), 2);
      expect(t1.firstWhere((r) => r.teamName == 'Comets').played, 0);

      final solo = buildOrgPointsTable(
        teams: _teams,
        matches: matches,
        tournamentFilter: kOrgStandaloneFilter,
      );
      expect(solo.firstWhere((r) => r.teamName == 'Aces').played, 0);
      expect(solo.firstWhere((r) => r.teamName == 'Blazers').won, 1);
    });
  });

  test('orgRankingMatches filters like the points table', () {
    final list = orgRankingMatches([
      _match('1', winner: 'ta', tournamentId: 't1'),
      _match('2', winner: 'ta'),
      _match('3', winner: 'ta', official: 'pendingApproval'),
    ], tournamentFilter: 't1');
    expect(list.map((m) => m.id), ['1']);
  });

  test('orgApprovedTournaments keeps approved, sorted by name', () {
    final list = orgApprovedTournaments([
      const TournamentModel(
        id: 'b', name: 'Zed Cup', seriesId: 's',
        seriesOfficialStatus: 'approved',
      ),
      const TournamentModel(
        id: 'a', name: 'Alpha Cup', seriesId: 's',
        seriesOfficialStatus: 'approved',
      ),
      const TournamentModel(
        id: 'c', name: 'Pending Cup', seriesId: 's',
        seriesOfficialStatus: 'pendingApproval',
      ),
    ]);
    expect(list.map((t) => t.id), ['a', 'b']);
  });
}
