import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/domain/services/series/series_permission_service.dart';

void main() {
  group('SeriesModel', () {
    test('fromMap/toMap round-trip preserves settings', () {
      final model = SeriesModel(
        id: 's1',
        name: 'T20 Softball Sri Lanka',
        kind: SeriesKind.series,
        status: SeriesStatus.active,
        superAdminUserId: 'u1',
        settings: const SeriesSettingsModel(
          maxSquadSize: 18,
          requireNationalId: true,
          requirePassport: false,
          rankingRules: SeriesRankingRulesModel(winPoints: 3),
        ),
        createdBy: 'u1',
      );
      final mapped = SeriesModel.fromMap('s1', model.toMap());
      expect(mapped.name, 'T20 Softball Sri Lanka');
      expect(mapped.settings.maxSquadSize, 18);
      expect(mapped.settings.requireNationalId, isTrue);
      expect(mapped.settings.rankingRules.winPoints, 3);
      expect(mapped.superAdminUserId, 'u1');
    });
  });

  group('SeriesPermissionService', () {
    const service = SeriesPermissionService();
    final series = SeriesModel(
      id: 's1',
      name: 'Test',
      superAdminUserId: 'super',
      createdBy: 'super',
      status: SeriesStatus.active,
    );

    test('creator/super admin is recognized', () {
      expect(
        service.isSuperAdmin(series: series, userId: 'super'),
        isTrue,
      );
      expect(
        service.isSuperAdmin(series: series, userId: 'other'),
        isFalse,
      );
    });

    test('series admin cannot bypass super-admin-only approve flag', () {
      final admins = [
        const SeriesAdminModel(
          id: 'a1',
          seriesId: 's1',
          userId: 'admin1',
          status: 'active',
        ),
      ];
      expect(
        service.canApprove(
          series: series,
          userId: 'admin1',
          admins: admins,
          requiresSuperAdmin: true,
        ),
        isFalse,
      );
      expect(
        service.canApprove(
          series: series,
          userId: 'super',
          admins: admins,
          requiresSuperAdmin: true,
        ),
        isTrue,
      );
    });

    test('club admin can propose match for own club', () {
      final clubAdmins = [
        const SeriesClubAdminModel(
          id: 'ca1',
          seriesId: 's1',
          clubId: 'c1',
          userId: 'clubAdmin',
          status: 'active',
        ),
      ];
      expect(
        service.canProposeMatch(
          series: series,
          userId: 'clubAdmin',
          clubId: 'c1',
          admins: const [],
          clubAdmins: clubAdmins,
        ),
        isTrue,
      );
      expect(
        service.canProposeMatch(
          series: series,
          userId: 'clubAdmin',
          clubId: 'c2',
          admins: const [],
          clubAdmins: clubAdmins,
        ),
        isFalse,
      );
    });

    test('role hierarchy resolves highest scoped role', () {
      final role = service.highestRole(
        series: series,
        userId: 'super',
        admins: const [],
        clubAdmins: const [],
        memberships: const [],
      );
      expect(role, SeriesRole.superAdmin);
    });
  });

  group('SeriesApprovalModel', () {
    test('parses pending approval', () {
      final a = SeriesApprovalModel.fromMap('ap1', {
        'seriesId': 's1',
        'targetType': 'playerJoin',
        'targetId': 't1',
        'status': 'pending',
        'requestedBy': 'u2',
      });
      expect(a.isPending, isTrue);
      expect(a.targetType, SeriesApprovalTargetType.playerJoin);
    });
  });

  group('SeriesClubModel', () {
    test('isApproved only when status approved', () {
      final pending = SeriesClubModel.fromMap('c1', {
        'seriesId': 's1',
        'name': 'Lightning',
        'status': 'pending',
      });
      final approved = SeriesClubModel.fromMap('c1', {
        'seriesId': 's1',
        'name': 'Lightning',
        'status': 'approved',
      });
      expect(pending.isApproved, isFalse);
      expect(approved.isApproved, isTrue);
    });
  });

  group('Series competition official status', () {
    test('only approved competitions are official', () {
      final draft = SeriesCompetitionModel.fromMap('x', {
        'seriesId': 's1',
        'type': 'singleMatch',
        'status': 'draft',
      });
      final approved = SeriesCompetitionModel.fromMap('x', {
        'seriesId': 's1',
        'type': 'singleMatch',
        'status': 'approved',
      });
      expect(draft.isOfficial, isFalse);
      expect(approved.isOfficial, isTrue);
    });
  });

  group('Series ranking isolation', () {
    test('player ranking averages are series-local', () {
      final ranking = SeriesPlayerRankingModel.fromMap('r1', {
        'seriesId': 's1',
        'userId': 'u1',
        'runs': 184,
        'innings': 4,
        'ballsFaced': 100,
        'wickets': 5,
        'bowlingRuns': 40,
        'oversBowled': 10,
      });
      expect(ranking.battingAverage, 46);
      expect(ranking.strikeRate, 184);
      expect(ranking.bowlingAverage, 8);
      expect(ranking.economy, 4);
    });
  });

  group('Squad max semantics', () {
    test('settings maxSquadSize is configurable not hardcoded 20', () {
      final settings = SeriesSettingsModel.fromMap({'maxSquadSize': 22});
      expect(settings.maxSquadSize, 22);
      final defaults = SeriesSettingsModel.fromMap(null);
      expect(defaults.maxSquadSize, 20);
    });
  });

  group('SeriesAdminModel', () {
    test('parses active admin', () {
      final a = SeriesAdminModel.fromMap('a1', {
        'seriesId': 's1',
        'userId': 'u2',
        'status': 'active',
        'permissions': ['approve'],
      });
      expect(a.status, 'active');
      expect(a.permissions, ['approve']);
    });
  });

  group('SeriesCompetitionModel', () {
    test('tournament type parses', () {
      final c = SeriesCompetitionModel.fromMap('c1', {
        'seriesId': 's1',
        'type': 'tournament',
        'status': 'pendingApproval',
        'tournamentId': 't1',
      });
      expect(c.type, SeriesCompetitionType.tournament);
      expect(c.isOfficial, isFalse);
    });
  });

  group('SeriesAuditLogModel', () {
    test('round-trip map', () {
      final log = SeriesAuditLogModel(
        id: 'l1',
        seriesId: 's1',
        actorUserId: 'u1',
        action: 'CLUB_APPROVED',
        actorRole: 'superAdmin',
        targetType: 'club',
        targetId: 'c1',
      );
      final mapped = SeriesAuditLogModel.fromMap('l1', log.toMap());
      expect(mapped.action, 'CLUB_APPROVED');
      expect(mapped.targetId, 'c1');
    });
  });
}
