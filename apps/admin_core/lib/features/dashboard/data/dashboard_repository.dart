import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../core/router/admin_route_paths.dart';
import '../../../core/theme/admin_colors.dart';
import '../models/dashboard_models.dart';
import 'dashboard_metrics.dart';

/// Builds dashboard snapshots from live Firestore [count] queries and
/// capped recent-document reads. Never returns hardcoded sample rows.
class DashboardRepository {
  DashboardRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const _recentLimit = 8;

  Future<DashboardSnapshot> fetch({
    required AdminAppType appType,
    String? organizationId,
    String? organizationName,
  }) async {
    final scoped = organizationId != null && organizationId.isNotEmpty;
    final scopeLabel = scoped
        ? (organizationName?.trim().isNotEmpty == true
            ? organizationName!.trim()
            : 'Organization')
        : 'All of CrickFlow';

    final todayStart = DateTime.now().toUtc();
    final today = DateTime.utc(todayStart.year, todayStart.month, todayStart.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final todayTs = Timestamp.fromDate(today);
    final weekTs = Timestamp.fromDate(weekAgo);

    var firestoreOk = true;
    Future<int> count(Query<Map<String, dynamic>> q) async {
      try {
        final agg = await q.count().get();
        return agg.count ?? 0;
      } catch (_) {
        firestoreOk = false;
        try {
          final snap = await q.limit(300).get();
          return snap.docs.length;
        } catch (_) {
          firestoreOk = false;
          return -1;
        }
      }
    }

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> recent(
      Query<Map<String, dynamic>> query, {
      required String orderField,
      int limit = _recentLimit,
    }) async {
      try {
        final snap =
            await query.orderBy(orderField, descending: true).limit(limit).get();
        return snap.docs;
      } on FirebaseException {
        try {
          final snap = await query.limit(limit).get();
          return snap.docs;
        } catch (_) {
          return const [];
        }
      } catch (_) {
        return const [];
      }
    }

    CollectionReference<Map<String, dynamic>> col(String name) =>
        _db.collection(name);

    Query<Map<String, dynamic>> maybeSeries(
      Query<Map<String, dynamic>> q,
    ) {
      if (!scoped) return q;
      return q.where('seriesId', isEqualTo: organizationId);
    }

    final usersQ = col(AdminCollections.users);
    final teamsQ = maybeSeries(col(AdminCollections.teams));
    final playersQ = maybeSeries(col(AdminCollections.players));
    final matchesQ = maybeSeries(col(AdminCollections.matches));
    final tournamentsQ = maybeSeries(col(AdminCollections.tournaments));
    final groundsQ = col(AdminCollections.grounds);
    final communityQ = col(AdminCollections.communityPosts);
    final discoverQ = col(AdminCollections.opportunityPosts);
    final communityReportsQ = col(AdminCollections.communityPostReports);
    final discoverReportsQ = col(AdminCollections.opportunityPostReports);
    final notificationsQ = col(AdminCollections.notifications);
    final seriesQ = col('series');

    final counts = await Future.wait<int>([
      count(usersQ),
      count(teamsQ),
      count(playersQ),
      count(matchesQ),
      count(matchesQ.where('status', isEqualTo: 'live')),
      count(matchesQ.where('status', isEqualTo: 'inningsBreak')),
      count(matchesQ.where('stream.status', isEqualTo: 'live')),
      count(tournamentsQ),
      count(groundsQ),
      count(communityQ),
      count(discoverQ),
      count(communityReportsQ),
      count(discoverReportsQ),
      count(notificationsQ),
      count(seriesQ),
      count(usersQ.where('createdAt', isGreaterThanOrEqualTo: todayTs)),
      count(usersQ.where('createdAt', isGreaterThanOrEqualTo: weekTs)),
      count(matchesQ.where('createdAt', isGreaterThanOrEqualTo: weekTs)),
      count(communityQ.where('createdAt', isGreaterThanOrEqualTo: weekTs)),
    ]);

    final users = counts[0];
    final teams = counts[1];
    final players = counts[2];
    final matches = counts[3];
    final liveMatches = _sumNonNegative([counts[4], counts[5]]);
    final liveStreams = counts[6];
    final tournaments = counts[7];
    final grounds = counts[8];
    final community = counts[9];
    final discover = counts[10];
    final reports = _sumNonNegative([counts[11], counts[12]]);
    final notifications = counts[13];
    final orgs = counts[14];
    final usersToday = counts[15];
    final usersWeek = counts[16];
    final matchesWeek = counts[17];
    final communityWeek = counts[18];

    final recents = await Future.wait([
      recent(col(AdminCollections.matches), orderField: 'createdAt', limit: 6),
      recent(col(AdminCollections.communityPostReports),
          orderField: 'createdAt', limit: 6),
      recent(col(AdminCollections.opportunityPostReports),
          orderField: 'createdAt', limit: 4),
      recent(col(AdminCollections.users), orderField: 'createdAt', limit: 6),
      recent(col(AdminCollections.tournaments), orderField: 'createdAt', limit: 6),
      recent(col(AdminCollections.communityPosts),
          orderField: 'createdAt', limit: 6),
    ]);

    final recentMatchDocs = recents[0];
    final recentCommunityReportDocs = recents[1];
    final recentDiscoverReportDocs = recents[2];
    final recentUserDocs = recents[3];
    final recentTournamentDocs = recents[4];
    final recentPostDocs = recents[5];

    final recentMatches = recentMatchDocs
        .map((d) => recentMatchFromMap(d.id, d.data()))
        .toList();

    final reportDocs = [
      ...recentCommunityReportDocs,
      ...recentDiscoverReportDocs,
    ];
    reportDocs.sort((a, b) {
      final at = parseDashboardDate(a.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bt = parseDashboardDate(b.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    final recentReports = reportDocs
        .take(6)
        .map((d) => recentReportFromMap(d.id, d.data()))
        .toList();

    final now = DateTime.now();
    final recentUsers = recentUserDocs
        .map((d) => recentUserFromMap(d.id, d.data(), now: now))
        .toList();
    final recentTournaments = recentTournamentDocs
        .map((d) => recentTournamentFromMap(d.id, d.data()))
        .toList();

    final activity = <ActivityItem>[
      for (final d in recentUserDocs) ?activityFromUser(d.id, d.data()),
      for (final d in recentMatchDocs) ?activityFromMatch(d.id, d.data()),
      for (final d in recentTournamentDocs)
        ?activityFromTournament(d.id, d.data()),
      for (final d in recentPostDocs) ?activityFromCommunityPost(d.id, d.data()),
      for (final d in reportDocs.take(6)) ?activityFromReport(d.id, d.data()),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return DashboardSnapshot(
      generatedAt: DateTime.now(),
      scopeLabel: scopeLabel,
      isOrganizationScoped: scoped,
      overview: _overview(
        users: users,
        teams: teams,
        players: players,
        matches: matches,
        liveMatches: liveMatches,
        liveStreams: liveStreams,
        tournaments: tournaments,
        grounds: grounds,
        community: community,
        discover: discover,
        reports: reports,
        notifications: notifications,
        orgs: orgs,
      ),
      quickActions: _quickActions(),
      activity: activity.take(12).toList(),
      systemStatus: _systemStatus(
        firestoreOk: firestoreOk,
        signedIn: _auth.currentUser != null,
      ),
      platformHealth: _platformHealth(
        usersToday: usersToday,
        liveMatches: liveMatches,
        liveStreams: liveStreams,
      ),
      recentMatches: recentMatches,
      recentReports: recentReports,
      recentUsers: recentUsers,
      recentTournaments: recentTournaments,
      analyticsPlaceholders: [
        AnalyticsPlaceholderItem(
          id: 'users_week',
          title: 'New users (7 days)',
          subtitle: 'Registrations with createdAt in the last 7 days',
          value: formatDashboardCount(usersWeek),
        ),
        AnalyticsPlaceholderItem(
          id: 'matches_week',
          title: 'New matches (7 days)',
          subtitle: 'Matches created in the last 7 days',
          value: formatDashboardCount(matchesWeek),
        ),
        AnalyticsPlaceholderItem(
          id: 'community_week',
          title: 'Community posts (7 days)',
          subtitle: 'Posts created in the last 7 days',
          value: formatDashboardCount(communityWeek),
        ),
        AnalyticsPlaceholderItem(
          id: 'orgs',
          title: 'Orgs & series',
          subtitle: 'Documents in the mobile series collection',
          value: formatDashboardCount(orgs),
        ),
      ],
    );
  }

  static int _sumNonNegative(List<int> values) {
    if (values.every((v) => v < 0)) return -1;
    return values.fold<int>(0, (s, v) => s + (v < 0 ? 0 : v));
  }

  List<OverviewMetric> _overview({
    required int users,
    required int teams,
    required int players,
    required int matches,
    required int liveMatches,
    required int liveStreams,
    required int tournaments,
    required int grounds,
    required int community,
    required int discover,
    required int reports,
    required int notifications,
    required int orgs,
  }) {
    OverviewMetric tile({
      required String id,
      required String title,
      required int value,
      required IconData icon,
      required Color accent,
      String growthLabel = 'Total',
    }) {
      return OverviewMetric(
        id: id,
        title: title,
        value: formatDashboardCount(value),
        growthLabel: value < 0 ? 'Unavailable' : growthLabel,
        growthPositive: null,
        icon: icon,
        accent: accent,
        sparkline: const [],
      );
    }

    return [
      tile(
        id: 'users',
        title: 'Users',
        value: users,
        icon: Icons.people_outline,
        accent: AdminColors.primaryBlue,
      ),
      tile(
        id: 'orgs',
        title: 'Orgs & series',
        value: orgs,
        icon: Icons.hub_outlined,
        accent: const Color(0xFF5C6BC0),
      ),
      tile(
        id: 'teams',
        title: 'Teams',
        value: teams,
        icon: Icons.groups_outlined,
        accent: const Color(0xFF7E57C2),
      ),
      tile(
        id: 'players',
        title: 'Players',
        value: players,
        icon: Icons.person_outline,
        accent: const Color(0xFF26A69A),
      ),
      tile(
        id: 'matches',
        title: 'Matches',
        value: matches,
        icon: Icons.sports_cricket_outlined,
        accent: AdminColors.goldDark,
      ),
      tile(
        id: 'live_matches',
        title: 'Live matches',
        value: liveMatches,
        icon: Icons.sensors,
        accent: const Color(0xFFE53935),
        growthLabel: 'Now',
      ),
      tile(
        id: 'streams',
        title: 'Active streams',
        value: liveStreams,
        icon: Icons.live_tv_outlined,
        accent: const Color(0xFFEF5350),
        growthLabel: 'Now',
      ),
      tile(
        id: 'tournaments',
        title: 'Tournaments',
        value: tournaments,
        icon: Icons.emoji_events_outlined,
        accent: const Color(0xFFFB8C00),
      ),
      tile(
        id: 'grounds',
        title: 'Grounds',
        value: grounds,
        icon: Icons.stadium_outlined,
        accent: const Color(0xFF5C6BC0),
      ),
      tile(
        id: 'community',
        title: 'Community posts',
        value: community,
        icon: Icons.forum_outlined,
        accent: const Color(0xFF00897B),
      ),
      tile(
        id: 'discover',
        title: 'Discover posts',
        value: discover,
        icon: Icons.explore_outlined,
        accent: const Color(0xFF42A5F5),
      ),
      tile(
        id: 'reports',
        title: 'Reports',
        value: reports,
        icon: Icons.flag_outlined,
        accent: const Color(0xFFFF7043),
      ),
      tile(
        id: 'notifications',
        title: 'Notifications',
        value: notifications,
        icon: Icons.notifications_outlined,
        accent: AdminColors.primaryBlueLight,
      ),
    ];
  }

  List<QuickActionItem> _quickActions() {
    return const [
      QuickActionItem(
        id: 'tournament',
        label: 'Create Tournament',
        icon: Icons.emoji_events_outlined,
        route: AdminRoutePaths.tournaments,
        accent: Color(0xFFFB8C00),
      ),
      QuickActionItem(
        id: 'notification',
        label: 'Send Notification',
        icon: Icons.campaign_outlined,
        route: AdminRoutePaths.notifications,
        accent: AdminColors.primaryBlue,
      ),
      QuickActionItem(
        id: 'users',
        label: 'Manage Users',
        icon: Icons.manage_accounts_outlined,
        route: AdminRoutePaths.users,
        accent: Color(0xFF7E57C2),
      ),
      QuickActionItem(
        id: 'reports',
        label: 'Reports',
        icon: Icons.flag_outlined,
        route: AdminRoutePaths.reports,
        accent: Color(0xFFE53935),
      ),
      QuickActionItem(
        id: 'ads',
        label: 'Advertisements',
        icon: Icons.ads_click_outlined,
        route: AdminRoutePaths.ads,
        accent: Color(0xFF00897B),
      ),
      QuickActionItem(
        id: 'community',
        label: 'Community',
        icon: Icons.forum_outlined,
        route: AdminRoutePaths.community,
        accent: Color(0xFF26A69A),
      ),
      QuickActionItem(
        id: 'broadcast',
        label: 'Broadcasts',
        icon: Icons.live_tv_outlined,
        route: AdminRoutePaths.broadcast,
        accent: Color(0xFFEF5350),
      ),
      QuickActionItem(
        id: 'orgs',
        label: 'Orgs & Series',
        icon: Icons.hub_outlined,
        route: AdminRoutePaths.orgs,
        accent: Color(0xFF5C6BC0),
      ),
    ];
  }

  List<SystemStatusItem> _systemStatus({
    required bool firestoreOk,
    required bool signedIn,
  }) {
    return [
      SystemStatusItem(
        id: 'firestore',
        name: 'Firestore',
        status: firestoreOk ? ServiceHealth.healthy : ServiceHealth.offline,
        detail: firestoreOk
            ? 'Reachable — counts and recent docs loaded'
            : 'A count or recent-doc query failed',
      ),
      SystemStatusItem(
        id: 'auth',
        name: 'Authentication',
        status: signedIn ? ServiceHealth.healthy : ServiceHealth.warning,
        detail: signedIn
            ? 'Signed in for this session'
            : 'No signed-in user on this session',
      ),
    ];
  }

  List<HealthMetric> _platformHealth({
    required int usersToday,
    required int liveMatches,
    required int liveStreams,
  }) {
    final now = DateTime.now().toUtc();
    String n(int v) => formatDashboardCount(v);
    return [
      HealthMetric(
        id: 'new_today',
        label: 'New users today',
        value: n(usersToday),
        icon: Icons.person_search_outlined,
      ),
      HealthMetric(
        id: 'concurrent_live',
        label: 'Concurrent live matches',
        value: n(liveMatches),
        icon: Icons.sports_cricket_outlined,
      ),
      HealthMetric(
        id: 'streams',
        label: 'Streams running',
        value: n(liveStreams),
        icon: Icons.videocam_outlined,
      ),
      HealthMetric(
        id: 'server_time',
        label: 'Server time',
        value:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} UTC',
        icon: Icons.schedule_outlined,
      ),
    ];
  }
}
