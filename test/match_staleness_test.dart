import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/domain/scoring/match_staleness.dart';
import 'package:crickflow/domain/services/series/org_competition_lists.dart';
import 'package:crickflow/shared/providers/tournament_match_providers.dart';
import 'package:crickflow/shared/providers/tournament_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.now();
DateTime _daysAgo(int d) => _now.subtract(Duration(days: d));

MatchModel _m(
  String id, {
  MatchStatus status = MatchStatus.scheduled,
  DateTime? scheduledAt,
  DateTime? startedAt,
  DateTime? createdAt,
  DateTime? completedAt,
  String? tournamentId,
}) =>
    MatchModel(
      id: id,
      title: id,
      status: status,
      teamAName: 'Aces',
      teamBName: 'Blazers',
      seriesId: 's1',
      seriesOfficialStatus: 'approved',
      tournamentId: tournamentId,
      scheduledAt: scheduledAt,
      startedAt: startedAt,
      createdAt: createdAt,
      completedAt: completedAt,
    );

void main() {
  group('isStaleUnfinishedMatch', () {
    test('scheduled more than 30 days ago is stale', () {
      expect(isStaleUnfinishedMatch(_m('a', scheduledAt: _daysAgo(31))), isTrue);
      expect(isStaleUnfinishedMatch(_m('b', scheduledAt: _daysAgo(29))), isFalse);
    });

    test('every unfinished status can go stale', () {
      for (final s in [
        MatchStatus.draft,
        MatchStatus.scheduled,
        MatchStatus.tossCompleted,
        MatchStatus.live,
        MatchStatus.inningsBreak,
      ]) {
        expect(
          isStaleUnfinishedMatch(_m('x', status: s, startedAt: _daysAgo(40))),
          isTrue,
          reason: s.name,
        );
      }
    });

    test('completed and abandoned matches are never stale', () {
      expect(
        isStaleUnfinishedMatch(_m('c',
            status: MatchStatus.completed,
            scheduledAt: _daysAgo(400),
            completedAt: _daysAgo(399))),
        isFalse,
      );
      expect(
        isStaleUnfinishedMatch(
            _m('d', status: MatchStatus.abandoned, scheduledAt: _daysAgo(400))),
        isFalse,
      );
    });

    test('uses the later of scheduled and started, else createdAt', () {
      expect(
        isStaleUnfinishedMatch(_m('e',
            createdAt: _daysAgo(90),
            scheduledAt: _now.add(const Duration(days: 7)))),
        isFalse,
      );
      expect(
        isStaleUnfinishedMatch(_m('f',
            status: MatchStatus.live,
            scheduledAt: _daysAgo(60),
            startedAt: _daysAgo(3))),
        isFalse,
      );
      expect(isStaleUnfinishedMatch(_m('g', createdAt: _daysAgo(31))), isTrue);
      expect(isStaleUnfinishedMatch(_m('h')), isFalse);
    });

    test('isListedLive / isListedUpcoming drop stale matches', () {
      expect(isListedLive(_m('l1', status: MatchStatus.live, startedAt: _daysAgo(1))), isTrue);
      expect(isListedLive(_m('l2', status: MatchStatus.live, startedAt: _daysAgo(45))), isFalse);
      expect(isListedUpcoming(_m('u1', scheduledAt: _now.add(const Duration(days: 2)))), isTrue);
      expect(isListedUpcoming(_m('u2', scheduledAt: _daysAgo(45))), isFalse);
    });
  });

  test('org Matches tab: stale leave Live / Upcoming, completed stay', () {
    final all = [
      _m('live', status: MatchStatus.live, startedAt: _daysAgo(1)),
      _m('oldLive', status: MatchStatus.live, startedAt: _daysAgo(50)),
      _m('up', scheduledAt: _now.add(const Duration(days: 3))),
      _m('oldUp', scheduledAt: _daysAgo(50)),
      _m('done',
          status: MatchStatus.completed,
          scheduledAt: _daysAgo(200),
          completedAt: _daysAgo(200)),
    ];
    final ids =
        groupOrgMatches(all).expand((s) => s.items).map((m) => m.id).toList();
    expect(ids, ['live', 'up', 'done']);
    final counts = orgBucketCounts(listedOrgMatches(all), orgMatchBucket);
    expect(counts[OrgStatusFilter.live], 1);
    expect(counts[OrgStatusFilter.upcoming], 1);
    expect(counts[OrgStatusFilter.completed], 1);
  });

  test('tournament Live / Upcoming drop stale fixtures, completed intact',
      () async {
    final matches = [
      _m('t-live', status: MatchStatus.live, startedAt: _daysAgo(2), tournamentId: 't'),
      _m('t-oldLive', status: MatchStatus.inningsBreak, startedAt: _daysAgo(40), tournamentId: 't'),
      _m('t-up', scheduledAt: _now.add(const Duration(days: 1)), tournamentId: 't'),
      _m('t-oldUp', scheduledAt: _daysAgo(40), tournamentId: 't'),
      _m('t-done',
          status: MatchStatus.completed,
          scheduledAt: _daysAgo(90),
          completedAt: _daysAgo(90),
          tournamentId: 't'),
    ];
    final container = ProviderContainer(overrides: [
      tournamentMatchesProvider('t').overrideWith((ref) => Stream.value(matches)),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(tournamentMatchesProvider('t'), (_, _) {});
    await container.read(tournamentMatchesProvider('t').future);
    List<String> ids(TournamentMatchFilter f) => container
        .read(tournamentMatchesFilteredProvider((tournamentId: 't', filter: f)))
        .map((m) => m.id)
        .toList();
    expect(ids(TournamentMatchFilter.live), ['t-live']);
    expect(ids(TournamentMatchFilter.upcoming), ['t-up']);
    expect(ids(TournamentMatchFilter.completed), ['t-done']);
    sub.close();
  });
}
