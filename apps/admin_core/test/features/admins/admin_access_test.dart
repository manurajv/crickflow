import 'package:crickflow_admin_core/crickflow_admin_core.dart';
import 'package:flutter_test/flutter_test.dart';

AdminAccount _account({
  String uid = 'u1',
  String roleId = 'admin',
  AdminAccessStatus status = AdminAccessStatus.active,
  String? org = 'org1',
}) {
  return AdminAccount(
    uid: uid,
    email: '$uid@example.com',
    roleId: roleId,
    status: status,
    organizationId: org,
  );
}

void main() {
  group('AdminAccessStatus.resolve', () {
    test('active when isActive', () {
      expect(
        AdminAccessStatus.resolve(raw: 'revoked', isActive: true),
        AdminAccessStatus.active,
      );
    });
    test('revoked only when explicitly revoked', () {
      expect(
        AdminAccessStatus.resolve(raw: 'revoked', isActive: false),
        AdminAccessStatus.revoked,
      );
      expect(
        AdminAccessStatus.resolve(raw: null, isActive: false),
        AdminAccessStatus.suspended,
      );
    });
  });

  group('AdminAccount.fromMap', () {
    test('parses fields and overrides', () {
      final a = AdminAccount.fromMap('abc', {
        'email': 'ana@example.com',
        'displayName': 'Ana Perera',
        'roleId': 'superAdmin',
        'organizationId': '  ',
        'isActive': false,
        'accessStatus': 'suspended',
        'permissionOverrides': {'canManageAds': false, 'bad': 'x'},
        'updatedAt': '2026-10-08T10:00:00.000',
      });
      expect(a.isSuperAdmin, isTrue);
      expect(a.status, AdminAccessStatus.suspended);
      expect(a.hasOrganization, isFalse);
      expect(a.permissionOverrides, {'canManageAds': false});
      expect(a.initials, 'AP');
      expect(a.updatedAt, isNotNull);
    });
  });

  group('AdminAccessPolicy.checkChange', () {
    test('non super admin is rejected', () {
      expect(
        AdminAccessPolicy.checkChange(
          actorUid: 'me',
          actorIsSuperAdmin: false,
          target: _account(),
          nextRoleId: 'admin',
          nextStatus: AdminAccessStatus.suspended,
          activeSuperAdminCount: 2,
        ),
        isNotNull,
      );
    });

    test('cannot change own role or status', () {
      expect(
        AdminAccessPolicy.checkChange(
          actorUid: 'me',
          actorIsSuperAdmin: true,
          target: _account(uid: 'me', roleId: 'superAdmin', org: null),
          nextRoleId: 'superAdmin',
          nextStatus: AdminAccessStatus.suspended,
          activeSuperAdminCount: 3,
        ),
        contains('own role'),
      );
      // Editing own display name / overrides (same role + status) is allowed.
      expect(
        AdminAccessPolicy.checkChange(
          actorUid: 'me',
          actorIsSuperAdmin: true,
          target: _account(uid: 'me', roleId: 'superAdmin', org: null),
          nextRoleId: 'superAdmin',
          nextStatus: AdminAccessStatus.active,
          activeSuperAdminCount: 1,
        ),
        isNull,
      );
    });

    test('last active super admin cannot be removed', () {
      final target = _account(uid: 'other', roleId: 'superAdmin', org: null);
      expect(
        AdminAccessPolicy.checkChange(
          actorUid: 'me',
          actorIsSuperAdmin: true,
          target: target,
          nextRoleId: 'admin',
          nextStatus: AdminAccessStatus.active,
          activeSuperAdminCount: 1,
          nextOrganizationId: 'org1',
          nextRoleNeedsOrganization: true,
        ),
        contains('At least one'),
      );
      expect(
        AdminAccessPolicy.checkChange(
          actorUid: 'me',
          actorIsSuperAdmin: true,
          target: target,
          nextRoleId: 'superAdmin',
          nextStatus: AdminAccessStatus.revoked,
          activeSuperAdminCount: 2,
        ),
        isNull,
      );
    });

    test('org admin needs an organization while active', () {
      expect(
        AdminAccessPolicy.checkChange(
          actorUid: 'me',
          actorIsSuperAdmin: true,
          target: _account(org: null),
          nextRoleId: 'admin',
          nextStatus: AdminAccessStatus.active,
          activeSuperAdminCount: 1,
          nextRoleNeedsOrganization: true,
        ),
        contains('organization'),
      );
      // Suspending an unscoped org admin is still allowed.
      expect(
        AdminAccessPolicy.checkChange(
          actorUid: 'me',
          actorIsSuperAdmin: true,
          target: _account(org: null),
          nextRoleId: 'admin',
          nextStatus: AdminAccessStatus.suspended,
          activeSuperAdminCount: 1,
          nextRoleNeedsOrganization: true,
        ),
        isNull,
      );
    });
  });

  group('AdminAccessPolicy.checkGrant', () {
    const candidate = AdminCandidate(uid: 'new', email: 'n@example.com');
    test('requires org for org roles', () {
      expect(
        AdminAccessPolicy.checkGrant(
          actorUid: 'me',
          actorIsSuperAdmin: true,
          candidate: candidate,
          roleNeedsOrganization: true,
        ),
        isNotNull,
      );
      expect(
        AdminAccessPolicy.checkGrant(
          actorUid: 'me',
          actorIsSuperAdmin: true,
          candidate: candidate,
          organizationId: 'org1',
          roleNeedsOrganization: true,
        ),
        isNull,
      );
    });
    test('cannot grant to self', () {
      expect(
        AdminAccessPolicy.checkGrant(
          actorUid: 'new',
          actorIsSuperAdmin: true,
          candidate: candidate,
        ),
        isNotNull,
      );
    });
  });

  group('resolveOrgAccess', () {
    test('blocks suspended / archived / deleted orgs', () {
      expect(resolveOrgAccess({'status': 'suspended'}), AdminOrgAccess.blocked);
      expect(
        resolveOrgAccess({'status': 'active', 'recordStatus': 'soft_deleted'}),
        AdminOrgAccess.blocked,
      );
      expect(resolveOrgAccess({'status': 'pending'}), AdminOrgAccess.allowed);
      expect(resolveOrgAccess(null), AdminOrgAccess.allowed);
    });
  });

  test('admins route requires canManageSecurity', () {
    expect(
      AdminRoutePermissions.requiredFor(AdminRoutePaths.admins),
      AdminPermission.canManageSecurity,
    );
  });

  test('AdminUser exposes revoked state', () {
    final u = AdminUser.fromMap('x', {
      'email': 'x@example.com',
      'roleId': 'admin',
      'isActive': false,
      'accessStatus': 'revoked',
    });
    expect(u.isRevoked, isTrue);
  });
}
