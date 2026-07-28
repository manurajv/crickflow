import '../../features/auth/providers/auth_providers.dart';
import 'admin_route_paths.dart';

/// GoRouter redirect based on [AdminSession].
String? adminAuthRedirect({
  required AdminSession session,
  required String matchedLocation,
}) {
  final loc = matchedLocation;
  final isLogin = loc == AdminRoutePaths.login;
  final isDenied = loc == AdminRoutePaths.accessDenied;

  switch (session.status) {
    case AdminSessionStatus.loading:
      return null;
    case AdminSessionStatus.unauthenticated:
      return isLogin ? null : AdminRoutePaths.login;
    case AdminSessionStatus.noAdminProfile:
    case AdminSessionStatus.inactive:
    case AdminSessionStatus.wrongPanel:
      return isDenied ? null : AdminRoutePaths.accessDenied;
    case AdminSessionStatus.authorized:
      if (isLogin || isDenied) return AdminRoutePaths.dashboard;
      return null;
  }
}
