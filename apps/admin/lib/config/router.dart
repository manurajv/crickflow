import 'package:crickflow_admin_core/crickflow_admin_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

GoRouter createOrgAdminRouter(Ref ref) {
  final refresh = GoRouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

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
      GoRoute(
        path: AdminRoutePaths.forbidden,
        builder: (context, state) => const ForbiddenScreen(),
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
          GoRoute(
            path: AdminRoutePaths.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.accountSettings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AccountSettingsScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.users,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UsersScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.tournaments,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TournamentsScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.matches,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MatchesScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.teams,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TeamsScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.players,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlayersScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.grounds,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GroundsScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.broadcast,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BroadcastsScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.community,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ModerationScreen(
                surface: ModerationSurface.community,
                permission: AdminPermission.canModerateCommunity,
              ),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.discover,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ModerationScreen(
                surface: ModerationSurface.discover,
                permission: AdminPermission.canManageDiscover,
              ),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.reports,
            pageBuilder: (context, state) => NoTransitionPage(
              child: ModerationScreen(
                surface: ModerationSurface.queue,
                permissions: const [
                  AdminPermission.canViewReports,
                  AdminPermission.canModerateCommunity,
                  AdminPermission.canManageDiscover,
                ],
              ),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.notifications,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.ads,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdsScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.analytics,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.monitoring,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MonitoringScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.support,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SupportScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.aiOps,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AiOpsScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.security,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SecurityScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
          GoRoute(
            path: AdminRoutePaths.logs,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AuditScreen(),
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

const _placeholderRoutes = <String, String>{};
