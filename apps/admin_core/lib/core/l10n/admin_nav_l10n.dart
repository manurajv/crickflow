import '../../l10n/generated/admin_localizations.dart';
import '../../models/nav_models.dart';

/// Resolves sidebar / nav labels from localization (stable [AdminNavItem.id]).
///
/// Falls back to the English [AdminNavItem.label] when no mapping exists —
/// modules can migrate incrementally without breaking the shell.
abstract final class AdminNavL10n {
  static String section(AdminLocalizations l10n, NavSectionId id) =>
      switch (id) {
        NavSectionId.dashboard => l10n.navSectionDashboard,
        NavSectionId.management => l10n.navSectionManagement,
        NavSectionId.community => l10n.navSectionCommunity,
        NavSectionId.platform => l10n.navSectionPlatform,
        NavSectionId.system => l10n.navSectionSystem,
        NavSectionId.settings => l10n.navSectionSettings,
      };

  static String item(AdminLocalizations l10n, AdminNavItem item) {
    return switch (item.id) {
      'dashboard' => l10n.navDashboard,
      'users' => l10n.navUsers,
      'organizations' => l10n.navOrganizations,
      'teams' => l10n.navTeams,
      'players' => l10n.navPlayers,
      'grounds' => l10n.navGrounds,
      'matches' => l10n.navMatches,
      'tournaments' => l10n.navTournaments,
      'broadcast' || 'broadcasts' => l10n.navBroadcasts,
      'community' => l10n.navCommunity,
      'discover' => l10n.navDiscover,
      'reports' || 'moderation' => l10n.navReports,
      'ads' => l10n.navAds,
      'notifications' => l10n.navNotifications,
      'support' => l10n.navSupport,
      'analytics' => l10n.navAnalytics,
      'cms' => l10n.navCms,
      'logs' || 'audit' => l10n.navAudit,
      'security' => l10n.navSecurity,
      'aiOps' || 'ai-ops' || 'ai' => l10n.navAiOps,
      'monitoring' => l10n.navMonitoring,
      'devops' => l10n.navDevOps,
      'continuity' => l10n.navContinuity,
      'settings' => l10n.navSettings,
      'revenue' => l10n.navRevenue,
      'docs' => 'Developer Docs',
      _ => item.label,
    };
  }
}
