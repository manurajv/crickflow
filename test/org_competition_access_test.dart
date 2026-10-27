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

/// Same access for matches and tournaments (what the old single setting did).
OrgCompetitionPolicy _both(OrgProposeAccess a) => _policy.copyWith(
      matchProposeAccess: a,
      tournamentProposeAccess: a,
    );

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
        policy: _policy.copyWith(matchTeamAdminsNeedApproval: false),
      );
      expect(relaxed.match, OrgStartMode.requestAutoApproved);
      expect(relaxed.tournament, OrgStartMode.request);
    });

    test('players only when the org allows it; viewers never', () {
      expect(_access(SeriesRole.seriesPlayer).canStartAnything, isFalse);
      expect(
        _access(SeriesRole.seriesPlayer,
                policy: _both(OrgProposeAccess.everyone))
            .tournament,
        OrgStartMode.request,
      );
      expect(_access(SeriesRole.viewer).canStartAnything, isFalse);
    });

    test('who can propose: admins only / team admins only / everyone', () {
      OrgCompetitionAccess at(SeriesRole r, OrgProposeAccess a) =>
          _access(r, policy: _both(a));
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

    test('matches and tournaments have separate access', () {
      final split = _policy.copyWith(
        matchProposeAccess: OrgProposeAccess.everyone,
        tournamentProposeAccess: OrgProposeAccess.admins,
      );
      final player = _access(SeriesRole.seriesPlayer, policy: split);
      expect(player.match, OrgStartMode.request);
      expect(player.tournament, OrgStartMode.none);
      final teamAdmin = _access(SeriesRole.clubAdmin, policy: split);
      expect(teamAdmin.match, OrgStartMode.request);
      expect(teamAdmin.tournament, OrgStartMode.none);
      expect(_access(SeriesRole.seriesAdmin, policy: split).tournament,
          OrgStartMode.direct);
    });

    test('approval is separate per kind and per role', () {
      const open = OrgProposeAccess.everyone;
      final p = _policy.copyWith(
        matchProposeAccess: open,
        tournamentProposeAccess: open,
        matchTeamAdminsNeedApproval: false,
        matchPlayersNeedApproval: true,
        tournamentTeamAdminsNeedApproval: true,
        tournamentPlayersNeedApproval: false,
      );
      expect(_access(SeriesRole.clubAdmin, policy: p).match,
          OrgStartMode.requestAutoApproved);
      expect(_access(SeriesRole.seriesPlayer, policy: p).match,
          OrgStartMode.request);
      expect(_access(SeriesRole.clubAdmin, policy: p).tournament,
          OrgStartMode.request);
      expect(_access(SeriesRole.seriesPlayer, policy: p).tournament,
          OrgStartMode.requestAutoApproved);
      expect(_access(SeriesRole.seriesAdmin, policy: p).match,
          OrgStartMode.direct);
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
      expect(_policy.matchProposeAccess, OrgProposeAccess.teamAdmins);
      expect(_policy.tournamentProposeAccess, OrgProposeAccess.teamAdmins);
      expect(_policy.allowWalkIns, isTrue);
      expect(_policy.matchTeamAdminsNeedApproval, isTrue);
      expect(_policy.tournamentPlayersNeedApproval, isTrue);
    });

    test('existing orgs keep working: the single legacy setting seeds both kinds',
        () {
      final legacyOn = OrgCompetitionPolicy.fromMap({
        'membersCanRequest': true,
        'matchRequestsNeedApproval': false,
      });
      expect(legacyOn.matchProposeAccess, OrgProposeAccess.everyone);
      expect(legacyOn.tournamentProposeAccess, OrgProposeAccess.everyone);
      expect(legacyOn.membersCanRequest, isTrue);
      expect(legacyOn.matchTeamAdminsNeedApproval, isFalse);
      expect(legacyOn.matchPlayersNeedApproval, isFalse);
      expect(legacyOn.tournamentTeamAdminsNeedApproval, isTrue);
      expect(legacyOn.allowWalkIns, isTrue);
      expect(
        OrgCompetitionPolicy.fromMap({'membersCanRequest': false}).matchProposeAccess,
        OrgProposeAccess.teamAdmins,
      );
      // proposeAccess wins over membersCanRequest; junk falls back safely.
      expect(
        OrgCompetitionPolicy.fromMap(
          {'proposeAccess': 'admins', 'membersCanRequest': true},
        ).tournamentProposeAccess,
        OrgProposeAccess.admins,
      );
      expect(
        OrgCompetitionPolicy.fromMap({'proposeAccess': 'nope'}).matchProposeAccess,
        OrgProposeAccess.teamAdmins,
      );
    });

    test('per-kind fields win over the legacy ones', () {
      final p = OrgCompetitionPolicy.fromMap({
        'proposeAccess': 'teamAdmins',
        'matchProposeAccess': 'everyone',
        'tournamentProposeAccess': 'admins',
        'matchTeamAdminsNeedApproval': false,
        'tournamentPlayersNeedApproval': false,
        'allowWalkIns': false,
      });
      expect(p.matchProposeAccess, OrgProposeAccess.everyone);
      expect(p.tournamentProposeAccess, OrgProposeAccess.admins);
      expect(p.matchTeamAdminsNeedApproval, isFalse);
      expect(p.matchPlayersNeedApproval, isTrue);
      expect(p.tournamentPlayersNeedApproval, isFalse);
      expect(p.allowWalkIns, isFalse);
    });

    test('toMap writes the new fields plus legacy mirrors for older apps', () {
      final p = _policy.copyWith(
        matchProposeAccess: OrgProposeAccess.everyone,
        tournamentProposeAccess: OrgProposeAccess.admins,
        matchPlayersNeedApproval: false,
        matchTeamAdminsNeedApproval: false,
        allowWalkIns: false,
      );
      final map = p.toMap();
      expect(map['matchProposeAccess'], 'everyone');
      expect(map['tournamentProposeAccess'], 'admins');
      expect(map['allowWalkIns'], false);
      expect(map['matchPlayersNeedApproval'], false);
      // Legacy: most permissive access, approval needed if any role needs it.
      expect(map['proposeAccess'], 'everyone');
      expect(map['membersCanRequest'], true);
      expect(map['matchRequestsNeedApproval'], false);
      expect(map['tournamentRequestsNeedApproval'], true);
      // Round trip.
      expect(OrgCompetitionPolicy.fromMap(map), p);
      expect(
        _both(OrgProposeAccess.admins).toMap()['membersCanRequest'],
        false,
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
        _access(r, policy: _both(a));

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
