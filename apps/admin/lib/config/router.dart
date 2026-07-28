import 'package:crickflow_admin_core/crickflow_admin_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

GoRouter createOrgAdminRouter(Ref ref) {
  final refresh = GoRouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: AdminRoutePaths.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(adminSessionProvider);
      return adminAuthRedirect(
        session: session,
        matchedLocation: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: AdminRoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AdminRoutePaths.accessDenied,
        builder: (context, state) => const AccessDeniedScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: AdminRoutePaths.dashboard,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          ..._placeholders,
        ],
      ),
    ],
  );
}

List<RouteBase> get _placeholders => [
      for (final entry in _placeholderRoutes.entries)
        GoRoute(
          path: entry.key,
          pageBuilder: (context, state) => NoTransitionPage(
            child: ModulePlaceholderScreen(title: entry.value),
          ),
        ),
    ];

const _placeholderRoutes = <String, String>{
  AdminRoutePaths.users: 'Users',
  AdminRoutePaths.teams: 'Teams',
  AdminRoutePaths.players: 'Players',
  AdminRoutePaths.matches: 'Matches',
  AdminRoutePaths.tournaments: 'Tournaments',
  AdminRoutePaths.community: 'Community',
  AdminRoutePaths.discover: 'Discover',
  AdminRoutePaths.broadcast: 'Broadcast',
  AdminRoutePaths.notifications: 'Notifications',
  AdminRoutePaths.analytics: 'Analytics',
  AdminRoutePaths.reports: 'Reports',
  AdminRoutePaths.settings: 'Settings',
};
