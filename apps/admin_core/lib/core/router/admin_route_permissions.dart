import '../../models/admin_permission.dart';
import 'admin_route_paths.dart';

/// Declares which permission each admin route requires.
///
/// Add entries here as modules ship. `null` means authenticated panel access
/// only (still blocked by session role guard).
///
/// Prefer [isAllowed] over [requiredFor] when checking access — some routes
/// accept any of several permissions (`anyOf`).
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
    AdminRoutePaths.devops: AdminPermission.canManageDeployments,
    AdminRoutePaths.continuity: AdminPermission.canManageContinuity,
    // Authenticated Super Admin panel access (no extra permission).
    AdminRoutePaths.docs: null,
    // Reports uses [anyOf] — kept here only for documentation / tooling.
    AdminRoutePaths.reports: AdminPermission.canViewReports,
    AdminRoutePaths.logs: AdminPermission.canViewLogs,
    AdminRoutePaths.organizations: AdminPermission.canManageOrganizations,
    AdminRoutePaths.settings: AdminPermission.canManageSettings,
    AdminRoutePaths.profile: AdminPermission.canViewProfile,
    AdminRoutePaths.accountSettings: AdminPermission.canManageAccount,
  };

  /// Routes that allow access when the session has **any** listed permission.
  static const Map<String, List<AdminPermission>> _anyOf = {
    AdminRoutePaths.reports: [
      AdminPermission.canViewReports,
      AdminPermission.canModerateCommunity,
      AdminPermission.canManageDiscover,
    ],
  };

  static AdminPermission? requiredFor(String location) {
    final resolved = _resolvePath(location);
    if (resolved == null) return null;
    return _map[resolved];
  }

  /// True when the session may open [location] (single or any-of).
  static bool isAllowed(
    String location,
    bool Function(AdminPermission permission) hasPermission,
  ) {
    final resolved = _resolvePath(location);
    if (resolved == null) return true;

    final anyOf = _anyOf[resolved];
    if (anyOf != null) {
      return anyOf.any(hasPermission);
    }

    final required = _map[resolved];
    if (required == null) return true;
    return hasPermission(required);
  }

  static String? _resolvePath(String location) {
    if (_map.containsKey(location) || _anyOf.containsKey(location)) {
      return location;
    }
    String? best;
    for (final path in {..._map.keys, ..._anyOf.keys}) {
      if (path == AdminRoutePaths.dashboard) continue;
      if (location == path || location.startsWith('$path/')) {
        if (best == null || path.length > best.length) best = path;
      }
    }
    return best;
  }
}
