import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/admin_collections.dart';
import '../../../core/constants/admin_query_limits.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/monitoring_enums.dart';
import '../models/monitoring_filters.dart';
import '../models/monitoring_models.dart';

/// System Operations Center data source.
///
/// Monitoring-only: lightweight Firestore `count()` / capped samples +
/// client-side cache. Never reads or exposes secrets, service accounts,
/// or Firebase project configuration. Future swap targets: Cloud Monitoring,
/// Crashlytics, BigQuery, Grafana, Datadog, Sentry.
class MonitoringRepository {
  MonitoringRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _cacheTtl = Duration(minutes: 2);
  static const _sampleLimit = AdminQueryLimits.monitoringSampleMax;

  MonitoringSnapshot? _cache;
  DateTime? _cacheAt;
  String? _cacheOrgKey;

  Future<MonitoringSnapshot> fetchSnapshot({
    String? organizationId,
    bool force = false,
  }) async {
    final key = organizationId ?? '';
    final now = DateTime.now();
    if (!force &&
        _cache != null &&
        _cacheOrgKey == key &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _cacheTtl) {
      return _cache!;
    }

    final scoped = organizationId != null && organizationId.isNotEmpty;
    final sw = Stopwatch()..start();

    final liveMatches = await _count(
      _scoped(_db.collection(AdminCollections.matches), organizationId)
          .where('status', isEqualTo: 'live'),
    );
    final liveStreams = await _count(
      _scoped(_db.collection(AdminCollections.matches), organizationId)
          .where('stream.status', isEqualTo: 'live'),
    );
    // Fallback if stream.status path unsupported
    final liveStreamsAlt = liveStreams > 0
        ? liveStreams
        : await _sampleLiveStreams(organizationId);

    final usersToday = await _countAuthLoginsToday(organizationId);
    final failedLogins = await _countAuditAction(
      AdminAuditActions.adminLoginFailed,
      organizationId,
    );
    final passwordResets = await _countAuditAction(
      AdminAuditActions.adminPasswordResetRequested,
      organizationId,
    );
    final notifSent = await _count(
      _scoped(
        _db.collection(AdminCollections.adminNotificationCampaigns),
        organizationId,
      ),
    );

    sw.stop();
    final probeMs = sw.elapsedMilliseconds;

    final firestoreHealthy = probeMs < 5000;
    final services = _buildServices(
      firestoreOk: firestoreHealthy,
      scoped: scoped,
    );

    final platformHealth = _derivePlatformHealth(services);
    final timeline = await _fetchTimeline(organizationId);
    final errors = await _fetchErrors(organizationId);
    final authMetrics = AuthMetrics(
      loggedInEstimate: 0,
      loginsToday: usersToday,
      failedLogins: failedLogins,
      passwordResets: passwordResets,
      googleSignIns: 0,
      emailSignIns: 0,
      blockedLogins: 0,
      suspiciousLogins: await _countAuditAction(
        AdminAuditActions.securitySuspiciousLogin,
        organizationId,
      ),
    );

    final topCollections = await _topCollectionCounts(organizationId);
    final docEstimate =
        topCollections.fold<int>(0, (acc, c) => acc + c.count);

    final usersCount = await _count(_db.collection(AdminCollections.users));
    final teamsCount = await _count(_db.collection(AdminCollections.teams));
    final matchesCount = await _count(_db.collection(AdminCollections.matches));
    final playersCount = await _count(_db.collection(AdminCollections.players));
    final tournamentsCount =
        await _count(_db.collection(AdminCollections.tournaments));
    final groundsCount = await _count(_db.collection(AdminCollections.grounds));
    final seriesCount = await _count(_db.collection('series'));
    final growth = await _fetchGrowthSeries(
      today: PlatformDailyStat(
        date: PlatformDailyStat.colomboDateId(),
        users: usersCount,
        teams: teamsCount,
        matches: matchesCount,
        players: playersCount,
        tournaments: tournamentsCount,
        grounds: groundsCount,
        series: seriesCount,
        liveMatches: liveMatches,
        isLiveToday: true,
      ),
    );

    final streaming = StreamingHealthMetrics(
      liveStreams: liveStreamsAlt,
      youtube: 0,
      facebook: 0,
      externalRtmp: 0,
      broadcastSessions: liveStreamsAlt,
      reconnectEvents: 0,
      avgDurationMin: 0,
      connectionFailures: 0,
      health: liveStreamsAlt > 0
          ? PlatformServiceHealth.healthy
          : PlatformServiceHealth.unknown,
    );

    final overview = <MonitoringKpi>[
      MonitoringKpi(
        id: 'platform',
        label: 'Platform Status',
        value: platformHealth.label,
        health: platformHealth,
      ),
      MonitoringKpi(
        id: 'users',
        label: 'Admin logins today',
        value: '$usersToday',
        subtitle: scoped ? 'Org-scoped audit' : 'From admin audit logs',
      ),
      MonitoringKpi(
        id: 'live_matches',
        label: 'Live Matches',
        value: '$liveMatches',
      ),
      MonitoringKpi(
        id: 'live_streams',
        label: 'Live Streams',
        value: '$liveStreamsAlt',
      ),
      const MonitoringKpi(
        id: 'functions',
        label: 'Cloud Functions',
        value: 'Not instrumented',
        subtitle: 'Cloud Monitoring is not connected',
        health: PlatformServiceHealth.unknown,
      ),
      MonitoringKpi(
        id: 'firestore',
        label: 'Firestore Probe',
        value: '${probeMs}ms',
        health: firestoreHealthy ? PlatformServiceHealth.healthy : PlatformServiceHealth.warning,
      ),
      const MonitoringKpi(
        id: 'storage',
        label: 'Storage',
        value: '—',
        subtitle: 'Usage API future',
        health: PlatformServiceHealth.unknown,
      ),
      const MonitoringKpi(
        id: 'hosting',
        label: 'Hosting',
        value: 'Not polled',
        subtitle: 'This panel does not probe Hosting',
        health: PlatformServiceHealth.unknown,
      ),
      MonitoringKpi(
        id: 'notifications',
        label: 'Notifications',
        value: '$notifSent',
        subtitle: 'Campaign documents, not FCM receipts',
      ),
      MonitoringKpi(
        id: 'realtime',
        label: 'Realtime',
        value: firestoreHealthy ? 'OK' : 'Slow',
        health: firestoreHealthy ? PlatformServiceHealth.healthy : PlatformServiceHealth.warning,
      ),
    ];

    final snap = MonitoringSnapshot(
      generatedAt: DateTime.now(),
      isOrgScoped: scoped,
      platformHealth: platformHealth,
      overview: overview,
      services: services,
      liveBar: LiveStatusBarSnapshot(
        platformHealth: platformHealth,
        liveMatches: liveMatches,
        liveStreams: liveStreamsAlt,
        onlineUsers: usersToday,
        errors: errors.length,
      ),
      firestore: FirestoreMetrics(
        reads: 0,
        writes: 0,
        deletes: 0,
        queries: topCollections.length,
        activeConnections: 0,
        avgResponseMs: probeMs,
        topCollections: topCollections,
      ),
      auth: authMetrics,
      functions: const [],
      storage: const StorageMetrics(
        totalLabel: 'Not available',
        availableLabel: 'Not available from this panel',
        growthPoints: [],
      ),
      hosting: HostingMetrics(
        status: PlatformServiceHealth.unknown,
        currentDeployment: 'Not polled',
        environment: MonitoringEnvironment.production,
        lastDeployment: null,
        domains: [
          HostingDomainStatus(
            domain: 'crickflow-superadmin.web.app',
            status: PlatformServiceHealth.unknown,
            ssl: PlatformServiceHealth.unknown,
            note: 'Known Hosting site — status is not polled from this panel',
          ),
          HostingDomainStatus(
            domain: 'crickflow.web.app',
            status: PlatformServiceHealth.unknown,
            ssl: PlatformServiceHealth.unknown,
            note: 'Known Hosting site — status is not polled from this panel',
          ),
        ],
      ),
      fcm: FcmMetrics(
        sentToday: notifSent,
        deliveryRate: 0,
        failures: 0,
        pending: 0,
        avgDeliveryMs: 0,
      ),
      streaming: streaming,
      database: DatabaseMetrics(
        collections: topCollections.length,
        documentsEstimate: docEstimate,
        estimatedSizeLabel: 'Not available',
        readUsage: 0,
        writeUsage: 0,
        deleteUsage: 0,
        growthPoints: [
          for (final row in growth) row.trackedDocuments.toDouble(),
        ],
      ),
      performance: PerformanceMetrics(
        avgApiResponseMs: probeMs,
        firestoreResponseMs: probeMs,
        cloudFunctionDurationMs: 0,
        realtimeLatencyMs: probeMs,
        avgQueryMs: probeMs,
      ),
      errors: errors,
      scheduledJobs: [
        const ScheduledJobItem(
          kind: ScheduledJobKind.scheduledNotifications,
          note:
              'processScheduledNotificationCampaigns is a Cloud Scheduler worker. Last run is not read from this panel.',
        ),
        ScheduledJobItem(
          kind: ScheduledJobKind.analyticsJobs,
          status: growth.any((g) => !g.isLiveToday)
              ? BackgroundTaskStatus.completed
              : BackgroundTaskStatus.pending,
          lastRun: () {
            final historic = growth.where((g) => !g.isLiveToday).toList();
            if (historic.isEmpty) return null;
            return DateTime.tryParse(historic.last.date);
          }(),
          note:
              'writeDailyPlatformStats writes platform counts at 01:00 Asia/Colombo. Growth charts use those documents when present.',
        ),
        for (final k in ScheduledJobKind.values)
          if (k != ScheduledJobKind.scheduledNotifications &&
              k != ScheduledJobKind.analyticsJobs)
            ScheduledJobItem(kind: k),
      ],
      backgroundTasks: const [],
      timeline: timeline,
      growth: growth,
    );

    _cache = snap;
    _cacheAt = DateTime.now();
    _cacheOrgKey = key;
    return snap;
  }

  List<MonitoringErrorItem> filterErrors(
    List<MonitoringErrorItem> errors,
    MonitoringFilters filters,
  ) {
    Iterable<MonitoringErrorItem> items = errors;
    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where(
        (e) =>
            e.title.toLowerCase().contains(q) ||
            e.module.toLowerCase().contains(q) ||
            e.detail.toLowerCase().contains(q),
      );
    }
    if (filters.severities.isNotEmpty) {
      items = items.where((e) => filters.severities.contains(e.severity));
    }
    if (filters.module?.trim().isNotEmpty == true) {
      final m = filters.module!.trim().toLowerCase();
      items = items.where((e) => e.module.toLowerCase().contains(m));
    }
    if (filters.from != null) {
      items = items.where((e) => !e.timestamp.isBefore(filters.from!));
    }
    if (filters.to != null) {
      items = items.where((e) => !e.timestamp.isAfter(filters.to!));
    }
    return items.toList();
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

  Future<int> _sampleLiveStreams(String? orgId) async {
    try {
      final snap = await _scoped(
        _db.collection(AdminCollections.matches),
        orgId,
      ).limit(_sampleLimit).get();
      var n = 0;
      for (final d in snap.docs) {
        final stream = d.data()['stream'];
        if (stream is Map && stream['status'] == 'live') n++;
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countAuthLoginsToday(String? orgId) async {
    try {
      final start = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final snap = await _db
          .collection(AdminCollections.adminAuditLogs)
          .where('action', isEqualTo: AdminAuditActions.adminLoginSuccess)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      var n = 0;
      for (final d in snap.docs) {
        final entry = AdminAuditLogEntry.fromMap(d.id, d.data());
        if (entry.timestamp.isBefore(start)) continue;
        if (orgId != null &&
            orgId.isNotEmpty &&
            entry.metadata['organizationId'] != orgId) {
          continue;
        }
        n++;
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countAuditAction(String action, String? orgId) async {
    try {
      final snap = await _db
          .collection(AdminCollections.adminAuditLogs)
          .where('action', isEqualTo: action)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      if (orgId == null || orgId.isEmpty) return snap.docs.length;
      return snap.docs.where((d) {
        final meta = d.data()['metadata'];
        return meta is Map && meta['organizationId'] == orgId;
      }).length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<NamedCount>> _topCollectionCounts(String? orgId) async {
    final collections = <(String, String)>[
      ('users', AdminCollections.users),
      ('matches', AdminCollections.matches),
      ('teams', AdminCollections.teams),
      ('tournaments', AdminCollections.tournaments),
      ('grounds', AdminCollections.grounds),
      ('notifications', AdminCollections.adminNotificationCampaigns),
    ];
    final results = <NamedCount>[];
    for (final c in collections) {
      final n = await _count(
        _scoped(_db.collection(c.$2), orgId),
      );
      results.add(NamedCount(name: c.$1, count: n));
    }
    results.sort((a, b) => b.count.compareTo(a.count));
    return results;
  }

  Future<List<HealthTimelineEvent>> _fetchTimeline(String? orgId) async {
    try {
      final snap = await _db
          .collection(AdminCollections.adminAuditLogs)
          .orderBy('timestamp', descending: true)
          .limit(40)
          .get();
      final events = <HealthTimelineEvent>[];
      for (final d in snap.docs) {
        final e = AdminAuditLogEntry.fromMap(d.id, d.data());
        if (orgId != null &&
            orgId.isNotEmpty &&
            e.metadata['organizationId'] != orgId) {
          continue;
        }
        final a = e.action.toLowerCase();
        final isHealth = a.contains('maintenance') ||
            a.contains('feature_flag') ||
            a.contains('failed') ||
            a.contains('settings') ||
            a.contains('app_version') ||
            a.contains('security') ||
            a.startsWith('auth.');
        if (!isHealth) continue;
        events.add(
          HealthTimelineEvent(
            id: e.id,
            title: e.action.replaceAll('.', ' › ').replaceAll('_', ' '),
            timestamp: e.timestamp,
            severity: _severityFromAction(a),
            detail: e.reason ?? e.actorEmail,
          ),
        );
        if (events.length >= 20) break;
      }
      return events;
    } catch (_) {
      return const [];
    }
  }

  Future<List<MonitoringErrorItem>> _fetchErrors(String? orgId) async {
    try {
      final snap = await _db
          .collection(AdminCollections.adminAuditLogs)
          .orderBy('timestamp', descending: true)
          .limit(60)
          .get();
      final errors = <MonitoringErrorItem>[];
      for (final d in snap.docs) {
        final e = AdminAuditLogEntry.fromMap(d.id, d.data());
        if (orgId != null &&
            orgId.isNotEmpty &&
            e.metadata['organizationId'] != orgId) {
          continue;
        }
        final a = e.action.toLowerCase();
        if (!a.contains('failed') &&
            !a.contains('error') &&
            !a.contains('blocked') &&
            !a.contains('suspicious') &&
            e.metadata['severity'] != 'critical' &&
            e.metadata['severity'] != 'high') {
          continue;
        }
        errors.add(
          MonitoringErrorItem(
            id: e.id,
            title: e.action.replaceAll('.', ' › ').replaceAll('_', ' '),
            module: (e.metadata['module'] ?? e.metadata['entity'] ?? 'system')
                .toString(),
            severity: _severityFromAction(a),
            timestamp: e.timestamp,
            status: 'Open',
            detail: e.reason ?? '',
          ),
        );
        if (errors.length >= 25) break;
      }
      return errors;
    } catch (_) {
      return const [];
    }
  }

  MonitoringSeverity _severityFromAction(String a) {
    if (a.contains('critical') ||
        a.contains('banned') ||
        a.contains('blocked') ||
        a.contains('suspicious')) {
      return MonitoringSeverity.critical;
    }
    if (a.contains('failed') || a.contains('error')) {
      return MonitoringSeverity.high;
    }
    if (a.contains('warning') || a.contains('maintenance.started')) {
      return MonitoringSeverity.warning;
    }
    return MonitoringSeverity.info;
  }

  List<ServiceStatusItem> _buildServices({
    required bool firestoreOk,
    required bool scoped,
  }) {
    final now = DateTime.now();
    return [
      for (final id in FirebaseServiceId.values)
        ServiceStatusItem(
          id: id,
          label: id.label,
          health: switch (id) {
            FirebaseServiceId.firestore =>
              firestoreOk ? PlatformServiceHealth.healthy : PlatformServiceHealth.warning,
            FirebaseServiceId.authentication => PlatformServiceHealth.unknown,
            FirebaseServiceId.hosting => PlatformServiceHealth.unknown,
            FirebaseServiceId.cloudFunctions ||
            FirebaseServiceId.storage ||
            FirebaseServiceId.messaging ||
            FirebaseServiceId.analytics ||
            FirebaseServiceId.remoteConfig ||
            FirebaseServiceId.appCheck ||
            FirebaseServiceId.performance =>
              PlatformServiceHealth.unknown,
          },
          note: switch (id) {
            FirebaseServiceId.firestore =>
              'Probe via count() — no secrets exposed',
            FirebaseServiceId.hosting =>
              'Hosting health is not polled from this panel',
            FirebaseServiceId.cloudFunctions ||
            FirebaseServiceId.performance ||
            FirebaseServiceId.analytics =>
              'Ready for Cloud Monitoring / Crashlytics integration',
            _ => 'Status mirror — configuration never modified',
          },
          lastChecked: now,
        ),
    ];
  }

  PlatformServiceHealth _derivePlatformHealth(List<ServiceStatusItem> services) {
    if (services.any((s) => s.health == PlatformServiceHealth.critical)) {
      return PlatformServiceHealth.critical;
    }
    if (services.any((s) => s.health == PlatformServiceHealth.offline)) {
      return PlatformServiceHealth.offline;
    }
    if (services.any((s) => s.health == PlatformServiceHealth.warning)) {
      return PlatformServiceHealth.warning;
    }
    if (services.any((s) => s.health == PlatformServiceHealth.healthy)) {
      return PlatformServiceHealth.healthy;
    }
    return PlatformServiceHealth.unknown;
  }


  Future<List<PlatformDailyStat>> _fetchGrowthSeries({
    required PlatformDailyStat today,
  }) async {
    try {
      final snap = await _db
          .collection(AdminCollections.adminPlatformDailyStats)
          .orderBy('date')
          .limitToLast(30)
          .get();
      final history = [
        for (final d in snap.docs) PlatformDailyStat.fromMap(d.id, d.data()),
      ];
      return PlatformDailyStat.mergeLiveToday(history: history, today: today);
    } catch (_) {
      return [today];
    }
  }
}

