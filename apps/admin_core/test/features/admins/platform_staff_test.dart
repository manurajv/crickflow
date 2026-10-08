import 'package:crickflow_admin_core/crickflow_admin_core.dart';
import 'package:flutter_test/flutter_test.dart';

AdminSession _session(Set<AdminPermission> perms) =>
    AdminSession(status: AdminSessionStatus.authorized, permissions: perms);

void main() {
  test('every platform staff role can enter the Super Admin panel', () {
    for (final r in [
      AdminRole.superAdmin,
      AdminRole.moderator,
      AdminRole.tournamentAdmin,
      AdminRole.support,
      AdminRole.viewer,
    ]) {
      expect(r.allowedPanel, AdminAppType.superAdmin, reason: r.name);
    }
    // Retired Organization Admin role has no panel.
    expect(AdminRole.admin.allowedPanel, isNull);
  });

  test('role docs: superAdmin panel kept, legacy org panel dropped', () {
    expect(
      RoleDefinition.fromMap('moderator', {
        'allowedPanel': 'superAdmin',
        'permissions': {'canModerateCommunity': true},
      }).allowedPanel,
      AdminAppType.superAdmin,
    );
    expect(
      RoleDefinition.fromMap('admin', {
        'allowedPanel': 'organizationAdmin',
      }).allowedPanel,
      isNull,
    );
    expect(
      RoleDefinition.fromMap('viewer', {'allowedPanel': 'none'}).allowedPanel,
      isNull,
    );
  });

  group('adminAuthRedirect for staff', () {
    test('moderator lands on dashboard and is kept out of security', () {
      final s = _session({
        AdminPermission.canViewDashboard,
        AdminPermission.canModerateCommunity,
      });
      expect(
        adminAuthRedirect(session: s, matchedLocation: AdminRoutePaths.login),
        AdminRoutePaths.dashboard,
      );
      expect(
        adminAuthRedirect(
          session: s,
          matchedLocation: AdminRoutePaths.community,
        ),
        isNull,
      );
      expect(
        adminAuthRedirect(
          session: s,
          matchedLocation: AdminRoutePaths.security,
        ),
        AdminRoutePaths.forbidden,
      );
      expect(
        adminAuthRedirect(session: s, matchedLocation: AdminRoutePaths.orgs),
        AdminRoutePaths.forbidden,
      );
    });

    test('viewer without dashboard lands on profile', () {
      final s = _session({AdminPermission.canViewProfile});
      expect(
        adminAuthRedirect(session: s, matchedLocation: AdminRoutePaths.login),
        AdminRoutePaths.profile,
      );
      expect(
        adminAuthRedirect(
          session: s,
          matchedLocation: AdminRoutePaths.dashboard,
        ),
        AdminRoutePaths.profile,
      );
    });
  });

  test('profile load failure goes to the error page, not a blank screen', () {
    const s = AdminSession(
      status: AdminSessionStatus.profileLoadFailed,
      error: 'permission-denied',
    );
    expect(
      adminAuthRedirect(session: s, matchedLocation: AdminRoutePaths.dashboard),
      AdminRoutePaths.accessDenied,
    );
    expect(
      adminAuthRedirect(session: s, matchedLocation: AdminRoutePaths.accessDenied),
      isNull,
    );
  });

  test('super admin lands on the dashboard from login and root', () {
    final s = _session(AdminPermission.values.toSet());
    expect(
      adminAuthRedirect(session: s, matchedLocation: AdminRoutePaths.login),
      AdminRoutePaths.dashboard,
    );
    expect(
      adminAuthRedirect(session: s, matchedLocation: AdminRoutePaths.dashboard),
      isNull,
    );
    expect(
      adminAuthRedirect(session: s, matchedLocation: AdminRoutePaths.orgs),
      isNull,
    );
  });
}
