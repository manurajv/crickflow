import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/domain/services/series/org_competition_access.dart';
import 'package:crickflow/features/series/presentation/series_approvals_screen.dart';
import 'package:crickflow/features/series/presentation/tabs/org_matches_tab.dart';
import 'package:crickflow/features/series/presentation/tabs/org_tournaments_tab.dart';
import 'package:crickflow/shared/providers/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crickflow/shared/providers/series_providers.dart';
import 'package:crickflow/shared/providers/start_match_draft_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _policy = OrgCompetitionPolicy();

OrgCompetitionAccess _access(SeriesRole role,
        {OrgCompetitionPolicy policy = _policy, List<String> mine = const []}) =>
    OrgCompetitionAccess(role: role, policy: policy, myTeamIds: mine);

List<Override> _overrides(OrgCompetitionAccess access) => [
      orgCompetitionAccessProvider('s1').overrideWithValue(access),
      authStateProvider.overrideWith((_) => Stream<User?>.value(null)),
      seriesMatchesProvider('s1').overrideWith((_) => Stream.value(const [])),
      seriesTournamentsProvider('s1')
          .overrideWith((_) => Stream.value(const [])),
    ];

Widget _tab(OrgCompetitionAccess access, Widget tab) => ProviderScope(
      overrides: _overrides(access),
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: tab),
      ),
    );

Widget _matches(OrgCompetitionAccess access) =>
    _tab(access, const OrgMatchesTab(seriesId: 's1'));
Widget _tournaments(OrgCompetitionAccess access) =>
    _tab(access, const OrgTournamentsTab(seriesId: 's1'));

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
                policy: _policy.copyWith(proposeAccess: OrgProposeAccess.everyone))
            .tournament,
        OrgStartMode.request,
      );
      expect(_access(SeriesRole.viewer).canStartAnything, isFalse);
    });

    test('who can propose: admins only / team admins only / everyone', () {
      OrgCompetitionAccess at(SeriesRole r, OrgProposeAccess a) =>
          _access(r, policy: _policy.copyWith(proposeAccess: a));
      // Org admins always start directly, whatever the setting.
      for (final a in OrgProposeAccess.values) {
        expect(at(SeriesRole.superAdmin, a).match, OrgStartMode.direct);
        expect(at(SeriesRole.seriesAdmin, a).tournament, OrgStartMode.direct);
      }
      // Admins only: nobody else sees anything.
      expect(at(SeriesRole.clubAdmin, OrgProposeAccess.admins).canStartAnything, isFalse);
      expect(at(SeriesRole.seriesPlayer, OrgProposeAccess.admins).canStartAnything, isFalse);
      // Team admins only.
      expect(at(SeriesRole.clubAdmin, OrgProposeAccess.teamAdmins).match, OrgStartMode.request);
      expect(at(SeriesRole.clubAdmin, OrgProposeAccess.teamAdmins).tournament, OrgStartMode.request);
      expect(at(SeriesRole.seriesPlayer, OrgProposeAccess.teamAdmins).canStartAnything, isFalse);
      // Everyone in the team.
      expect(at(SeriesRole.clubAdmin, OrgProposeAccess.everyone).match, OrgStartMode.request);
      expect(at(SeriesRole.seriesPlayer, OrgProposeAccess.everyone).match, OrgStartMode.request);
      expect(at(SeriesRole.seriesPlayer, OrgProposeAccess.everyone).tournament, OrgStartMode.request);
      expect(at(SeriesRole.viewer, OrgProposeAccess.everyone).canStartAnything, isFalse);
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
      expect(_policy.proposeAccess, OrgProposeAccess.teamAdmins);
    });

    test('existing orgs keep working: membersCanRequest maps to proposeAccess',
        () {
      final legacyOn = OrgCompetitionPolicy.fromMap({'membersCanRequest': true});
      expect(legacyOn.proposeAccess, OrgProposeAccess.everyone);
      expect(legacyOn.membersCanRequest, isTrue);
      expect(
        OrgCompetitionPolicy.fromMap({'membersCanRequest': false}).proposeAccess,
        OrgProposeAccess.teamAdmins,
      );
      expect(OrgCompetitionPolicy.fromMap({}).proposeAccess, OrgProposeAccess.teamAdmins);
      // New field wins over the legacy one; junk falls back safely.
      expect(
        OrgCompetitionPolicy.fromMap(
          {'proposeAccess': 'admins', 'membersCanRequest': true},
        ).proposeAccess,
        OrgProposeAccess.admins,
      );
      expect(
        OrgCompetitionPolicy.fromMap({'proposeAccess': 'nope'}).proposeAccess,
        OrgProposeAccess.teamAdmins,
      );
    });

    test('toMap writes proposeAccess and the legacy flag for older apps', () {
      final map = _policy
          .copyWith(proposeAccess: OrgProposeAccess.everyone)
          .toMap();
      expect(map['proposeAccess'], 'everyone');
      expect(map['membersCanRequest'], true);
      expect(
        _policy.copyWith(proposeAccess: OrgProposeAccess.admins).toMap()['membersCanRequest'],
        false,
      );
      expect(OrgCompetitionPolicy.fromMap(map), OrgCompetitionPolicy.fromMap(map));
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
    await tester.pumpWidget(_matches(_access(SeriesRole.viewer)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org_start_match')), findsNothing);
    expect(find.text('No matches yet'), findsOneWidget);
    expect(find.textContaining('Official org matches will appear'), findsOneWidget);

    await tester.pumpWidget(_tournaments(_access(SeriesRole.viewer)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org_start_tournament')), findsNothing);
    expect(find.text('No tournaments yet'), findsOneWidget);
  });

  testWidgets('proposal buttons follow the org permission', (tester) async {
    OrgCompetitionAccess at(SeriesRole r, OrgProposeAccess a) =>
        _access(r, policy: _policy.copyWith(proposeAccess: a));

    // Team admin: yes in team-admins mode, no in admins-only mode.
    await tester.pumpWidget(
        _matches(at(SeriesRole.clubAdmin, OrgProposeAccess.teamAdmins)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org_start_match')), findsOneWidget);
    expect(find.text('Request a match'), findsOneWidget);

    await tester.pumpWidget(
        _matches(at(SeriesRole.clubAdmin, OrgProposeAccess.admins)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org_start_match')), findsNothing);

    // Player: only when everyone in the team may propose.
    await tester.pumpWidget(
        _tournaments(at(SeriesRole.seriesPlayer, OrgProposeAccess.teamAdmins)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org_start_tournament')), findsNothing);

    await tester.pumpWidget(
        _tournaments(at(SeriesRole.seriesPlayer, OrgProposeAccess.everyone)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org_start_tournament')), findsOneWidget);
    expect(find.text('Request a tournament'), findsOneWidget);

    // Owner always starts directly.
    await tester.pumpWidget(
        _matches(at(SeriesRole.superAdmin, OrgProposeAccess.admins)));
    await tester.pumpAndSettle();
    expect(find.text('Start a match'), findsOneWidget);
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
