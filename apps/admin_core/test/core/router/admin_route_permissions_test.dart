import 'package:crickflow_admin_core/core/router/admin_route_paths.dart';
import 'package:crickflow_admin_core/core/router/admin_route_permissions.dart';
import 'package:crickflow_admin_core/models/admin_permission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminRoutePermissions.isAllowed', () {
    test('reports allows any of community / discover / viewReports', () {
      expect(
        AdminRoutePermissions.isAllowed(
          AdminRoutePaths.reports,
          (p) => p == AdminPermission.canModerateCommunity,
        ),
        isTrue,
      );
      expect(
        AdminRoutePermissions.isAllowed(
          AdminRoutePaths.reports,
          (p) => p == AdminPermission.canManageDiscover,
        ),
        isTrue,
      );
      expect(
        AdminRoutePermissions.isAllowed(
          AdminRoutePaths.reports,
          (p) => p == AdminPermission.canViewReports,
        ),
        isTrue,
      );
      expect(
        AdminRoutePermissions.isAllowed(
          AdminRoutePaths.reports,
          (_) => false,
        ),
        isFalse,
      );
    });

    test('single-permission routes still require exact grant', () {
      expect(
        AdminRoutePermissions.isAllowed(
          AdminRoutePaths.users,
          (p) => p == AdminPermission.canManageUsers,
        ),
        isTrue,
      );
      expect(
        AdminRoutePermissions.isAllowed(
          AdminRoutePaths.users,
          (p) => p == AdminPermission.canViewDashboard,
        ),
        isFalse,
      );
    });

    test('devops requires canManageDeployments', () {
      expect(
        AdminRoutePermissions.isAllowed(
          AdminRoutePaths.devops,
          (p) => p == AdminPermission.canManageDeployments,
        ),
        isTrue,
      );
      expect(
        AdminRoutePermissions.isAllowed(
          AdminRoutePaths.devops,
          (_) => false,
        ),
        isFalse,
      );
    });

    test('continuity requires canManageContinuity', () {
      expect(
        AdminRoutePermissions.isAllowed(
          AdminRoutePaths.continuity,
          (p) => p == AdminPermission.canManageContinuity,
        ),
        isTrue,
      );
      expect(
        AdminRoutePermissions.isAllowed(
          AdminRoutePaths.continuity,
          (_) => false,
        ),
        isFalse,
      );
    });
  });
}
