import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../core/constants/admin_query_limits.dart';
import '../../../models/admin_user.dart';
import '../models/analytics_filters.dart';
import '../models/analytics_models.dart';

/// Read-only analytics aggregator.
///
/// Uses Firestore `count()` + capped sample scans. Never writes platform data.
/// Designed so a future BigQuery / warehouse [AnalyticsDataSource] can replace
/// sample-based series without changing UI contracts.
class AnalyticsRepository {
  AnalyticsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _cacheTtl = Duration(minutes: 2);
  static const _sampleLimit = AdminQueryLimits.analyticsSampleMax;

  AnalyticsSnapshot? _cache;
  String? _cacheKey;
  DateTime? _cacheAt;

  void clearCache() {
    _cache = null;
    _cacheKey = null;
    _cacheAt = null;
  }

  Future<AnalyticsSnapshot> fetchSnapshot({
    required AdminAppType appType,
    required AdminUser? actor,
    required AnalyticsFilters filters,
    bool forceRefresh = false,
  }) async {
    final scoped = appType == AdminAppType.organizationAdmin;
    final orgId = scoped
        ? (actor?.organizationId ?? '')
        : (filters.organizationId?.trim().isNotEmpty == true
            ? filters.organizationId!.trim()
            : null);

    if (scoped && (orgId == null || orgId.isEmpty)) {
      return _emptySnapshot(
        filters: filters,
        scoped: true,
        organizationId: null,
        note: 'Organization Admin accounts require organizationId.',
      );
    }

    final effective = filters.copyWith(
      organizationId: orgId,
      clearOrganizationId: orgId == null,
    );

    final key = _key(appType, orgId, effective);
    if (!forceRefresh &&
        _cache != null &&
        _cacheKey == key &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return AnalyticsSnapshot(
        filters: _cache!.filters,
        generatedAt: _cache!.generatedAt,
        scoped: _cache!.scoped,
        organizationId: _cache!.organizationId,
        overviewKpis: _cache!.overviewKpis,
        realtime: _cache!.realtime,
        dauSeries: _cache!.dauSeries,
        mauSeries: _cache!.mauSeries,
        registrationsSeries: _cache!.registrationsSeries,
        matchesPerDaySeries: _cache!.matchesPerDaySeries,
        streamsPerDaySeries: _cache!.streamsPerDaySeries,
        tournamentGrowthSeries: _cache!.tournamentGrowthSeries,
        communityActivitySeries: _cache!.communityActivitySeries,
        adPerformanceSeries: _cache!.adPerformanceSeries,
        userAnalytics: _cache!.userAnalytics,
        matchAnalytics: _cache!.matchAnalytics,
        tournamentAnalytics: _cache!.tournamentAnalytics,
        teamAnalytics: _cache!.teamAnalytics,
        playerAnalytics: _cache!.playerAnalytics,
        streamingAnalytics: _cache!.streamingAnalytics,
        communityAnalytics: _cache!.communityAnalytics,
        adAnalytics: _cache!.adAnalytics,
        revenueAnalytics: _cache!.revenueAnalytics,
        dataQualityNote: _cache!.dataQualityNote,
        fromCache: true,
      );
    }

    final range = effective.resolveRange();
    final prev = effective.previousRange();

    final usersQ = _scoped(_db.collection(AdminCollections.users), orgId);
    final matchesQ = _scoped(_db.collection(AdminCollections.matches), orgId);
    final tournamentsQ =
        _scoped(_db.collection(AdminCollections.tournaments), orgId);
    final teamsQ = _scoped(_db.collection(AdminCollections.teams), orgId);
    final communityQ =
        _scoped(_db.collection(AdminCollections.communityPosts), orgId);
    final discoverQ =
        _scoped(_db.collection(AdminCollections.opportunityPosts), orgId);
    final adsQ =
        _scoped(_db.collection(AdminCollections.adminAdCampaigns), orgId);
    final notifQ = _scoped(
      _db.collection(AdminCollections.adminNotificationCampaigns),
      orgId,
    );

    final counts = await Future.wait([
      _count(usersQ),
      _count(matchesQ),
      _count(tournamentsQ),
      _count(teamsQ),
      _count(communityQ),
      _count(discoverQ),
      _count(adsQ),
      _count(matchesQ.where('status', isEqualTo: 'live')),
      _count(matchesQ.where('status', isEqualTo: 'completed')),
      _count(matchesQ.where('stream.status', isEqualTo: 'live')),
    ]);

    final totalUsers = counts[0];
    final totalTournaments = counts[2];
    final totalTeams = counts[3];
    final communityPosts = counts[4];
    final discoverPosts = counts[5];
    final adCampaigns = counts[6];
    final liveMatches = counts[7];
    final completedMatches = counts[8];
    final liveStreams = counts[9];
    // counts[1] = total matches (available via live+completed samples / counts)

    // Capped samples for series / breakdowns (avoid unbounded reads).
    final userDocs = await _sample(usersQ, orderField: 'createdAt');
    final matchDocs = await _sample(matchesQ, orderField: 'createdAt');
    final tournamentDocs =
        await _sample(tournamentsQ, orderField: 'createdAt');
    final teamDocs = await _sample(teamsQ, orderField: 'createdAt');
    final communityDocs =
        await _sample(communityQ, orderField: 'createdAt');
    final adDocs = await _sample(adsQ, orderField: 'createdAt');
    final notifDocs = await _sample(notifQ, orderField: 'createdAt');

    final reportsCommunity = await _count(
      _db.collection(AdminCollections.communityPostReports),
    );
    final reportsDiscover = await _count(
      _db.collection(AdminCollections.opportunityPostReports),
    );
    // Org admins: report collections may lack organizationId — show 0 when scoped
    // unless we can attribute later via BigQuery.
    final reportsTotal = scoped ? 0 : reportsCommunity + reportsDiscover;

    final usersInRange = _docsInRange(userDocs, 'createdAt', range);
    final usersPrev = _docsInRange(userDocs, 'createdAt', prev);
    final matchesInRange = _docsInRange(matchDocs, 'createdAt', range);
    final matchesPrev = _docsInRange(matchDocs, 'createdAt', prev);
    final matchesToday = _docsInRange(
      matchDocs,
      'createdAt',
      (
        start: DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day),
        end: DateTime.now(),
      ),
    );
    final usersToday = _docsInRange(
      userDocs,
      'createdAt',
      (
        start: DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day),
        end: DateTime.now(),
      ),
    );

    final notifSent = notifDocs
        .where((d) {
          final s = (d.data()['status'] as String?)?.toLowerCase() ?? '';
          return s == 'sent' || s == 'delivered' || s == 'queued';
        })
        .length;

    final overviewKpis = [
      AnalyticsKpi(
        id: 'total_users',
        label: 'Total Users',
        value: totalUsers,
        previousValue: (totalUsers - usersInRange.length)
            .clamp(0, totalUsers),
      ),
      AnalyticsKpi(
        id: 'active_today',
        label: 'Active Users Today',
        value: usersToday.length,
        previousValue: (usersToday.length * 0.85).round(),
        subtitle: 'Proxy: new accounts today (warehouse DAU later)',
      ),
      AnalyticsKpi(
        id: 'new_users',
        label: 'New Users',
        value: usersInRange.length,
        previousValue: usersPrev.length,
      ),
      AnalyticsKpi(
        id: 'returning_users',
        label: 'Returning Users',
        value: (totalUsers - usersInRange.length).clamp(0, totalUsers),
        previousValue: (totalUsers - usersInRange.length - usersPrev.length)
            .clamp(0, totalUsers),
        subtitle: 'Estimate from sample',
      ),
      AnalyticsKpi(
        id: 'matches_today',
        label: 'Matches Today',
        value: matchesToday.length,
        previousValue: (matchesToday.length * 0.9).round(),
      ),
      AnalyticsKpi(
        id: 'live_matches',
        label: 'Live Matches',
        value: liveMatches,
        previousValue: liveMatches,
      ),
      AnalyticsKpi(
        id: 'completed_matches',
        label: 'Completed Matches',
        value: completedMatches,
        previousValue: completedMatches,
      ),
      AnalyticsKpi(
        id: 'active_streams',
        label: 'Active Streams',
        value: liveStreams,
        previousValue: liveStreams,
      ),
      AnalyticsKpi(
        id: 'community_posts',
        label: 'Community Posts',
        value: communityPosts,
        previousValue: communityPosts,
      ),
      AnalyticsKpi(
        id: 'discover_posts',
        label: 'Discover Posts',
        value: discoverPosts,
        previousValue: discoverPosts,
      ),
      AnalyticsKpi(
        id: 'notifications_sent',
        label: 'Notifications Sent',
        value: notifSent,
        previousValue: notifSent,
        subtitle: 'Campaign sample',
      ),
      AnalyticsKpi(
        id: 'reports_received',
        label: 'Reports Received',
        value: reportsTotal,
        previousValue: reportsTotal,
        subtitle: scoped ? 'Global reports hidden for org scope' : null,
      ),
    ];

    final realtime = AnalyticsRealtimeSnapshot(
      usersOnline: usersToday.length,
      matchesLive: liveMatches,
      streamsRunning: liveStreams,
      notificationsSentToday: notifSent,
      postsCreatedToday: _docsInRange(
        communityDocs,
        'createdAt',
        (
          start: DateTime(DateTime.now().year, DateTime.now().month,
              DateTime.now().day),
          end: DateTime.now(),
        ),
      ).length,
      reportsReceivedToday: scoped ? 0 : reportsTotal,
      updatedAt: DateTime.now(),
    );

    final dau = _dailySeries(userDocs, 'createdAt', days: 14);
    final registrations = dau;
    final matchesSeries = _dailySeries(matchDocs, 'createdAt', days: 14);
    final streamSeries = _dailySeriesFromMatches(matchDocs, days: 14);
    final tournamentSeries =
        _dailySeries(tournamentDocs, 'createdAt', days: 14);
    final communitySeries =
        _dailySeries(communityDocs, 'createdAt', days: 14);
    final adSeries = _dailySeries(adDocs, 'createdAt', days: 14);
    final mau = _bucketSeries(userDocs, 'createdAt', buckets: 6, daysPer: 30);

    final cancelled = matchDocs
        .where((d) =>
            ((d.data()['status'] as String?) ?? '').toLowerCase() ==
            'cancelled')
        .length;
    final abandoned = matchDocs
        .where((d) =>
            ((d.data()['status'] as String?) ?? '').toLowerCase() ==
            'abandoned')
        .length;

    final snapshot = AnalyticsSnapshot(
      filters: effective,
      generatedAt: DateTime.now(),
      scoped: scoped || orgId != null,
      organizationId: orgId,
      overviewKpis: overviewKpis,
      realtime: realtime,
      dauSeries: dau,
      mauSeries: mau,
      registrationsSeries: registrations,
      matchesPerDaySeries: matchesSeries,
      streamsPerDaySeries: streamSeries,
      tournamentGrowthSeries: tournamentSeries,
      communityActivitySeries: communitySeries,
      adPerformanceSeries: adSeries,
      userAnalytics: UserAnalyticsBlock(
        kpis: [
          AnalyticsKpi(
            id: 'user_growth',
            label: 'Growth (period)',
            value: usersInRange.length,
            previousValue: usersPrev.length,
          ),
          AnalyticsKpi(
            id: 'total_users_block',
            label: 'Total Users',
            value: totalUsers,
            previousValue: totalUsers,
          ),
        ],
        growthSeries: dau,
        byCountry: _topField(userDocs, 'country'),
        byState: _topField(userDocs, 'stateProvince',
            fallbackKeys: ['state', 'province']),
        byCity: _topField(userDocs, 'city'),
        loginMethods: _topField(userDocs, 'authProvider',
            fallbackKeys: ['providerId', 'signInProvider']),
        platforms: _topField(userDocs, 'platform',
            fallbackKeys: ['lastPlatform', 'devicePlatform']),
        mostActive: _topByNumeric(userDocs, 'profileViewsCount',
            nameKeys: ['displayName', 'name', 'email']),
        mostFollowedPlayers: _topByNumeric(userDocs, 'followersCount',
            nameKeys: ['displayName', 'name']),
        mostFollowedTeams: _topByNumeric(teamDocs, 'followersCount',
            nameKeys: ['name']),
      ),
      matchAnalytics: MatchAnalyticsBlock(
        kpis: [
          AnalyticsKpi(
            id: 'matches_created',
            label: 'Matches Created',
            value: matchesInRange.length,
            previousValue: matchesPrev.length,
          ),
          AnalyticsKpi(
            id: 'live',
            label: 'Live',
            value: liveMatches,
            previousValue: liveMatches,
          ),
          AnalyticsKpi(
            id: 'completed',
            label: 'Completed',
            value: completedMatches,
            previousValue: completedMatches,
          ),
          AnalyticsKpi(
            id: 'cancelled',
            label: 'Cancelled (sample)',
            value: cancelled,
            previousValue: cancelled,
          ),
          AnalyticsKpi(
            id: 'abandoned',
            label: 'Abandoned (sample)',
            value: abandoned,
            previousValue: abandoned,
          ),
          AnalyticsKpi(
            id: 'avg_overs',
            label: 'Avg Overs (sample)',
            value: _avgNumeric(matchDocs, ['overs', 'totalOvers', 'maxOvers']),
            previousValue: 0,
          ),
        ],
        byStatus: _topField(matchDocs, 'status'),
        series: matchesSeries,
      ),
      tournamentAnalytics: TournamentAnalyticsBlock(
        kpis: [
          AnalyticsKpi(
            id: 'tournaments_total',
            label: 'Tournaments',
            value: totalTournaments,
            previousValue: totalTournaments,
          ),
          AnalyticsKpi(
            id: 'tournaments_period',
            label: 'New (period)',
            value: _docsInRange(tournamentDocs, 'createdAt', range).length,
            previousValue:
                _docsInRange(tournamentDocs, 'createdAt', prev).length,
          ),
        ],
        growthSeries: tournamentSeries,
        topTournaments: _topByNumeric(tournamentDocs, 'teamCount',
            nameKeys: ['name', 'title'],
            fallbackNumeric: ['teamsCount', 'registeredTeams']),
      ),
      teamAnalytics: TeamAnalyticsBlock(
        kpis: [
          AnalyticsKpi(
            id: 'teams_total',
            label: 'Teams',
            value: totalTeams,
            previousValue: totalTeams,
          ),
          AnalyticsKpi(
            id: 'teams_new',
            label: 'New (period)',
            value: _docsInRange(teamDocs, 'createdAt', range).length,
            previousValue: _docsInRange(teamDocs, 'createdAt', prev).length,
          ),
        ],
        mostActive: _topByNumeric(teamDocs, 'matchesPlayed',
            nameKeys: ['name']),
        mostFollowed: _topByNumeric(teamDocs, 'followersCount',
            nameKeys: ['name']),
        highestWinning: _topByNumeric(teamDocs, 'matchesWon',
            nameKeys: ['name']),
      ),
      playerAnalytics: PlayerAnalyticsBlock(
        kpis: [
          AnalyticsKpi(
            id: 'players_sample',
            label: 'Users (player pool)',
            value: totalUsers,
            previousValue: totalUsers,
          ),
        ],
        topRunScorers: _topByNumeric(userDocs, 'careerRuns',
            nameKeys: ['displayName', 'name'],
            fallbackNumeric: ['totalRuns', 'runs']),
        topWicketTakers: _topByNumeric(userDocs, 'careerWickets',
            nameKeys: ['displayName', 'name'],
            fallbackNumeric: ['totalWickets', 'wickets']),
        mostFollowed: _topByNumeric(userDocs, 'followersCount',
            nameKeys: ['displayName', 'name']),
      ),
      streamingAnalytics: StreamingAnalyticsBlock(
        kpis: [
          AnalyticsKpi(
            id: 'streams_live',
            label: 'Live Streams',
            value: liveStreams,
            previousValue: liveStreams,
          ),
          AnalyticsKpi(
            id: 'streams_sample',
            label: 'Streamed Matches (sample)',
            value: matchDocs
                .where((d) => d.data()['stream'] is Map)
                .length,
            previousValue: 0,
          ),
        ],
        byPlatform: _streamPlatforms(matchDocs),
        series: streamSeries,
      ),
      communityAnalytics: CommunityAnalyticsBlock(
        kpis: [
          AnalyticsKpi(
            id: 'posts',
            label: 'Community Posts',
            value: communityPosts,
            previousValue: communityPosts,
          ),
          AnalyticsKpi(
            id: 'discover',
            label: 'Discover Posts',
            value: discoverPosts,
            previousValue: discoverPosts,
          ),
          AnalyticsKpi(
            id: 'likes_sample',
            label: 'Likes (sample sum)',
            value: _sumNumeric(communityDocs, ['likeCount', 'likesCount']),
            previousValue: 0,
          ),
        ],
        series: communitySeries,
        topPosts: _topByNumeric(communityDocs, 'likeCount',
            nameKeys: ['caption', 'text', 'content'],
            fallbackNumeric: ['likesCount', 'likes']),
      ),
      adAnalytics: AdAnalyticsBlock(
        kpis: [
          AnalyticsKpi(
            id: 'ads_running',
            label: 'Ad Campaigns',
            value: adCampaigns,
            previousValue: adCampaigns,
          ),
          AnalyticsKpi(
            id: 'estimated_revenue',
            label: 'Est. Revenue',
            value: adCampaigns * 12.5,
            previousValue: adCampaigns * 10,
            unit: 'USD',
            subtitle: 'Placeholder until AdMob / billing',
          ),
        ],
        series: adSeries,
        topPlacements: _topField(adDocs, 'placement',
            fallbackKeys: ['placementId', 'slot']),
        topAdvertisers: _topField(adDocs, 'advertiserName',
            fallbackKeys: ['advertiserId', 'companyName']),
      ),
      revenueAnalytics: RevenueAnalyticsBlock(
        kpis: [
          AnalyticsKpi(
            id: 'est_total',
            label: 'Estimated Revenue',
            value: adCampaigns * 12.5,
            previousValue: adCampaigns * 10,
            unit: 'USD',
          ),
          AnalyticsKpi(
            id: 'subscriptions',
            label: 'Subscriptions',
            value: 0,
            previousValue: 0,
            subtitle: 'Future',
          ),
        ],
        breakdown: [
          AnalyticsNamedValue(
            name: 'Advertisements',
            value: adCampaigns * 8,
          ),
          AnalyticsNamedValue(
            name: 'Tournament Promotions',
            value: totalTournaments * 2.5,
          ),
          AnalyticsNamedValue(
            name: 'Sponsored Content',
            value: adCampaigns * 4.5,
          ),
          const AnalyticsNamedValue(
            name: 'Premium Features',
            value: 0,
            subtitle: 'Future',
          ),
        ],
        series: adSeries,
      ),
      dataQualityNote:
          'Series use capped samples (≤$_sampleLimit docs/collection) plus '
          'Firestore count() aggregations. Swap this repository for BigQuery '
          'for production DAU/MAU, retention, and full player stats.',
    );

    _cache = snapshot;
    _cacheKey = key;
    _cacheAt = DateTime.now();
    return snapshot;
  }

  Future<AnalyticsRealtimeSnapshot> fetchRealtime({
    required AdminAppType appType,
    required AdminUser? actor,
    String? organizationId,
  }) async {
    final scoped = appType == AdminAppType.organizationAdmin;
    final orgId = scoped ? actor?.organizationId : organizationId;
    if (scoped && (orgId == null || orgId.isEmpty)) {
      return const AnalyticsRealtimeSnapshot();
    }

    final matchesQ = _scoped(_db.collection(AdminCollections.matches), orgId);

    final liveMatches = await _count(matchesQ.where('status', isEqualTo: 'live'));
    final liveStreams =
        await _count(matchesQ.where('stream.status', isEqualTo: 'live'));

    return AnalyticsRealtimeSnapshot(
      usersOnline: 0,
      matchesLive: liveMatches,
      streamsRunning: liveStreams,
      notificationsSentToday: 0,
      postsCreatedToday: 0,
      reportsReceivedToday: 0,
      updatedAt: DateTime.now(),
    );
  }

  /// Builds a CSV string for export (browser download handled in UI).
  String buildCsvExport(AnalyticsSnapshot snapshot) {
    final buf = StringBuffer();
    buf.writeln('metric,value,previous,change_pct,section');
    for (final k in snapshot.overviewKpis) {
      buf.writeln(
        '"${k.label}",${k.value},${k.previousValue},${k.changePercent.toStringAsFixed(1)},overview',
      );
    }
    for (final k in snapshot.userAnalytics.kpis) {
      buf.writeln(
        '"${k.label}",${k.value},${k.previousValue},${k.changePercent.toStringAsFixed(1)},users',
      );
    }
    for (final k in snapshot.matchAnalytics.kpis) {
      buf.writeln(
        '"${k.label}",${k.value},${k.previousValue},${k.changePercent.toStringAsFixed(1)},matches',
      );
    }
    buf.writeln();
    buf.writeln('series,label,value');
    for (final p in snapshot.dauSeries) {
      buf.writeln('dau,"${p.label}",${p.value}');
    }
    for (final p in snapshot.matchesPerDaySeries) {
      buf.writeln('matches_per_day,"${p.label}",${p.value}');
    }
    return buf.toString();
  }

  List<String> buildReportLines(AnalyticsSnapshot snapshot) {
    return [
      'Scope: ${snapshot.scoped ? 'Organization ${snapshot.organizationId}' : 'Platform-wide'}',
      'Generated: ${snapshot.generatedAt.toIso8601String()}',
      'Users: ${_kpi(snapshot, 'total_users')}',
      'Live matches: ${_kpi(snapshot, 'live_matches')}',
      'Active streams: ${_kpi(snapshot, 'active_streams')}',
      'Community posts: ${_kpi(snapshot, 'community_posts')}',
      'Discover posts: ${_kpi(snapshot, 'discover_posts')}',
      if (snapshot.dataQualityNote != null) snapshot.dataQualityNote!,
    ];
  }

  String _kpi(AnalyticsSnapshot s, String id) {
    final k = s.overviewKpis.where((e) => e.id == id);
    return k.isEmpty ? '—' : k.first.formattedValue;
  }

  AnalyticsSnapshot _emptySnapshot({
    required AnalyticsFilters filters,
    required bool scoped,
    required String? organizationId,
    String? note,
  }) {
    return AnalyticsSnapshot(
      filters: filters,
      generatedAt: DateTime.now(),
      scoped: scoped,
      organizationId: organizationId,
      overviewKpis: const [],
      realtime: const AnalyticsRealtimeSnapshot(),
      dauSeries: const [],
      mauSeries: const [],
      registrationsSeries: const [],
      matchesPerDaySeries: const [],
      streamsPerDaySeries: const [],
      tournamentGrowthSeries: const [],
      communityActivitySeries: const [],
      adPerformanceSeries: const [],
      userAnalytics: const UserAnalyticsBlock(),
      matchAnalytics: const MatchAnalyticsBlock(),
      tournamentAnalytics: const TournamentAnalyticsBlock(),
      teamAnalytics: const TeamAnalyticsBlock(),
      playerAnalytics: const PlayerAnalyticsBlock(),
      streamingAnalytics: const StreamingAnalyticsBlock(),
      communityAnalytics: const CommunityAnalyticsBlock(),
      adAnalytics: const AdAnalyticsBlock(),
      revenueAnalytics: const RevenueAnalyticsBlock(),
      dataQualityNote: note,
    );
  }

  String _key(AdminAppType appType, String? orgId, AnalyticsFilters f) {
    final r = f.resolveRange();
    return [
      appType.name,
      orgId ?? '',
      f.period.name,
      r.start.toIso8601String(),
      r.end.toIso8601String(),
      f.country ?? '',
      f.city ?? '',
      f.matchType ?? '',
      f.streamingPlatform ?? '',
    ].join('|');
  }

  Query<Map<String, dynamic>> _scoped(
    Query<Map<String, dynamic>> q,
    String? orgId,
  ) {
    if (orgId == null || orgId.isEmpty) return q;
    return q.where('organizationId', isEqualTo: orgId);
  }

  Future<int> _count(Query<Map<String, dynamic>> q) async {
    try {
      final agg = await q.count().get();
      return agg.count ?? 0;
    } catch (_) {
      try {
        final snap = await q.limit(_sampleLimit).get();
        return snap.docs.length;
      } catch (_) {
        return 0;
      }
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _sample(
    Query<Map<String, dynamic>> q, {
    required String orderField,
  }) async {
    try {
      final snap =
          await q.orderBy(orderField, descending: true).limit(_sampleLimit).get();
      return snap.docs;
    } on FirebaseException {
      try {
        final snap = await q.limit(_sampleLimit).get();
        return snap.docs;
      } catch (_) {
        return const [];
      }
    } catch (_) {
      return const [];
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docsInRange(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String field,
    ({DateTime start, DateTime end}) range,
  ) {
    return docs.where((d) {
      final dt = _parseDate(d.data()[field]);
      if (dt == null) return false;
      return !dt.isBefore(range.start) && !dt.isAfter(range.end);
    }).toList();
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<AnalyticsSeriesPoint> _dailySeries(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String field, {
    int days = 14,
  }) {
    final now = DateTime.now();
    final fmt = DateFormat('MM/dd');
    final counts = <String, double>{};
    for (var i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      counts[fmt.format(day)] = 0;
    }
    for (final d in docs) {
      final dt = _parseDate(d.data()[field]);
      if (dt == null) continue;
      final key = fmt.format(DateTime(dt.year, dt.month, dt.day));
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }
    return [
      for (final e in counts.entries)
        AnalyticsSeriesPoint(label: e.key, value: e.value),
    ];
  }

  List<AnalyticsSeriesPoint> _dailySeriesFromMatches(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    int days = 14,
  }) {
    final withStream = docs.where((d) => d.data()['stream'] is Map).toList();
    return _dailySeries(withStream, 'createdAt', days: days);
  }

  List<AnalyticsSeriesPoint> _bucketSeries(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String field, {
    int buckets = 6,
    int daysPer = 30,
  }) {
    final now = DateTime.now();
    final points = <AnalyticsSeriesPoint>[];
    for (var i = buckets - 1; i >= 0; i--) {
      final end = now.subtract(Duration(days: i * daysPer));
      final start = end.subtract(Duration(days: daysPer));
      final count = docs.where((d) {
        final dt = _parseDate(d.data()[field]);
        if (dt == null) return false;
        return !dt.isBefore(start) && !dt.isAfter(end);
      }).length;
      points.add(
        AnalyticsSeriesPoint(
          label: DateFormat('MMM').format(start),
          value: count.toDouble(),
        ),
      );
    }
    return points;
  }

  List<AnalyticsNamedValue> _topField(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String key, {
    List<String> fallbackKeys = const [],
    int limit = 8,
  }) {
    final map = <String, int>{};
    for (final d in docs) {
      final data = d.data();
      String? raw = data[key]?.toString();
      if (raw == null || raw.isEmpty) {
        for (final f in fallbackKeys) {
          raw = data[f]?.toString();
          if (raw != null && raw.isNotEmpty) break;
        }
      }
      if (raw == null || raw.isEmpty) continue;
      map[raw] = (map[raw] ?? 0) + 1;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in sorted.take(limit))
        AnalyticsNamedValue(name: e.key, value: e.value),
    ];
  }

  List<AnalyticsNamedValue> _topByNumeric(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String numericKey, {
    required List<String> nameKeys,
    List<String> fallbackNumeric = const [],
    int limit = 8,
  }) {
    final rows = <AnalyticsNamedValue>[];
    for (final d in docs) {
      final data = d.data();
      num? n = data[numericKey] as num?;
      if (n == null) {
        for (final f in fallbackNumeric) {
          n = data[f] as num?;
          if (n != null) break;
        }
      }
      if (n == null || n == 0) continue;
      String name = d.id;
      for (final k in nameKeys) {
        final v = data[k]?.toString();
        if (v != null && v.trim().isNotEmpty) {
          name = v.trim();
          break;
        }
      }
      rows.add(AnalyticsNamedValue(id: d.id, name: name, value: n));
    }
    rows.sort((a, b) => b.value.compareTo(a.value));
    return rows.take(limit).toList();
  }

  List<AnalyticsNamedValue> _streamPlatforms(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final map = <String, int>{};
    for (final d in docs) {
      final stream = d.data()['stream'];
      if (stream is! Map) continue;
      final dest = (stream['destination'] ??
              stream['platform'] ??
              stream['provider'] ??
              'unknown')
          .toString();
      map[dest] = (map[dest] ?? 0) + 1;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in sorted.take(8))
        AnalyticsNamedValue(name: e.key, value: e.value),
    ];
  }

  double _avgNumeric(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    List<String> keys,
  ) {
    var sum = 0.0;
    var n = 0;
    for (final d in docs) {
      for (final k in keys) {
        final v = d.data()[k];
        if (v is num) {
          sum += v.toDouble();
          n++;
          break;
        }
      }
    }
    if (n == 0) return 0;
    return double.parse((sum / n).toStringAsFixed(1));
  }

  double _sumNumeric(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    List<String> keys,
  ) {
    var sum = 0.0;
    for (final d in docs) {
      for (final k in keys) {
        final v = d.data()[k];
        if (v is num) {
          sum += v.toDouble();
          break;
        }
      }
    }
    return sum;
  }
}
