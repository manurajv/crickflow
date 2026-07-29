import 'admin_role.dart';

/// Fine-grained permissions checked before loading admin pages.
///
/// Wire names match enum names and map keys in `admin_roles.permissions`.
/// Add new values here; seed / update the matching `admin_roles` document.
enum AdminPermission {
  canManageUsers,
  canManageMatches,
  canManageTeams,
  canManagePlayers,
  canManageTournaments,
  canSendNotifications,
  canManageAds,
  canModerateCommunity,
  canManageBroadcast,
  canViewAnalytics,
  canManageCms,
  canViewReports,
  canManageSettings,
  canViewLogs,
  canManageOrganizations,
  canAccessGlobalData,
  canManageDiscover,
  canViewDashboard,
  canViewProfile,
  canManageAccount;

  String get label => switch (this) {
        AdminPermission.canManageUsers => 'Manage users',
        AdminPermission.canManageMatches => 'Manage matches',
        AdminPermission.canManageTeams => 'Manage teams',
        AdminPermission.canManagePlayers => 'Manage players',
        AdminPermission.canManageTournaments => 'Manage tournaments',
        AdminPermission.canSendNotifications => 'Send notifications',
        AdminPermission.canManageAds => 'Manage ads',
        AdminPermission.canModerateCommunity => 'Moderate community',
        AdminPermission.canManageBroadcast => 'Manage broadcast',
        AdminPermission.canViewAnalytics => 'View analytics',
        AdminPermission.canManageCms => 'Manage CMS',
        AdminPermission.canViewReports => 'View reports',
        AdminPermission.canManageSettings => 'Manage settings',
        AdminPermission.canViewLogs => 'View logs',
        AdminPermission.canManageOrganizations => 'Manage organizations',
        AdminPermission.canAccessGlobalData => 'Access global data',
        AdminPermission.canManageDiscover => 'Manage discover',
        AdminPermission.canViewDashboard => 'View dashboard',
        AdminPermission.canViewProfile => 'View profile',
        AdminPermission.canManageAccount => 'Manage account',
      };

  static AdminPermission? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Alias used in product specs
    if (raw == 'canManageBroadcasts') return AdminPermission.canManageBroadcast;
    for (final p in AdminPermission.values) {
      if (p.name == raw) return p;
    }
    return null;
  }
}

/// Built-in permission maps used when Firestore `admin_roles` is missing.
///
/// Production should store these in `admin_roles/{roleId}` so permission
/// changes do not require a client release.
abstract final class DefaultAdminRolePermissions {
  static const Set<AdminPermission> all = {...AdminPermission.values};

  static Set<AdminPermission> forRole(AdminRole role) => switch (role) {
        AdminRole.superAdmin => Set.unmodifiable(all),
        AdminRole.admin => {
            AdminPermission.canViewDashboard,
            AdminPermission.canViewProfile,
            AdminPermission.canManageAccount,
            AdminPermission.canManageUsers,
            AdminPermission.canManageMatches,
            AdminPermission.canManageTeams,
            AdminPermission.canManagePlayers,
            AdminPermission.canManageTournaments,
            AdminPermission.canSendNotifications,
            AdminPermission.canModerateCommunity,
            AdminPermission.canManageBroadcast,
            AdminPermission.canViewAnalytics,
            AdminPermission.canViewReports,
            AdminPermission.canManageSettings,
            AdminPermission.canManageDiscover,
          },
        AdminRole.moderator => {
            AdminPermission.canViewDashboard,
            AdminPermission.canViewProfile,
            AdminPermission.canManageAccount,
            AdminPermission.canModerateCommunity,
            AdminPermission.canViewReports,
          },
        AdminRole.tournamentAdmin => {
            AdminPermission.canViewDashboard,
            AdminPermission.canViewProfile,
            AdminPermission.canManageAccount,
            AdminPermission.canManageMatches,
            AdminPermission.canManageTeams,
            AdminPermission.canManagePlayers,
            AdminPermission.canManageTournaments,
            AdminPermission.canViewReports,
          },
        AdminRole.support => {
            AdminPermission.canViewDashboard,
            AdminPermission.canViewProfile,
            AdminPermission.canManageAccount,
            AdminPermission.canViewReports,
            AdminPermission.canViewLogs,
            AdminPermission.canViewAnalytics,
          },
        AdminRole.viewer => {
            AdminPermission.canViewProfile,
          },
      };

  static Map<String, bool> asPermissionMap(AdminRole role) {
    final allowed = forRole(role);
    return {
      for (final p in AdminPermission.values) p.name: allowed.contains(p),
    };
  }
}

/// Resolves effective permissions from a role map + optional user overrides.
abstract final class AdminPermissionResolver {
  static Set<AdminPermission> resolve({
    required Map<String, bool> rolePermissions,
    Map<String, bool> overrides = const {},
  }) {
    final merged = Map<String, bool>.from(rolePermissions)..addAll(overrides);
    final set = <AdminPermission>{};
    for (final entry in merged.entries) {
      if (!entry.value) continue;
      final p = AdminPermission.tryParse(entry.key);
      if (p != null) set.add(p);
    }
    return Set.unmodifiable(set);
  }
}
