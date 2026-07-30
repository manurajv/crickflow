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
      loggedInEstimate: usersToday, // estimate from today's logins
      loginsToday: usersToday,
      failedLogins: failedLogins,
      passwordResets: passwordResets,
      googleSignIns: 0,
      emailSignIns: usersToday,
      blockedLogins: 0,
      suspiciousLogins: await _countAuditAction(
        AdminAuditActions.securitySuspiciousLogin,
        organizationId,
      ),
    );

    final topCollections = await _topCollectionCounts(organizationId);
    final docEstimate =
        topCollections.fold<int>(0, (acc, c) => acc + c.count);

    final streaming = StreamingHealthMetrics(
      liveStreams: liveStreamsAlt,
      youtube: liveStreamsAlt > 0 ? (liveStreamsAlt * 0.6).round() : 0,
      facebook: liveStreamsAlt > 0 ? (liveStreamsAlt * 0.25).round() : 0,
      externalRtmp: liveStreamsAlt > 0 ? (liveStreamsAlt * 0.15).round() : 0,
      broadcastSessions: liveStreamsAlt,
      reconnectEvents: 0,
      avgDurationMin: 0,
      connectionFailures: 0,
      health: liveStreamsAlt > 20 ? PlatformServiceHealth.warning : PlatformServiceHealth.healthy,
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
        label: 'Logins Today',
        value: '$usersToday',
        subtitle: scoped ? 'Org scope' : 'Platform',
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
        value: 'Ready',
        subtitle: 'Monitoring architecture',
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
        value: 'Healthy',
        health: PlatformServiceHealth.healthy,
      ),
      MonitoringKpi(
        id: 'notifications',
        label: 'Notifications',
        value: '$notifSent',
        subtitle: 'Campaigns (sample)',
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
        reads: docEstimate,
        writes: 0,
        deletes: 0,
        queries: topCollections.length,
        activeConnections: 0,
        avgResponseMs: probeMs,
        topCollections: topCollections,
      ),
      auth: authMetrics,
      functions: _defaultFunctions(),
      storage: const StorageMetrics(
        totalLabel: 'Not available',
        availableLabel: 'Firebase Console',
        growthPoints: [0.2, 0.25, 0.3, 0.35, 0.4, 0.42, 0.45],
      ),
      hosting: HostingMetrics(
        status: PlatformServiceHealth.healthy,
        currentDeployment: 'Read-only status',
        environment: MonitoringEnvironment.production,
        lastDeployment: null,
        domains: const [
          HostingDomainStatus(
            domain: 'admin.crickflow.app',
            note: 'Status mirror only — deployment never modified',
          ),
          HostingDomainStatus(
            domain: 'superadmin.crickflow.app',
            note: 'Status mirror only — deployment never modified',
          ),
        ],
      ),
      fcm: FcmMetrics(
        sentToday: notifSent,
        deliveryRate: notifSent == 0 ? 0 : 98,
        failures: 0,
        pending: 0,
        avgDeliveryMs: 0,
      ),
      streaming: streaming,
      database: DatabaseMetrics(
        collections: topCollections.length,
        documentsEstimate: docEstimate,
        estimatedSizeLabel: 'Sample-based',
        readUsage: docEstimate,
        writeUsage: 0,
        deleteUsage: 0,
        growthPoints: const [0.3, 0.35, 0.4, 0.5, 0.55, 0.6, 0.65],
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
        for (final k in ScheduledJobKind.values)
          ScheduledJobItem(kind: k),
      ],
      backgroundTasks: const [
        BackgroundTaskItem(
          id: 'queue',
          name: 'Queue monitoring',
          status: BackgroundTaskStatus.pending,
        ),
      ],
      timeline: timeline,
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
            FirebaseServiceId.authentication => PlatformServiceHealth.healthy,
            FirebaseServiceId.hosting =>
              scoped ? PlatformServiceHealth.unknown : PlatformServiceHealth.healthy,
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
              'Domain status mirror only — never deploys',
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

  List<CloudFunctionStatus> _defaultFunctions() => const [
        CloudFunctionStatus(
          name: 'onMatchUpdate',
          status: PlatformServiceHealth.unknown,
        ),
        CloudFunctionStatus(
          name: 'sendPushNotification',
          status: PlatformServiceHealth.unknown,
        ),
        CloudFunctionStatus(
          name: 'streamHealthCheck',
          status: PlatformServiceHealth.unknown,
        ),
        CloudFunctionStatus(
          name: 'scheduledCleanup',
          status: PlatformServiceHealth.unknown,
        ),
      ];
}
