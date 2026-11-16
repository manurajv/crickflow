import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/data/models/user_model.dart';
import 'package:crickflow/domain/services/series/org_competition_access.dart';
import 'package:crickflow/features/series/presentation/series_club_detail_screen.dart';
import 'package:crickflow/shared/providers/providers.dart';
import 'package:crickflow/shared/providers/series_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SeriesClubModel _club({SeriesClubStatus status = SeriesClubStatus.approved}) =>
    SeriesClubModel(
      id: 'c1',
      seriesId: 's1',
      name: 'CrickFlow 1',
      status: status,
    );

UserModel _user(String id) => UserModel(
      id: id,
      email: '$id@example.com',
      displayName: 'Player $id',
      playerId: 'CF-$id',
    );

SeriesMembershipModel _member(String userId) => SeriesMembershipModel(
      id: 'm-$userId',
      seriesId: 's1',
      clubId: 'c1',
      userId: userId,
      displayName: 'Player $userId',
    );

List<Override> _overrides({
  UserModel? user,
  SeriesRole role = SeriesRole.viewer,
  List<SeriesMembershipModel> squad = const [],
  List<SeriesClubAdminModel> admins = const [],
  OrgCompetitionAccess? access,
}) {
  const params = (seriesId: 's1', clubId: 'c1');
  final resolvedAccess = access ??
      OrgCompetitionAccess(
        role: role,
        policy: const OrgCompetitionPolicy(),
      );
  return [
    seriesClubByIdProvider('c1').overrideWith((_) async => _club()),
    seriesClubSquadProvider(params).overrideWith((_) => Stream.value(squad)),
    seriesClubAdminsProvider(params).overrideWith((_) => Stream.value(admins)),
    pendingClubJoinApprovalsProvider(params)
        .overrideWith((_) => Stream.value(const [])),
    mySeriesRoleProvider('s1').overrideWithValue(role),
    orgCompetitionAccessProvider('s1').overrideWithValue(resolvedAccess),
    currentUserProfileProvider.overrideWith((_) async => user),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  UserModel? user,
  SeriesRole role = SeriesRole.viewer,
  List<SeriesMembershipModel> squad = const [],
  List<SeriesClubAdminModel> admins = const [],
  OrgCompetitionAccess? access,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(
        user: user,
        role: role,
        squad: squad,
        admins: admins,
        access: access,
      ),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SeriesClubDetailScreen(seriesId: 's1', clubId: 'c1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guest on an approved team sees Request to join, not Search & add',
      (tester) async {
    await _pump(tester);
    expect(find.text('CrickFlow 1'), findsOneWidget);
    expect(find.byKey(const Key('org_team_request_to_join')), findsOneWidget);
    expect(find.text('Request to join'), findsOneWidget);
    expect(find.text('Register & request to join'), findsNothing);
    expect(find.text('Search & add player'), findsNothing);
    expect(find.byKey(const Key('org_team_squad_add')), findsNothing);
    expect(find.text('Start a match'), findsNothing);
    expect(find.text('Pending approvals'), findsNothing);
  });

  testWidgets('signed-in outsider can request to join but cannot add to squad',
      (tester) async {
    await _pump(tester, user: _user('u2'));
    expect(find.byKey(const Key('org_team_request_to_join')), findsOneWidget);
    expect(find.byKey(const Key('org_team_squad_add')), findsNothing);
  });

  testWidgets('active squad member does not see Request to join',
      (tester) async {
    await _pump(
      tester,
      user: _user('p1'),
      role: SeriesRole.seriesPlayer,
      squad: [_member('p1')],
    );
    expect(find.byKey(const Key('org_team_request_to_join')), findsNothing);
    expect(find.byKey(const Key('org_team_squad_add')), findsNothing);
  });

  testWidgets('team admin hides join and gets Squad Add, not a standalone button',
      (tester) async {
    await _pump(
      tester,
      user: _user('ta1'),
      role: SeriesRole.clubAdmin,
      admins: const [
        SeriesClubAdminModel(
          id: 'a1',
          seriesId: 's1',
          clubId: 'c1',
          userId: 'ta1',
        ),
      ],
      access: const OrgCompetitionAccess(
        role: SeriesRole.clubAdmin,
        policy: OrgCompetitionPolicy(),
        myTeamIds: ['c1'],
      ),
    );
    expect(find.byKey(const Key('org_team_request_to_join')), findsNothing);
    expect(find.text('Search & add player'), findsNothing);
    expect(find.byKey(const Key('org_team_squad_add')), findsOneWidget);
    expect(find.text('Request a match'), findsOneWidget);
    expect(find.text('Request a tournament'), findsOneWidget);
    expect(find.text('Pending approvals'), findsNothing);
  });

  testWidgets('org admin keeps start actions, pending approvals, and Squad Add',
      (tester) async {
    await _pump(
      tester,
      user: _user('owner'),
      role: SeriesRole.seriesAdmin,
      access: const OrgCompetitionAccess(
        role: SeriesRole.seriesAdmin,
        policy: OrgCompetitionPolicy(),
      ),
    );
    expect(find.byKey(const Key('org_team_request_to_join')), findsOneWidget);
    expect(find.byKey(const Key('org_team_squad_add')), findsOneWidget);
    expect(find.text('Search & add player'), findsNothing);
    expect(find.text('Start a match'), findsOneWidget);
    expect(find.text('Start a tournament'), findsOneWidget);
    expect(find.text('Pending approvals'), findsOneWidget);
  });
}
