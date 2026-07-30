import '../../models/admin_permission.dart';
import 'admin_route_paths.dart';

/// Declares which permission each admin route requires.
///
/// Add entries here as modules ship. `null` means authenticated panel access
/// only (still blocked by session role guard).
abstract final class AdminRoutePermissions {
  static const Map<String, AdminPermission?> _map = {
    AdminRoutePaths.dashboard: AdminPermission.canViewDashboard,
    AdminRoutePaths.users: AdminPermission.canManageUsers,
    AdminRoutePaths.teams: AdminPermission.canManageTeams,
    AdminRoutePaths.players: AdminPermission.canManagePlayers,
    AdminRoutePaths.matches: AdminPermission.canManageMatches,
    AdminRoutePaths.tournaments: AdminPermission.canManageTournaments,
    AdminRoutePaths.grounds: AdminPermission.canManageGrounds,
    AdminRoutePaths.community: AdminPermission.canModerateCommunity,
    AdminRoutePaths.discover: AdminPermission.canManageDiscover,
    AdminRoutePaths.broadcast: AdminPermission.canManageBroadcast,
    AdminRoutePaths.ads: AdminPermission.canManageAds,
    AdminRoutePaths.cms: AdminPermission.canManageCms,
    AdminRoutePaths.notifications: AdminPermission.canSendNotifications,
    AdminRoutePaths.revenue: AdminPermission.canAccessGlobalData,
    AdminRoutePaths.analytics: AdminPermission.canViewAnalytics,
    AdminRoutePaths.monitoring: AdminPermission.canViewSystemHealth,
    AdminRoutePaths.support: AdminPermission.canManageSupport,
    AdminRoutePaths.aiOps: AdminPermission.canManageAiOps,
    AdminRoutePaths.security: AdminPermission.canManageSecurity,
    AdminRoutePaths.reports: AdminPermission.canViewReports,
    AdminRoutePaths.logs: AdminPermission.canViewLogs,
    AdminRoutePaths.organizations: AdminPermission.canManageOrganizations,
    AdminRoutePaths.settings: AdminPermission.canManageSettings,
    AdminRoutePaths.profile: AdminPermission.canViewProfile,
    AdminRoutePaths.accountSettings: AdminPermission.canManageAccount,
  };

  static AdminPermission? requiredFor(String location) {
    if (_map.containsKey(location)) return _map[location];
    // Longest-prefix match for nested routes later (`/users/:id`, …).
    String? best;
    for (final path in _map.keys) {
      if (path == AdminRoutePaths.dashboard) continue;
      if (location == path || location.startsWith('$path/')) {
        if (best == null || path.length > best.length) best = path;
      }
    }
    return best == null ? null : _map[best];
  }
}
