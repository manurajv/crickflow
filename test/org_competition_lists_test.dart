import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/tournament_model.dart';
import 'package:crickflow/domain/services/series/org_competition_lists.dart';
import 'package:flutter_test/flutter_test.dart';

MatchModel _m(
  String id, {
  MatchStatus status = MatchStatus.scheduled,
  String official = 'approved',
  String? createdBy,
  String? tournamentId,
  MatchMode mode = MatchMode.normal,
  DateTime? scheduledAt,
  DateTime? completedAt,
  String a = 'Aces',
  String b = 'Blazers',
}) =>
    MatchModel(
      id: id,
      title: id,
      status: status,
      matchMode: mode,
      teamAName: a,
      teamBName: b,
      seriesId: 's1',
      seriesOfficialStatus: official,
      createdBy: createdBy,
      tournamentId: tournamentId,
      scheduledAt: scheduledAt,
      completedAt: completedAt,
    );

TournamentModel _t(
  String id, {
  TournamentStatus status = TournamentStatus.upcoming,
  String official = 'approved',
  DateTime? start,
  DateTime? end,
}) =>
    TournamentModel(
      id: id,
      name: 'Cup $id',
      status: status,
      seriesId: 's1',
      seriesOfficialStatus: official,
      startDate: start,
      endDate: end,
    );

void main() {
  group('org badge flags', () {
    test('match and tournament flags follow the org status', () {
      expect(_m('a').isOrgMatch, isTrue);
      expect(_m('a').isOrgApproved, isTrue);
      expect(_m('a', official: 'pendingApproval').isOrgMatch, isTrue);
      expect(_m('a', official: 'pendingApproval').isOrgApproved, isFalse);
      expect(_m('a', official: 'rejected').isOrgMatch, isFalse);
      expect(const MatchModel(id: 'x', title: 'x').isOrgMatch, isFalse);
      expect(_t('a').isOrgTournament, isTrue);
      expect(_t('a', official: 'rejected').isOrgTournament, isFalse);
      expect(
        const TournamentModel(id: 'x', name: 'x').isOrgTournament,
        isFalse,
      );
    });
  });

  group('visibility', () {
    test('approved is public; pending only for admins and the requester', () {
      expect(
        orgItemVisible(officialStatus: 'approved', createdBy: 'u', isAdmin: false),
        isTrue,
      );
      expect(
        orgItemVisible(officialStatus: 'pendingApproval', createdBy: 'u', isAdmin: false),
        isFalse,
      );
      expect(
        orgItemVisible(officialStatus: 'pendingApproval', createdBy: 'u', isAdmin: true),
        isTrue,
      );
      expect(
        orgItemVisible(
          officialStatus: 'pendingApproval', createdBy: 'u', isAdmin: false, uid: 'u',
        ),
        isTrue,
      );
      expect(
        orgItemVisible(officialStatus: 'rejected', createdBy: 'u', isAdmin: true),
        isFalse,
      );
      expect(
        orgItemVisible(officialStatus: null, createdBy: 'u', isAdmin: true),
        isFalse,
      );
    });

    test('quick matches never show', () {
      final list = visibleOrgMatches(
        [_m('a'), _m('q', mode: MatchMode.quick)],
        isAdmin: true,
      );
      expect(list.map((m) => m.id), ['a']);
    });
  });

  group('matches grouping', () {
    final live = _m('live', status: MatchStatus.live);
    final soon = _m('soon', scheduledAt: DateTime(2026, 5, 1));
    final later = _m('later', scheduledAt: DateTime(2026, 6, 1));
    final old = _m('old', status: MatchStatus.completed, completedAt: DateTime(2026, 1, 1));
    final recent = _m('recent', status: MatchStatus.completed, completedAt: DateTime(2026, 3, 1));
    final all = [old, later, live, recent, soon];

    test('Live → Upcoming (soonest first) → Completed (latest first)', () {
      final sections = groupOrgMatches(all);
      expect(sections.map((s) => s.bucket), [
        OrgBucket.live,
        OrgBucket.upcoming,
        OrgBucket.completed,
      ]);
      expect(sections[1].items.map((m) => m.id), ['soon', 'later']);
      expect(sections[2].items.map((m) => m.id), ['recent', 'old']);
      expect(sections.map((s) => s.title), ['Live now', 'Upcoming', 'Completed']);
    });

    test('status filter keeps one section; empty sections are dropped', () {
      final done = groupOrgMatches(all, status: OrgStatusFilter.completed);
      expect(done.length, 1);
      expect(done.single.bucket, OrgBucket.completed);
      expect(groupOrgMatches([old], status: OrgStatusFilter.live), isEmpty);
    });

    test('tournament filter: standalone, one tournament, search', () {
      final inCup = _m('cup', tournamentId: 't1', scheduledAt: DateTime(2026, 5, 2));
      final list = [soon, inCup];
      expect(
        groupOrgMatches(list, tournamentFilter: 't1').single.items.single.id,
        'cup',
      );
      expect(
        groupOrgMatches(list, tournamentFilter: kOrgStandaloneFilter)
            .single.items.single.id,
        'soon',
      );
      expect(
        groupOrgMatches([_m('x', a: 'Tigers')], query: 'tig').length,
        1,
      );
      expect(groupOrgMatches([_m('x', a: 'Tigers')], query: 'zzz'), isEmpty);
    });

    test('counts per status chip', () {
      final counts = orgBucketCounts<MatchModel>(all, orgMatchBucket);
      expect(counts[OrgStatusFilter.all], 5);
      expect(counts[OrgStatusFilter.live], 1);
      expect(counts[OrgStatusFilter.upcoming], 2);
      expect(counts[OrgStatusFilter.completed], 2);
    });

    test('toss done counts as live, abandoned as completed', () {
      expect(orgMatchBucket(_m('t', status: MatchStatus.tossCompleted)), OrgBucket.live);
      expect(orgMatchBucket(_m('a', status: MatchStatus.abandoned)), OrgBucket.completed);
      expect(orgMatchBucket(_m('d', status: MatchStatus.draft)), OrgBucket.upcoming);
    });
  });

  group('tournaments grouping', () {
    test('live, upcoming (draft included), completed (cancelled included)', () {
      final sections = groupOrgTournaments([
        _t('done', status: TournamentStatus.completed, end: DateTime(2026, 2, 1)),
        _t('cancel', status: TournamentStatus.cancelled, end: DateTime(2026, 3, 1)),
        _t('draft', status: TournamentStatus.draft, start: DateTime(2026, 9, 1)),
        _t('next', start: DateTime(2026, 8, 1)),
        _t('on', status: TournamentStatus.live),
      ]);
      expect(sections.map((s) => s.bucket), [
        OrgBucket.live,
        OrgBucket.upcoming,
        OrgBucket.completed,
      ]);
      expect(sections[1].items.map((t) => t.id), ['next', 'draft']);
      expect(sections[2].items.map((t) => t.id), ['cancel', 'done']);
    });

    test('status filter and search', () {
      final list = [_t('a'), _t('b', status: TournamentStatus.live)];
      expect(
        groupOrgTournaments(list, status: OrgStatusFilter.live).single.items.single.id,
        'b',
      );
      expect(groupOrgTournaments(list, query: 'cup a').single.items.single.id, 'a');
    });
  });
}
