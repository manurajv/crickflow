import 'package:crickflow_admin_core/crickflow_admin_core.dart';
import 'package:flutter_test/flutter_test.dart';

ManagedSeries _org(String id, String kind, {String status = 'active'}) =>
    ManagedSeries.fromFirestore(id, {
      'name': 'Org $id',
      'kind': kind,
      'status': status,
      'createdBy': 'creator-$id',
      'region': 'Western',
    });

void main() {
  group('ManagedSeries', () {
    test('owner falls back to createdBy when superAdminUserId is unset', () {
      expect(_org('a', 'club').ownerUid, 'creator-a');
      final withOwner = ManagedSeries.fromFirestore('b', {
        'name': 'B',
        'superAdminUserId': 'owner-b',
        'createdBy': 'creator-b',
      });
      expect(withOwner.ownerUid, 'owner-b');
      expect(withOwner.kind, 'series');
      expect(withOwner.status, 'draft');
    });

    test('kind maps to the mobile Orgs families', () {
      expect(OrgFamily.forKind('association'), OrgFamily.associations);
      expect(OrgFamily.forKind('federation'), OrgFamily.associations);
      expect(OrgFamily.forKind('club'), OrgFamily.clubs);
      expect(OrgFamily.forKind('company'), OrgFamily.clubs);
      expect(OrgFamily.forKind('league'), OrgFamily.series);
      expect(OrgFamily.forKind('cup'), OrgFamily.series);
    });
  });

  test('filterOrgs filters by family, status and query', () {
    final all = [
      _org('1', 'club'),
      _org('2', 'association', status: 'suspended'),
      _org('3', 'series'),
    ];
    expect(filterOrgs(all, family: OrgFamily.clubs).map((s) => s.id), ['1']);
    expect(filterOrgs(all, status: 'suspended').map((s) => s.id), ['2']);
    expect(filterOrgs(all, query: 'creator-3').map((s) => s.id), ['3']);
    expect(filterOrgs(all, query: 'western').length, 3);
  });

  test('moderation transitions', () {
    expect(OrgModeration.nextSeriesStatuses('active'), [
      'suspended',
      'archived',
    ]);
    expect(OrgModeration.nextSeriesStatuses('suspended'), [
      'active',
      'archived',
    ]);
    expect(OrgModeration.nextSeriesStatuses('archived'), ['active']);
    expect(OrgModeration.auditAction('active'), 'ENTITY_RESTORED');
    expect(OrgModeration.auditAction('suspended'), 'ENTITY_SUSPENDED');
  });

  test('Orgs & Series route requires the org moderation permission', () {
    expect(
      AdminRoutePermissions.requiredFor(AdminRoutePaths.orgs),
      AdminPermission.canManageOrganizations,
    );
  });
}
