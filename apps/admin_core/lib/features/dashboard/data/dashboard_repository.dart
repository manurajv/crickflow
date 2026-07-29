import 'package:flutter/material.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/router/admin_route_paths.dart';
import '../../../core/theme/admin_colors.dart';
import '../models/dashboard_models.dart';

/// Builds dashboard snapshots.
///
/// Today: deterministic placeholders.
/// Later: replace method bodies with Firestore aggregate / query reads.
/// Organization scope must always filter by [organizationId].
class DashboardRepository {
  const DashboardRepository();

  Future<DashboardSnapshot> fetch({
    required AdminAppType appType,
    String? organizationId,
    String? organizationName,
  }) async {
    // Simulate network latency for skeleton UX.
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final scoped = appType == AdminAppType.organizationAdmin;
    final scopeLabel = scoped
        ? (organizationName?.isNotEmpty == true
            ? organizationName!
            : 'Your organization')
        : 'All of CrickFlow';

    return DashboardSnapshot(
      generatedAt: DateTime.now(),
      scopeLabel: scopeLabel,
      isOrganizationScoped: scoped,
      overview: _overview(scoped),
      quickActions: _quickActions(scoped),
      activity: _activity(scoped),
      systemStatus: _systemStatus(scoped),
      platformHealth: _platformHealth(scoped),
      recentMatches: _matches(scoped),
      recentReports: _reports(scoped),
      recentUsers: _users(scoped),
      recentTournaments: _tournaments(scoped),
      analyticsPlaceholders: _analytics(scoped),
    );
  }

  List<OverviewMetric> _overview(bool scoped) {
    String v(String global, String org) => scoped ? org : global;
    return [
      OverviewMetric(
        id: 'users',
        title: 'Users',
        value: v('12,480', '186'),
        growthLabel: '+2.4%',
        growthPositive: true,
        icon: Icons.people_outline,
        accent: AdminColors.primaryBlue,
        sparkline: const [0.3, 0.4, 0.35, 0.5, 0.55, 0.7, 0.8],
      ),
      OverviewMetric(
        id: 'teams',
        title: 'Teams',
        value: v('1,942', '24'),
        growthLabel: '+1.1%',
        growthPositive: true,
        icon: Icons.groups_outlined,
        accent: const Color(0xFF7E57C2),
      ),
      OverviewMetric(
        id: 'players',
        title: 'Players',
        value: v('28,310', '412'),
        growthLabel: '+3.0%',
        growthPositive: true,
        icon: Icons.person_outline,
        accent: const Color(0xFF26A69A),
      ),
      OverviewMetric(
        id: 'matches',
        title: 'Matches',
        value: v('9,874', '138'),
        growthLabel: '+4.2%',
        growthPositive: true,
        icon: Icons.sports_cricket_outlined,
        accent: AdminColors.goldDark,
      ),
      OverviewMetric(
        id: 'live_matches',
        title: 'Live Matches',
        value: v('18', '2'),
        growthLabel: '+3',
        growthPositive: true,
        icon: Icons.sensors,
        accent: const Color(0xFFE53935),
        sparkline: const [0.2, 0.3, 0.5, 0.4, 0.6, 0.7, 0.9],
      ),
      OverviewMetric(
        id: 'streams',
        title: 'Active Streams',
        value: v('11', '1'),
        growthLabel: '+2',
        growthPositive: true,
        icon: Icons.live_tv_outlined,
        accent: const Color(0xFFEF5350),
      ),
      OverviewMetric(
        id: 'tournaments',
        title: 'Tournaments',
        value: v('640', '7'),
        growthLabel: '+0.8%',
        growthPositive: true,
        icon: Icons.emoji_events_outlined,
        accent: const Color(0xFFFB8C00),
      ),
      OverviewMetric(
        id: 'grounds',
        title: 'Grounds',
        value: v('1,120', '9'),
        growthLabel: '+0.3%',
        growthPositive: true,
        icon: Icons.stadium_outlined,
        accent: const Color(0xFF5C6BC0),
      ),
      OverviewMetric(
        id: 'community',
        title: 'Community Posts',
        value: v('4,210', '56'),
        growthLabel: '+5.1%',
        growthPositive: true,
        icon: Icons.forum_outlined,
        accent: const Color(0xFF00897B),
      ),
      OverviewMetric(
        id: 'discover',
        title: 'Discover Posts',
        value: v('890', '12'),
        growthLabel: '+1.4%',
        growthPositive: true,
        icon: Icons.explore_outlined,
        accent: const Color(0xFF42A5F5),
      ),
      OverviewMetric(
        id: 'reports',
        title: 'Reports',
        value: v('47', '3'),
        growthLabel: '-12%',
        growthPositive: false,
        icon: Icons.flag_outlined,
        accent: const Color(0xFFFF7043),
      ),
      OverviewMetric(
        id: 'notifications',
        title: 'Notifications Sent',
        value: v('22.4k', '840'),
        growthLabel: '+6.0%',
        growthPositive: true,
        icon: Icons.notifications_outlined,
        accent: AdminColors.primaryBlueLight,
      ),
    ];
  }

  List<QuickActionItem> _quickActions(bool scoped) {
    return [
      const QuickActionItem(
        id: 'tournament',
        label: 'Create Tournament',
        icon: Icons.emoji_events_outlined,
        route: AdminRoutePaths.tournaments,
        accent: Color(0xFFFB8C00),
      ),
      const QuickActionItem(
        id: 'notification',
        label: 'Send Notification',
        icon: Icons.campaign_outlined,
        route: AdminRoutePaths.notifications,
        accent: AdminColors.primaryBlue,
      ),
      const QuickActionItem(
        id: 'users',
        label: 'Manage Users',
        icon: Icons.manage_accounts_outlined,
        route: AdminRoutePaths.users,
        accent: Color(0xFF7E57C2),
      ),
      const QuickActionItem(
        id: 'reports',
        label: 'Reports',
        icon: Icons.flag_outlined,
        route: AdminRoutePaths.reports,
        accent: Color(0xFFE53935),
      ),
      if (!scoped)
        const QuickActionItem(
          id: 'ads',
          label: 'Advertisements',
          icon: Icons.ads_click_outlined,
          route: AdminRoutePaths.ads,
          accent: Color(0xFF00897B),
        ),
      const QuickActionItem(
        id: 'community',
        label: 'Community',
        icon: Icons.forum_outlined,
        route: AdminRoutePaths.community,
        accent: Color(0xFF26A69A),
      ),
      const QuickActionItem(
        id: 'broadcast',
        label: 'Broadcasts',
        icon: Icons.live_tv_outlined,
        route: AdminRoutePaths.broadcast,
        accent: Color(0xFFEF5350),
      ),
    ];
  }

  List<ActivityItem> _activity(bool scoped) {
    final now = DateTime.now();
    final prefix = scoped ? 'Org · ' : '';
    return [
      ActivityItem(
        id: 'a1',
        kind: ActivityKind.userRegistered,
        title: '${prefix}New User Registered',
        subtitle: scoped ? 'Kasun Perera joined your org' : 'Nimali Silva joined CrickFlow',
        occurredAt: now.subtract(const Duration(minutes: 4)),
      ),
      ActivityItem(
        id: 'a2',
        kind: ActivityKind.tournamentCreated,
        title: '${prefix}Tournament Created',
        subtitle: 'Colombo Night Cup 2026',
        occurredAt: now.subtract(const Duration(minutes: 18)),
      ),
      ActivityItem(
        id: 'a3',
        kind: ActivityKind.matchStarted,
        title: '${prefix}Match Started',
        subtitle: 'Titans vs Strikers · Live',
        occurredAt: now.subtract(const Duration(minutes: 32)),
      ),
      ActivityItem(
        id: 'a4',
        kind: ActivityKind.streamStarted,
        title: '${prefix}Live Stream Started',
        subtitle: 'Ground A camera 1',
        occurredAt: now.subtract(const Duration(minutes: 35)),
      ),
      ActivityItem(
        id: 'a5',
        kind: ActivityKind.matchCompleted,
        title: '${prefix}Match Completed',
        subtitle: 'Riverside XI won by 24 runs',
        occurredAt: now.subtract(const Duration(hours: 1, minutes: 10)),
      ),
      ActivityItem(
        id: 'a6',
        kind: ActivityKind.communityPost,
        title: '${prefix}Community Post Created',
        subtitle: 'Looking for an umpire · Galle',
        occurredAt: now.subtract(const Duration(hours: 2)),
      ),
      ActivityItem(
        id: 'a7',
        kind: ActivityKind.reportSubmitted,
        title: '${prefix}Report Submitted',
        subtitle: 'Spam content flagged',
        occurredAt: now.subtract(const Duration(hours: 3)),
      ),
      ActivityItem(
        id: 'a8',
        kind: ActivityKind.streamEnded,
        title: '${prefix}Live Stream Ended',
        subtitle: 'Average viewers 214',
        occurredAt: now.subtract(const Duration(hours: 4)),
      ),
    ];
  }

  List<SystemStatusItem> _systemStatus(bool scoped) {
    // Org admins see a simplified “services affecting your org” strip.
    final items = <SystemStatusItem>[
      const SystemStatusItem(
        id: 'firestore',
        name: 'Firestore',
        status: ServiceHealth.healthy,
        detail: 'Operational',
      ),
      const SystemStatusItem(
        id: 'auth',
        name: 'Authentication',
        status: ServiceHealth.healthy,
        detail: 'Operational',
      ),
      const SystemStatusItem(
        id: 'storage',
        name: 'Storage',
        status: ServiceHealth.healthy,
        detail: 'Operational',
      ),
      const SystemStatusItem(
        id: 'functions',
        name: 'Cloud Functions',
        status: ServiceHealth.healthy,
        detail: 'Operational',
      ),
      if (!scoped)
        const SystemStatusItem(
          id: 'hosting',
          name: 'Hosting',
          status: ServiceHealth.healthy,
          detail: 'Operational',
        ),
      const SystemStatusItem(
        id: 'fcm',
        name: 'FCM',
        status: ServiceHealth.warning,
        detail: 'Elevated latency (placeholder)',
      ),
      if (!scoped)
        const SystemStatusItem(
          id: 'analytics',
          name: 'Analytics',
          status: ServiceHealth.healthy,
          detail: 'Operational',
        ),
      if (!scoped)
        const SystemStatusItem(
          id: 'remote_config',
          name: 'Remote Config',
          status: ServiceHealth.healthy,
          detail: 'Operational',
        ),
    ];
    return items;
  }

  List<HealthMetric> _platformHealth(bool scoped) {
    String v(String global, String org) => scoped ? org : global;
    return [
      HealthMetric(
        id: 'active_today',
        label: scoped ? 'Active members today' : 'Active users today',
        value: v('3,842', '64'),
        icon: Icons.person_search_outlined,
      ),
      HealthMetric(
        id: 'concurrent_live',
        label: 'Concurrent live matches',
        value: v('18', '2'),
        icon: Icons.sports_cricket_outlined,
      ),
      HealthMetric(
        id: 'streams',
        label: 'Streams running',
        value: v('11', '1'),
        icon: Icons.videocam_outlined,
      ),
      HealthMetric(
        id: 'server_time',
        label: 'Server time',
        value: '${_formatTime(DateTime.now().toUtc())} UTC',
        icon: Icons.schedule_outlined,
      ),
      HealthMetric(
        id: 'reads',
        label: 'Database reads',
        value: v('—', '—'),
        icon: Icons.download_outlined,
      ),
      HealthMetric(
        id: 'writes',
        label: 'Database writes',
        value: v('—', '—'),
        icon: Icons.upload_outlined,
      ),
      HealthMetric(
        id: 'storage',
        label: 'Storage usage',
        value: v('—', '—'),
        icon: Icons.cloud_outlined,
      ),
      HealthMetric(
        id: 'bandwidth',
        label: 'Bandwidth',
        value: v('—', '—'),
        icon: Icons.speed_outlined,
      ),
    ];
  }

  List<RecentMatchItem> _matches(bool scoped) => [
        RecentMatchItem(
          id: 'm1',
          title: scoped ? 'Org League · Match 12' : 'Sunday Super League',
          teamA: 'Titans',
          teamB: 'Strikers',
          status: 'Live',
          score: '148/4 (16.2)',
          isLive: true,
        ),
        const RecentMatchItem(
          id: 'm2',
          title: 'Corporate Cup Final',
          teamA: 'Aces',
          teamB: 'Blazers',
          status: 'Completed',
          score: '172/7 · 168/9',
          isLive: false,
        ),
        const RecentMatchItem(
          id: 'm3',
          title: 'Indoor Challenge',
          teamA: 'Falcons',
          teamB: 'Riders',
          status: 'Upcoming',
          score: '—',
          isLive: false,
        ),
      ];

  List<RecentReportItem> _reports(bool scoped) => [
        RecentReportItem(
          id: 'r1',
          userName: scoped ? 'Member #4821' : 'guest_user_92',
          reason: 'Spam in community',
          status: 'Open',
        ),
        const RecentReportItem(
          id: 'r2',
          userName: 'team_captain_lk',
          reason: 'Inappropriate content',
          status: 'Reviewing',
        ),
        const RecentReportItem(
          id: 'r3',
          userName: 'scorer_01',
          reason: 'Harassment',
          status: 'Resolved',
        ),
      ];

  List<RecentUserItem> _users(bool scoped) => [
        RecentUserItem(
          id: 'u1',
          name: 'Kasun Perera',
          country: 'Sri Lanka',
          joinedLabel: '2h ago',
          status: scoped ? 'Member' : 'Active',
        ),
        const RecentUserItem(
          id: 'u2',
          name: 'Ayesha Fernando',
          country: 'Sri Lanka',
          joinedLabel: '5h ago',
          status: 'Active',
        ),
        const RecentUserItem(
          id: 'u3',
          name: 'Rahul Mehta',
          country: 'India',
          joinedLabel: 'Yesterday',
          status: 'Pending',
        ),
      ];

  List<RecentTournamentItem> _tournaments(bool scoped) => [
        RecentTournamentItem(
          id: 't1',
          title: scoped ? 'Inter-Faculty Cricket 2026' : 'Colombo Night Cup',
          organizer: scoped ? 'Your organization' : 'CF Events',
          status: 'Open',
        ),
        const RecentTournamentItem(
          id: 't2',
          title: 'Beach Bash T10',
          organizer: 'Coastal Cricket',
          status: 'Ongoing',
        ),
        const RecentTournamentItem(
          id: 't3',
          title: 'School League Phase 2',
          organizer: 'District Assoc.',
          status: 'Draft',
        ),
      ];

  List<AnalyticsPlaceholderItem> _analytics(bool scoped) => [
        AnalyticsPlaceholderItem(
          id: 'user_growth',
          title: 'User Growth',
          subtitle: scoped
              ? 'Member growth for your organization'
              : 'Platform-wide registrations over time',
        ),
        AnalyticsPlaceholderItem(
          id: 'match_growth',
          title: 'Match Growth',
          subtitle: scoped
              ? 'Matches created in your organization'
              : 'Matches created across CrickFlow',
        ),
        const AnalyticsPlaceholderItem(
          id: 'streaming',
          title: 'Streaming Activity',
          subtitle: 'Concurrent viewers and stream minutes',
        ),
        const AnalyticsPlaceholderItem(
          id: 'community',
          title: 'Community Activity',
          subtitle: 'Posts, comments, and engagement',
        ),
        if (!scoped)
          const AnalyticsPlaceholderItem(
            id: 'revenue',
            title: 'Revenue',
            subtitle: 'Platform monetization overview',
          ),
      ];

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
