import '../../features/auth/providers/auth_providers.dart';
import '../../models/admin_permission.dart';
import 'admin_route_paths.dart';
import 'admin_route_permissions.dart';

/// GoRouter redirect: auth session + per-route permission guards.
String? adminAuthRedirect({
  required AdminSession session,
  required String matchedLocation,
}) {
  final loc = matchedLocation;
  final isLogin = loc == AdminRoutePaths.login;
  final isDenied = loc == AdminRoutePaths.accessDenied;
  final isForbidden = loc == AdminRoutePaths.forbidden;

  switch (session.status) {
    case AdminSessionStatus.loading:
      return null;
    case AdminSessionStatus.unauthenticated:
      return isLogin ? null : AdminRoutePaths.login;
    case AdminSessionStatus.noAdminProfile:
    case AdminSessionStatus.inactive:
    case AdminSessionStatus.unauthorizedRole:
    case AdminSessionStatus.wrongPanel:
      return isDenied ? null : AdminRoutePaths.accessDenied;
    case AdminSessionStatus.authorized:
      // Staff roles without the dashboard (e.g. Viewer) land on their profile.
      final home = session.hasPermission(AdminPermission.canViewDashboard)
          ? AdminRoutePaths.dashboard
          : AdminRoutePaths.profile;
      if (isLogin || isDenied) return home;
      if (isForbidden) return null;
      if (loc == AdminRoutePaths.dashboard && home != loc) return home;

      if (!AdminRoutePermissions.isAllowed(loc, session.hasPermission)) {
        return AdminRoutePaths.forbidden;
      }
      return null;
  }
}
