import 'admin_role.dart';

/// Fine-grained permissions checked before loading admin pages.
///
/// Add new values here; map them in [AdminPermissionCatalog] for each role.
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
  canViewDashboard;

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
      };
}

/// Default permission sets per [AdminRole]. Easy to extend.
abstract final class AdminPermissionCatalog {
  static const Set<AdminPermission> _all = {...AdminPermission.values};

  static Set<AdminPermission> forRole(AdminRole role) => switch (role) {
        AdminRole.superAdmin => Set.unmodifiable(_all),
        AdminRole.admin => {
            AdminPermission.canViewDashboard,
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
            AdminPermission.canModerateCommunity,
            AdminPermission.canViewReports,
          },
        AdminRole.tournamentAdmin => {
            AdminPermission.canViewDashboard,
            AdminPermission.canManageMatches,
            AdminPermission.canManageTeams,
            AdminPermission.canManagePlayers,
            AdminPermission.canManageTournaments,
            AdminPermission.canViewReports,
          },
        AdminRole.support => {
            AdminPermission.canViewDashboard,
            AdminPermission.canViewReports,
            AdminPermission.canViewLogs,
            AdminPermission.canViewAnalytics,
          },
      };

  /// Merges role defaults with optional document-level grants/denies.
  static Set<AdminPermission> resolve({
    required AdminRole role,
    List<String>? grants,
    List<String>? denies,
  }) {
    final set = Set<AdminPermission>.from(forRole(role));
    for (final g in grants ?? const []) {
      final p = _parse(g);
      if (p != null) set.add(p);
    }
    for (final d in denies ?? const []) {
      final p = _parse(d);
      if (p != null) set.remove(p);
    }
    return Set.unmodifiable(set);
  }

  static AdminPermission? _parse(String raw) {
    for (final p in AdminPermission.values) {
      if (p.name == raw) return p;
    }
    return null;
  }
}
