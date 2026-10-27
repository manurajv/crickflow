import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/data/models/team_model.dart';
import 'package:crickflow/data/models/tournament_model.dart';
import 'package:crickflow/data/models/user_model.dart';
import 'package:crickflow/data/services/series_functions_service.dart';
import 'package:crickflow/domain/services/series/org_competition_access.dart';
import 'package:crickflow/features/series/presentation/tabs/org_leaderboard_tab.dart';
import 'package:crickflow/features/series/presentation/tabs/org_matches_tab.dart';
import 'package:crickflow/features/series/presentation/tabs/org_tournaments_tab.dart';
import 'package:crickflow/features/series/presentation/widgets/org_permissions_section.dart';
import 'package:crickflow/shared/providers/providers.dart';
import 'package:crickflow/shared/providers/series_providers.dart';
import 'package:crickflow/shared/widgets/match_card_ui.dart';
import 'package:crickflow/shared/widgets/org_badge.dart';
import 'package:crickflow/shared/widgets/tournament_list_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SeriesModel _org() => SeriesModel.fromMap('s1', {
      'name': 'City League',
      'status': 'active',
      'kind': 'series',
      'superAdminUserId': 'owner',
    });

MatchModel _match(
  String id, {
  String? seriesId = 's1',
  String? official = 'approved',
  MatchStatus status = MatchStatus.scheduled,
  String a = 'Aces',
  String b = 'Blazers',
  String? createdBy,
}) =>
    MatchModel(
      id: id,
      title: id,
      status: status,
      teamAName: a,
      teamBName: b,
      seriesId: seriesId,
      seriesOfficialStatus: official,
      createdBy: createdBy,
      scheduledAt: DateTime(2026, 12, 1, 10),
    );

class _FakeFunctions implements SeriesFunctionsService {
  Map<String, dynamic>? policySent;

  @override
  Future<Map<String, dynamic>> updateSeriesCompetitionPolicy({
    required String seriesId,
    required Map<String, dynamic> policy,
  }) async {
    policySent = policy;
    return {'ok': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _base({
  List<MatchModel> matches = const [],
  List<TournamentModel> tournaments = const [],
  OrgCompetitionAccess? access,
}) =>
    [
      seriesByIdProvider('s1').overrideWith((_) => Stream.value(_org())),
      authStateProvider.overrideWith((_) => Stream<User?>.value(null)),
      allTeamsProvider.overrideWith((_) => Stream.value(const <TeamModel>[])),
      tournamentsProvider
          .overrideWith((_) => Stream.value(const <TournamentModel>[])),
      currentUserProfileProvider.overrideWith((_) async => null as UserModel?),
      seriesMatchesProvider('s1').overrideWith((_) => Stream.value(matches)),
      seriesTournamentsProvider('s1')
          .overrideWith((_) => Stream.value(tournaments)),
      if (access != null)
        orgCompetitionAccessProvider('s1').overrideWithValue(access),
    ];

Widget _app(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: child),
      ),
    );

OrgCompetitionAccess _viewer() => const OrgCompetitionAccess(
      role: SeriesRole.viewer,
      policy: OrgCompetitionPolicy(),
    );
OrgCompetitionAccess _admin() => const OrgCompetitionAccess(
      role: SeriesRole.seriesAdmin,
      policy: OrgCompetitionPolicy(),
    );

void main() {
  testWidgets('org badge chip shows the org and its state', (tester) async {
    await tester.pumpWidget(_app(const Column(children: [
      OrgBadgeChip(name: 'City League'),
      OrgBadgeChip(name: 'Pending League', pending: true),
    ])));
    expect(find.text('City League'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });

  group('org badge on cards', () {
    testWidgets('org match cards carry the badge, normal ones do not',
        (tester) async {
      await tester.pumpWidget(_app(
        Column(children: [
          MatchCardContent(match: _match('org')),
          MatchCardContent(match: _match('plain', seriesId: null, official: null)),
        ]),
        overrides: _base(),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('org_badge')), findsOneWidget);
      expect(find.text('City League'), findsOneWidget);
    });

    testWidgets('pending org match is badged as pending', (tester) async {
      await tester.pumpWidget(_app(
        MatchCardContent(match: _match('p', official: 'pendingApproval')),
        overrides: _base(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('rejected org match has no badge', (tester) async {
      await tester.pumpWidget(_app(
        MatchCardContent(match: _match('r', official: 'rejected')),
        overrides: _base(),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('org_badge')), findsNothing);
    });

    testWidgets('org tournament cards carry the badge', (tester) async {
      await tester.pumpWidget(_app(
        Column(children: [
          const TournamentListCard(
            tournament: TournamentModel(
              id: 't1', name: 'Org Cup', seriesId: 's1',
              seriesOfficialStatus: 'approved',
            ),
          ),
          const TournamentListCard(
            tournament: TournamentModel(id: 't2', name: 'Street Cup'),
          ),
        ]),
        overrides: _base(),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('org_badge')), findsOneWidget);
      expect(find.text('City League'), findsOneWidget);
    });
  });

  group('Matches tab', () {
    testWidgets('groups matches and filters by status', (tester) async {
      final matches = [
        _match('live', status: MatchStatus.live, a: 'Livers', b: 'Others'),
        _match('soon', a: 'Soonies', b: 'Later'),
        _match('hidden', official: 'pendingApproval', a: 'Secret', b: 'Team'),
      ];
      await tester.pumpWidget(_app(
        const OrgMatchesTab(seriesId: 's1'),
        overrides: _base(matches: matches, access: _viewer()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Live now'), findsOneWidget);
      expect(find.text('Upcoming'), findsWidgets);
      expect(find.text('Livers'), findsOneWidget);
      expect(find.text('Soonies'), findsOneWidget);
      // Pending requests are not public.
      expect(find.text('Secret'), findsNothing);
      expect(find.text('Upcoming (1)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('org_filter_live')));
      await tester.pumpAndSettle();
      expect(find.text('Livers'), findsOneWidget);
      expect(find.text('Soonies'), findsNothing);

      await tester.tap(find.byKey(const Key('org_filter_completed')));
      await tester.pumpAndSettle();
      expect(find.text('No matches in this filter'), findsOneWidget);
    });

    testWidgets('org admins also see pending requests, marked pending',
        (tester) async {
      await tester.pumpWidget(_app(
        const OrgMatchesTab(seriesId: 's1'),
        overrides: _base(
          matches: [
            _match('p', official: 'pendingApproval', a: 'Secret', b: 'Team'),
          ],
          access: _admin(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Secret'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byKey(const Key('org_start_match')), findsOneWidget);
    });
  });

  group('Tournaments tab', () {
    testWidgets('groups tournaments by status', (tester) async {
      await tester.pumpWidget(_app(
        const OrgTournamentsTab(seriesId: 's1'),
        overrides: _base(
          tournaments: const [
            TournamentModel(
              id: 'a', name: 'Summer Cup', seriesId: 's1',
              seriesOfficialStatus: 'approved', status: TournamentStatus.live,
            ),
            TournamentModel(
              id: 'b', name: 'Winter Cup', seriesId: 's1',
              seriesOfficialStatus: 'approved',
            ),
            TournamentModel(
              id: 'c', name: 'Hidden Cup', seriesId: 's1',
              seriesOfficialStatus: 'pendingApproval',
            ),
          ],
          access: _viewer(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Live now'), findsOneWidget);
      expect(find.text('Summer Cup'), findsOneWidget);
      expect(find.text('Winter Cup'), findsOneWidget);
      expect(find.text('Hidden Cup'), findsNothing);
    });
  });

  group('Leaderboard tab', () {
    testWidgets('shows the points table and the ranking categories',
        (tester) async {
      await tester.pumpWidget(_app(
        OrgLeaderboardTab(seriesId: 's1', series: _org()),
        overrides: [
          ..._base(),
          clubsForSeriesProvider('s1').overrideWith(
            (_) => Stream.value(const [
              SeriesClubModel(
                id: 'ca', seriesId: 's1', name: 'Aces', linkedTeamId: 'ta',
                status: SeriesClubStatus.approved,
              ),
              SeriesClubModel(
                id: 'cb', seriesId: 's1', name: 'Blazers', linkedTeamId: 'tb',
                status: SeriesClubStatus.approved,
              ),
            ]),
          ),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('org_points_table')), findsOneWidget);
      expect(find.text('Aces'), findsOneWidget);
      expect(find.text('Blazers'), findsOneWidget);
      for (final col in ['P', 'W', 'L', 'T', 'NR', 'Pts', 'NRR']) {
        expect(find.text(col), findsWidgets, reason: col);
      }

      await tester.tap(find.byKey(const Key('org_leaderboard_players')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('org_section_batting')), findsOneWidget);
      expect(find.byKey(const Key('org_section_bowling')), findsOneWidget);
      expect(find.byKey(const Key('org_section_fielding')), findsOneWidget);
      expect(find.text('No rankings yet'), findsOneWidget);
    });
  });

  group('Permissions section', () {
    testWidgets('owner picks who can propose and saves it', (tester) async {
      final fns = _FakeFunctions();
      await tester.pumpWidget(_app(
        const SingleChildScrollView(
          child: OrgPermissionsSection(seriesId: 's1'),
        ),
        overrides: [
          orgCompetitionPolicyProvider('s1').overrideWith(
            (_) => Stream.value(
              OrgCompetitionPolicy.fromMap({'membersCanRequest': false}),
            ),
          ),
          seriesFunctionsServiceProvider.overrideWithValue(fns),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Org admins only'), findsOneWidget);
      expect(find.text('Team admins only'), findsOneWidget);
      expect(find.text('Everyone in the team'), findsOneWidget);
      // Existing org: team admins only is selected, nothing to save yet.
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('org_permissions_save')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('org_access_everyone')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('org_permissions_save')));
      await tester.pumpAndSettle();

      expect(fns.policySent?['proposeAccess'], 'everyone');
      expect(fns.policySent?['membersCanRequest'], true);
      expect(find.text('Permissions saved'), findsOneWidget);
    });

    testWidgets('legacy players-can-propose orgs show Everyone selected',
        (tester) async {
      await tester.pumpWidget(_app(
        const SingleChildScrollView(
          child: OrgPermissionsSection(seriesId: 's1'),
        ),
        overrides: [
          orgCompetitionPolicyProvider('s1').overrideWith(
            (_) => Stream.value(
              OrgCompetitionPolicy.fromMap({'membersCanRequest': true}),
            ),
          ),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      final everyone = find.descendant(
        of: find.byKey(const Key('org_access_everyone')),
        matching: find.byIcon(Icons.radio_button_checked),
      );
      expect(everyone, findsOneWidget);
    });
  });
}
