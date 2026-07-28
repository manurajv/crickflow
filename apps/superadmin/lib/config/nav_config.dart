import 'package:crickflow_admin_core/crickflow_admin_core.dart';
import 'package:flutter/material.dart';

/// Super Admin navigation — platform-wide sections.
List<AdminNavSection> buildSuperAdminNav() {
  return const [
    AdminNavSection(
      id: NavSectionId.dashboard,
      items: [
        AdminNavItem(
          id: 'dashboard',
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          route: AdminRoutePaths.dashboard,
          permission: AdminPermission.canViewDashboard,
          enabled: true,
        ),
      ],
    ),
    AdminNavSection(
      id: NavSectionId.management,
      items: [
        AdminNavItem(
          id: 'organizations',
          label: 'Organizations',
          icon: Icons.apartment_outlined,
          route: AdminRoutePaths.organizations,
          permission: AdminPermission.canManageOrganizations,
        ),
        AdminNavItem(
          id: 'users',
          label: 'Users',
          icon: Icons.people_outline,
          route: AdminRoutePaths.users,
          permission: AdminPermission.canManageUsers,
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
          icon: Icons.person_outline,
          route: AdminRoutePaths.players,
          permission: AdminPermission.canManagePlayers,
        ),
        AdminNavItem(
          id: 'matches',
          label: 'Matches',
          icon: Icons.sports_cricket_outlined,
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
      ],
    ),
    AdminNavSection(
      id: NavSectionId.platform,
      items: [
        AdminNavItem(
          id: 'broadcast',
          label: 'Broadcast',
          icon: Icons.live_tv_outlined,
          route: AdminRoutePaths.broadcast,
          permission: AdminPermission.canManageBroadcast,
        ),
        AdminNavItem(
          id: 'ads',
          label: 'Ads',
          icon: Icons.campaign_outlined,
          route: AdminRoutePaths.ads,
          permission: AdminPermission.canManageAds,
        ),
        AdminNavItem(
          id: 'cms',
          label: 'CMS',
          icon: Icons.article_outlined,
          route: AdminRoutePaths.cms,
          permission: AdminPermission.canManageCms,
        ),
        AdminNavItem(
          id: 'notifications',
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          route: AdminRoutePaths.notifications,
          permission: AdminPermission.canSendNotifications,
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
          id: 'analytics',
          label: 'Analytics',
          icon: Icons.insights_outlined,
          route: AdminRoutePaths.analytics,
          permission: AdminPermission.canViewAnalytics,
        ),
        AdminNavItem(
          id: 'reports',
          label: 'Reports',
          icon: Icons.flag_outlined,
          route: AdminRoutePaths.reports,
          permission: AdminPermission.canViewReports,
        ),
        AdminNavItem(
          id: 'logs',
          label: 'Logs',
          icon: Icons.receipt_long_outlined,
          route: AdminRoutePaths.logs,
          permission: AdminPermission.canViewLogs,
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
