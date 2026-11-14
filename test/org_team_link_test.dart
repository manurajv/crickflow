import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/data/models/team_model.dart';
import 'package:crickflow/domain/services/series/org_competition_access.dart';
import 'package:crickflow/features/teams/presentation/utils/team_squad_utils.dart';
import 'package:crickflow/features/teams/presentation/widgets/org_locked_team_notice.dart';
import 'package:crickflow/features/teams/presentation/widgets/team_join_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TeamModel _team({Map<String, dynamic>? lock}) => TeamModel.fromMap('t1', {
      'name': 'Lions',
      'createdBy': 'owner',
      'playerIds': ['owner'],
      if (lock != null) 'orgLock': lock,
    });

void main() {
  const lockMap = {'seriesId': 's1', 'clubId': 'c1', 'seriesName': 'City League'};

  group('TeamOrgLock', () {
    test('parses orgLock and exposes the org team path', () {
      final t = _team(lock: lockMap);
      expect(t.isOrgLocked, isTrue);
      expect(t.orgLock!.orgTeamPath, '/series/s1/clubs/c1');
      expect(t.orgLock!.seriesName, 'City League');
    });

    test('incomplete or missing lock means a normal team', () {
      expect(_team().isOrgLocked, isFalse);
      expect(_team(lock: {'seriesId': 's1'}).isOrgLocked, isFalse);
    });

    test('toMap never writes the server-owned lock', () {
      expect(_team(lock: lockMap).toMap().containsKey('orgLock'), isFalse);
    });

    test('copyWith keeps the lock', () {
      expect(_team(lock: lockMap).copyWith(name: 'X').isOrgLocked, isTrue);
    });
  });

  group('locked team permissions outside the org', () {
    final locked = _team(lock: lockMap);
    final free = _team();

    test('owner cannot edit or manage the roster of a locked team', () {
      expect(TeamSquadUtils.canEditTeam('owner', locked), isFalse);
      expect(TeamSquadUtils.canManageJoinRequests('owner', locked), isFalse);
      expect(TeamSquadUtils.canEditTeam('owner', free), isTrue);
      expect(TeamSquadUtils.canManageJoinRequests('owner', free), isTrue);
    });

    test('nobody can request to join a locked team', () {
      expect(
        canRequestJoinTeam(team: locked, uid: 'someone', squad: const []),
        isFalse,
      );
      expect(
        canRequestJoinTeam(team: free, uid: 'someone', squad: const []),
        isTrue,
      );
    });
  });

  testWidgets('notice names the org', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: OrgLockedTeamNotice(lock: _team(lock: lockMap).orgLock!),
        ),
      ),
    );
    expect(find.textContaining('Managed by City League'), findsOneWidget);
  });

  group('proposing in an org', () {
    OrgCompetitionAccess access(SeriesRole role, {bool members = false}) =>
        OrgCompetitionAccess(
          role: role,
          policy: OrgCompetitionPolicy(
            matchProposeAccess: members
                ? OrgProposeAccess.everyone
                : OrgProposeAccess.teamAdmins,
            tournamentProposeAccess: members
                ? OrgProposeAccess.everyone
                : OrgProposeAccess.teamAdmins,
          ),
        );

    test('players see nothing unless the org allows it', () {
      expect(access(SeriesRole.seriesPlayer).match, OrgStartMode.none);
      expect(access(SeriesRole.seriesPlayer).tournament, OrgStartMode.none);
      expect(
        access(SeriesRole.seriesPlayer, members: true).match,
        OrgStartMode.request,
      );
    });

    test('team admins request, admins start directly', () {
      expect(access(SeriesRole.clubAdmin).match, OrgStartMode.request);
      expect(access(SeriesRole.seriesAdmin).tournament, OrgStartMode.direct);
    });
  });
}
