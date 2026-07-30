import 'package:crickflow_admin_core/crickflow_admin_core.dart';
import 'package:flutter/material.dart';

/// Super Admin navigation — platform-wide sections.
List<AdminNavSection> buildSuperAdminNav() {
  return [
    AdminNavSection(
      id: NavSectionId.dashboard,
      items: [
        AdminNavItem(
          id: 'dashboard',
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          route: AdminRoutePaths.dashboard,
          permission: AdminPermission.canViewDashboard,
        ),
      ],
    ),
    AdminNavSection(
      id: NavSectionId.management,
      items: [
        AdminNavItem(
          id: 'users',
          label: 'Users',
          icon: Icons.people_outline,
          route: AdminRoutePaths.users,
          permission: AdminPermission.canManageUsers,
        ),
        AdminNavItem(
          id: 'organizations',
          label: 'Organizations',
          icon: Icons.apartment_outlined,
          route: AdminRoutePaths.organizations,
          permission: AdminPermission.canManageOrganizations,
        ),
        AdminNavItem(
          id: 'teams',
          label: 'Teams',
          icon: Icons.groups_outlined,
          route: AdminRoutePaths.teams,
          permission: AdminPermission.canManageTeams,
        ),
        AdminNavItem(
          id: 'players',
          label: 'Players',
          icon: Icons.sports_cricket_outlined,
          route: AdminRoutePaths.players,
          permission: AdminPermission.canManagePlayers,
        ),
        AdminNavItem(
          id: 'grounds',
          label: 'Grounds',
          icon: Icons.stadium_outlined,
          route: AdminRoutePaths.grounds,
          permission: AdminPermission.canManageGrounds,
        ),
        AdminNavItem(
          id: 'matches',
          label: 'Matches',
          icon: Icons.sports_outlined,
          route: AdminRoutePaths.matches,
          permission: AdminPermission.canManageMatches,
        ),
        AdminNavItem(
          id: 'tournaments',
          label: 'Tournaments',
          icon: Icons.emoji_events_outlined,
          route: AdminRoutePaths.tournaments,
          permission: AdminPermission.canManageTournaments,
        ),
        AdminNavItem(
          id: 'broadcast',
          label: 'Broadcasts',
          icon: Icons.live_tv_outlined,
          route: AdminRoutePaths.broadcast,
          permission: AdminPermission.canManageBroadcast,
        ),
      ],
    ),
    AdminNavSection(
      id: NavSectionId.community,
      items: [
        AdminNavItem(
          id: 'community',
          label: 'Community',
          icon: Icons.forum_outlined,
          route: AdminRoutePaths.community,
          permission: AdminPermission.canModerateCommunity,
        ),
        AdminNavItem(
          id: 'discover',
          label: 'Discover',
          icon: Icons.explore_outlined,
          route: AdminRoutePaths.discover,
          permission: AdminPermission.canManageDiscover,
        ),
        AdminNavItem(
          id: 'reports',
          label: 'Reports',
          icon: Icons.flag_outlined,
          route: AdminRoutePaths.reports,
          permission: AdminPermission.canViewReports,
        ),
      ],
    ),
    AdminNavSection(
      id: NavSectionId.platform,
      items: [
        AdminNavItem(
          id: 'ads',
          label: 'Advertisements',
          icon: Icons.campaign_outlined,
          route: AdminRoutePaths.ads,
          permission: AdminPermission.canManageAds,
        ),
        AdminNavItem(
          id: 'notifications',
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          route: AdminRoutePaths.notifications,
          permission: AdminPermission.canSendNotifications,
        ),
        AdminNavItem(
          id: 'cms',
          label: 'CMS',
          icon: Icons.article_outlined,
          route: AdminRoutePaths.cms,
          permission: AdminPermission.canManageCms,
        ),
        AdminNavItem(
          id: 'analytics',
          label: 'Analytics',
          icon: Icons.insights_outlined,
          route: AdminRoutePaths.analytics,
          permission: AdminPermission.canViewAnalytics,
        ),
        AdminNavItem(
          id: 'revenue',
          label: 'Revenue',
          icon: Icons.payments_outlined,
          route: AdminRoutePaths.revenue,
          permission: AdminPermission.canAccessGlobalData,
        ),
      ],
    ),
    AdminNavSection(
      id: NavSectionId.system,
      items: [
        AdminNavItem(
          id: 'monitoring',
          label: 'System Monitoring',
          icon: Icons.monitor_heart_outlined,
          route: AdminRoutePaths.monitoring,
          permission: AdminPermission.canViewSystemHealth,
        ),
        AdminNavItem(
          id: 'support',
          label: 'Support Center',
          icon: Icons.support_agent_outlined,
          route: AdminRoutePaths.support,
          permission: AdminPermission.canManageSupport,
        ),
        AdminNavItem(
          id: 'ai-ops',
          label: 'AI Operations',
          icon: Icons.auto_awesome_outlined,
          route: AdminRoutePaths.aiOps,
          permission: AdminPermission.canManageAiOps,
        ),
        AdminNavItem(
          id: 'security',
          label: 'Security Center',
          icon: Icons.shield_outlined,
          route: AdminRoutePaths.security,
          permission: AdminPermission.canManageSecurity,
        ),
        AdminNavItem(
          id: 'devops',
          label: 'DevOps & Releases',
          icon: Icons.rocket_launch_outlined,
          route: AdminRoutePaths.devops,
          permission: AdminPermission.canManageDeployments,
        ),
        AdminNavItem(
          id: 'continuity',
          label: 'Continuity & DR',
          icon: Icons.backup_outlined,
          route: AdminRoutePaths.continuity,
          permission: AdminPermission.canManageContinuity,
        ),
        AdminNavItem(
          id: 'logs',
          label: 'Audit Logs',
          icon: Icons.history_outlined,
          route: AdminRoutePaths.logs,
          permission: AdminPermission.canViewLogs,
        ),
        AdminNavItem(
          id: 'docs',
          label: 'Developer Docs',
          icon: Icons.menu_book_outlined,
          route: AdminRoutePaths.docs,
        ),
      ],
    ),
    AdminNavSection(
      id: NavSectionId.settings,
      items: [
        AdminNavItem(
          id: 'settings',
          label: 'Settings',
          icon: Icons.settings_outlined,
          route: AdminRoutePaths.settings,
          permission: AdminPermission.canManageSettings,
        ),
      ],
    ),
  ];
}
