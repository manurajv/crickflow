import '../../features/auth/providers/auth_providers.dart';
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
      if (isLogin || isDenied) return AdminRoutePaths.dashboard;
      if (isForbidden) return null;

      final required = AdminRoutePermissions.requiredFor(loc);
      if (required != null && !session.hasPermission(required)) {
        return AdminRoutePaths.forbidden;
      }
      return null;
  }
}
