import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/domain/services/series/org_competition_access.dart';
import 'package:crickflow/features/series/presentation/series_approvals_screen.dart';
import 'package:crickflow/features/series/presentation/series_competitions_screen.dart';
import 'package:crickflow/shared/providers/series_providers.dart';
import 'package:crickflow/shared/providers/start_match_draft_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _policy = OrgCompetitionPolicy();

OrgCompetitionAccess _access(SeriesRole role,
        {OrgCompetitionPolicy policy = _policy, List<String> mine = const []}) =>
    OrgCompetitionAccess(role: role, policy: policy, myTeamIds: mine);

Widget _competitions(OrgCompetitionAccess access) => ProviderScope(
      overrides: [
        orgCompetitionAccessProvider('s1').overrideWithValue(access),
        seriesCompetitionsProvider('s1')
            .overrideWith((_) => Stream.value(const <SeriesCompetitionModel>[])),
        clubsForSeriesProvider('s1')
            .overrideWith((_) => Stream.value(const <SeriesClubModel>[])),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const SeriesCompetitionsScreen(seriesId: 's1'),
      ),
    );

void main() {
  group('OrgCompetitionAccess', () {
    test('owner and admins start directly', () {
      expect(_access(SeriesRole.superAdmin).tournament, OrgStartMode.direct);
      expect(_access(SeriesRole.seriesAdmin).match, OrgStartMode.direct);
      expect(_access(SeriesRole.superAdmin).isOwner, isTrue);
      expect(_access(SeriesRole.seriesAdmin).isOwner, isFalse);
    });

    test('team admins request; auto-approved when the org turns approval off', () {
      expect(_access(SeriesRole.clubAdmin).match, OrgStartMode.request);
      final relaxed = _access(
        SeriesRole.clubAdmin,
        policy: _policy.copyWith(matchRequestsNeedApproval: false),
      );
      expect(relaxed.match, OrgStartMode.requestAutoApproved);
      expect(relaxed.tournament, OrgStartMode.request);
    });

    test('players only when the org allows it; viewers never', () {
      expect(_access(SeriesRole.seriesPlayer).canStartAnything, isFalse);
      expect(
        _access(SeriesRole.seriesPlayer,
                policy: _policy.copyWith(membersCanRequest: true))
            .tournament,
        OrgStartMode.request,
      );
      expect(_access(SeriesRole.viewer).canStartAnything, isFalse);
    });

    test('requesters must include one of their teams', () {
      final a = _access(SeriesRole.clubAdmin, mine: ['c1']);
      expect(a.matchTeamsError('c2', 'c3'), isNotNull);
      expect(a.matchTeamsError('c1', 'c3'), isNull);
      expect(a.matchTeamsError('c1', 'c1'), isNotNull);
      expect(_access(SeriesRole.seriesAdmin).matchTeamsError('c2', 'c3'), isNull);
    });

    test('policy parses missing keys as safe defaults', () {
      expect(OrgCompetitionPolicy.fromMap(null), _policy);
      expect(
        OrgCompetitionPolicy.fromMap({'membersCanRequest': true}).membersCanRequest,
        isTrue,
      );
    });
  });

  test('playableOrgTeams keeps approved teams linked to a CrickFlow team', () {
    const teams = [
      SeriesClubModel(id: 'a', seriesId: 's', name: 'A', status: SeriesClubStatus.approved, linkedTeamId: 't1'),
      SeriesClubModel(id: 'b', seriesId: 's', name: 'B', status: SeriesClubStatus.approved),
      SeriesClubModel(id: 'c', seriesId: 's', name: 'C', status: SeriesClubStatus.pending, linkedTeamId: 't3'),
    ];
    expect(playableOrgTeams(teams).map((t) => t.id), ['a']);
  });

  test('seriesTeamsError requires both sides to be org teams', () {
    final base = StartMatchDraft(matchId: 'm', teamAName: 'x', teamBName: 'y');
    expect(seriesTeamsError(base), isNull);
    final org = StartMatchDraft(
      matchId: 'm',
      seriesId: 's1',
      seriesTeamIds: const ['t1', 't2'],
      teamAName: 'x',
      teamBName: 'y',
    );
    expect(seriesTeamsError(org), isNotNull);
  });

  testWidgets('users without access see no start actions', (tester) async {
    await tester.pumpWidget(_competitions(_access(SeriesRole.viewer)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org_start_match')), findsNothing);
    expect(find.byKey(const Key('org_start_tournament')), findsNothing);
    expect(find.byKey(const Key('org_request_settings')), findsNothing);
  });

  testWidgets('team admins see request actions, owners also see settings',
      (tester) async {
    await tester.pumpWidget(_competitions(_access(SeriesRole.clubAdmin)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org_start_match')), findsOneWidget);
    expect(find.byKey(const Key('org_request_settings')), findsNothing);

    await tester.pumpWidget(_competitions(_access(SeriesRole.superAdmin)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org_start_tournament')), findsOneWidget);
    expect(find.byKey(const Key('org_request_settings')), findsOneWidget);
  });

  testWidgets('rejecting needs a reason', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await askRejectionReason(context),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('reject_reason_confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('reject_reason_field')), 'Clash');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(result, 'Clash');
  });
}
