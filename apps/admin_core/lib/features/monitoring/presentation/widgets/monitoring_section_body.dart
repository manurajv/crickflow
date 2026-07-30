import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../models/monitoring_enums.dart';
import '../../models/monitoring_models.dart';
import 'monitoring_health.dart';
import 'monitoring_kpi_cards.dart';

class MonitoringSectionBody extends StatelessWidget {
  const MonitoringSectionBody({
    super.key,
    required this.section,
    required this.snapshot,
    required this.filteredErrors,
    required this.searchQuery,
  });

  final MonitoringHubSection section;
  final MonitoringSnapshot snapshot;
  final List<MonitoringErrorItem> filteredErrors;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      MonitoringHubSection.overview => _Overview(snapshot: snapshot),
      MonitoringHubSection.firebaseServices =>
        _Services(services: snapshot.services),
      MonitoringHubSection.liveStatus => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MonitoringLiveStatusBar(bar: snapshot.liveBar),
            const SizedBox(height: 12),
            MonitoringSectionCard(
              title: 'Live platform pulse',
              subtitle: snapshot.isOrgScoped
                  ? 'Organization-scoped probes only'
                  : 'Platform-wide probes (no secrets)',
              child: MonitoringMetricGrid(
                items: [
                  (
                    'Platform',
                    snapshot.platformHealth.label,
                    null,
                  ),
                  (
                    'Live matches',
                    '${snapshot.liveBar.liveMatches}',
                    null,
                  ),
                  (
                    'Live streams',
                    '${snapshot.liveBar.liveStreams}',
                    null,
                  ),
                  (
                    'Open errors',
                    '${snapshot.liveBar.errors}',
                    null,
                  ),
                ],
              ),
            ),
          ],
        ),
      MonitoringHubSection.firestore => _Firestore(m: snapshot.firestore),
      MonitoringHubSection.authentication => _Auth(m: snapshot.auth),
      MonitoringHubSection.cloudFunctions =>
        _Functions(items: snapshot.functions, query: searchQuery),
      MonitoringHubSection.storage => _Storage(m: snapshot.storage),
      MonitoringHubSection.hosting => _Hosting(m: snapshot.hosting),
      MonitoringHubSection.pushNotifications => _Fcm(m: snapshot.fcm),
      MonitoringHubSection.liveStreaming => _Streaming(m: snapshot.streaming),
      MonitoringHubSection.database => _Database(m: snapshot.database),
      MonitoringHubSection.performance => _Performance(m: snapshot.performance),
      MonitoringHubSection.errors => _Errors(items: filteredErrors),
      MonitoringHubSection.scheduledJobs =>
        _Scheduled(items: snapshot.scheduledJobs, query: searchQuery),
      MonitoringHubSection.backgroundTasks =>
        _Background(items: snapshot.backgroundTasks),
      MonitoringHubSection.healthTimeline =>
        _Timeline(items: snapshot.timeline),
    };
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.snapshot});
  final MonitoringSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonitoringLiveStatusBar(bar: snapshot.liveBar),
        const SizedBox(height: 16),
        MonitoringKpiGrid(kpis: snapshot.overview),
        const SizedBox(height: 16),
        MonitoringSectionCard(
          title: 'Firebase services at a glance',
          child: _ServiceGrid(services: snapshot.services.take(6).toList()),
        ),
        const SizedBox(height: 12),
        MonitoringSectionCard(
          title: 'Recent health events',
          subtitle: 'Newest first · sourced from admin audit trail',
          child: snapshot.timeline.isEmpty
              ? const Text('No recent health events')
              : Column(
                  children: [
                    for (final e in snapshot.timeline.take(5))
                      _TimelineTile(event: e),
                  ],
                ),
        ),
        if (snapshot.generatedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'Generated ${snapshot.generatedAt} · TTL cache avoids expensive listeners',
            style: TextStyle(
              fontSize: 11,
              color: context.adminColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _Services extends StatelessWidget {
  const _Services({required this.services});
  final List<ServiceStatusItem> services;

  @override
  Widget build(BuildContext context) {
    return MonitoringSectionCard(
      title: 'Platform status',
      subtitle: 'Healthy · Warning · Offline · Unknown',
      child: _ServiceGrid(services: services),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.services});
  final List<ServiceStatusItem> services;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100
            ? 3
            : c.maxWidth >= 700
                ? 2
                : 1;
        const spacing = 10.0;
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final s in services)
              SizedBox(
                width: w,
                child: Material(
                  color: context.adminColors.background,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: context.adminColors.border),
                    ),
                    leading: HealthDot(health: s.health),
                    title: Text(s.label),
                    subtitle: Text(
                      s.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: HealthBadge(health: s.health),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Firestore extends StatelessWidget {
  const _Firestore({required this.m});
  final FirestoreMetrics m;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MonitoringMetricGrid(
          items: [
            ('Reads (est.)', '${m.reads}', 'Sample-based'),
            ('Writes', '${m.writes}', 'Usage API future'),
            ('Deletes', '${m.deletes}', null),
            ('Queries', '${m.queries}', null),
            ('Active connections', '${m.activeConnections}', 'Future'),
            ('Avg response', '${m.avgResponseMs}ms', 'Probe latency'),
            ('Slow queries', '—', 'Future'),
            ('Realtime', 'OK', 'Listener-light design'),
          ],
        ),
        const SizedBox(height: 12),
        MonitoringSectionCard(
          title: 'Top collections',
          subtitle: 'Storage growth wiring prepared for Cloud Monitoring',
          child: m.topCollections.isEmpty
              ? const Text('No collection samples')
              : Column(
                  children: [
                    for (final c in m.topCollections)
                      Material(
                        child: ListTile(
                          title: Text(c.name),
                          trailing: Text(
                            '${c.count}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Auth extends StatelessWidget {
  const _Auth({required this.m});
  final AuthMetrics m;

  @override
  Widget build(BuildContext context) {
    return MonitoringMetricGrid(
      items: [
        ('Logged-in (est.)', '${m.loggedInEstimate}', 'From today logins'),
        ("Today's logins", '${m.loginsToday}', null),
        ('Failed logins', '${m.failedLogins}', null),
        ('Password resets', '${m.passwordResets}', null),
        ('Google sign-ins', '${m.googleSignIns}', 'Future Identity Toolkit'),
        ('Email sign-ins', '${m.emailSignIns}', null),
        ('Blocked logins', '${m.blockedLogins}', null),
        ('Suspicious logins', '${m.suspiciousLogins}', null),
      ],
    );
  }
}

class _Functions extends StatelessWidget {
  const _Functions({required this.items, required this.query});
  final List<CloudFunctionStatus> items;
  final String query;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final list = q.isEmpty
        ? items
        : items.where((f) => f.name.toLowerCase().contains(q)).toList();
    if (list.isEmpty) {
      return const CfEmptyState(
        title: 'No functions matched',
        message: 'Architecture ready for Cloud Functions metrics.',
        icon: Icons.functions,
      );
    }
    return MonitoringSectionCard(
      title: 'Cloud Functions',
      subtitle: 'Execution metrics reserved for future GCP Monitoring',
      child: Column(
        children: [
          for (final f in list)
            Material(
              child: ListTile(
                leading: HealthDot(health: f.status),
                title: Text(f.name),
                subtitle: Text(
                  'Exec ${f.executions} · avg ${f.avgDurationMs}ms · '
                  'fail ${f.failures} · timeout ${f.timeouts} · '
                  'mem ${f.memoryMb}MB',
                ),
                trailing: HealthBadge(health: f.status),
              ),
            ),
        ],
      ),
    );
  }
}

class _Storage extends StatelessWidget {
  const _Storage({required this.m});
  final StorageMetrics m;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MonitoringMetricGrid(
          items: [
            ('Total storage', m.totalLabel, null),
            ('Images', '${m.images}', null),
            ('Videos', '${m.videos}', null),
            ('Documents', '${m.documents}', null),
            ('Broadcast assets', '${m.broadcastAssets}', null),
            ('Profile pictures', '${m.profilePictures}', null),
            ('Tournament posters', '${m.tournamentPosters}', null),
            ('Ground images', '${m.groundImages}', null),
            ('Available space', m.availableLabel, null),
          ],
        ),
        const SizedBox(height: 12),
        MonitoringGrowthChart(
          title: 'Storage growth (placeholder)',
          points: m.growthPoints,
        ),
      ],
    );
  }
}

class _Hosting extends StatelessWidget {
  const _Hosting({required this.m});
  final HostingMetrics m;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonitoringMetricGrid(
          items: [
            ('Hosting status', m.status.label, null),
            ('Current deployment', m.currentDeployment, 'Read-only'),
            ('Environment', m.environment.name, null),
            (
              'Last deployment',
              m.lastDeployment?.toIso8601String() ?? '—',
              'Never modified by this module',
            ),
            ('Firebase Hosting', 'Healthy', 'Status mirror'),
            ('SSL', 'Healthy', null),
          ],
        ),
        const SizedBox(height: 12),
        MonitoringSectionCard(
          title: 'Custom domains',
          subtitle: 'Display only — deployments are never triggered',
          child: Column(
            children: [
              for (final d in m.domains)
                Material(
                  child: ListTile(
                    leading: HealthDot(health: d.status),
                    title: Text(d.domain),
                    subtitle: Text(d.note),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        HealthBadge(health: d.status),
                        const SizedBox(height: 4),
                        Text(
                          'SSL ${d.ssl.label}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.adminColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Material(
                child: ListTile(
                  leading: HealthDot(health: PlatformServiceHealth.unknown),
                  title: const Text('Future domains'),
                  subtitle: const Text('Reserved for additional hostnames'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fcm extends StatelessWidget {
  const _Fcm({required this.m});
  final FcmMetrics m;

  @override
  Widget build(BuildContext context) {
    return MonitoringMetricGrid(
      items: [
        ('Notifications sent', '${m.sentToday}', 'Campaigns sample'),
        ('Delivery rate', '${m.deliveryRate.toStringAsFixed(0)}%', 'Future FCM'),
        ('Failures', '${m.failures}', null),
        ('Pending', '${m.pending}', null),
        ('Avg delivery time', '${m.avgDeliveryMs}ms', 'Future'),
      ],
    );
  }
}

class _Streaming extends StatelessWidget {
  const _Streaming({required this.m});
  final StreamingHealthMetrics m;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MonitoringSectionCard(
          title: 'Live streaming health',
          subtitle: 'Monitoring only — stream control is never available here',
          child: HealthBadge(health: m.health),
        ),
        const SizedBox(height: 12),
        MonitoringMetricGrid(
          items: [
            ('Current live streams', '${m.liveStreams}', null),
            ('YouTube streams', '${m.youtube}', 'Estimated mix'),
            ('Facebook streams', '${m.facebook}', 'Estimated mix'),
            ('External RTMP', '${m.externalRtmp}', 'Estimated mix'),
            ('Broadcast sessions', '${m.broadcastSessions}', null),
            ('Reconnect events', '${m.reconnectEvents}', 'Future'),
            ('Avg stream duration', '${m.avgDurationMin} min', 'Future'),
            ('Connection failures', '${m.connectionFailures}', null),
          ],
        ),
      ],
    );
  }
}

class _Database extends StatelessWidget {
  const _Database({required this.m});
  final DatabaseMetrics m;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MonitoringMetricGrid(
          items: [
            ('Collections', '${m.collections}', null),
            ('Documents (est.)', '${m.documentsEstimate}', null),
            ('Estimated size', m.estimatedSizeLabel, null),
            ('Read usage', '${m.readUsage}', null),
            ('Write usage', '${m.writeUsage}', null),
            ('Delete usage', '${m.deleteUsage}', null),
          ],
        ),
        const SizedBox(height: 12),
        MonitoringGrowthChart(
          title: 'Database growth (placeholder)',
          points: m.growthPoints,
        ),
      ],
    );
  }
}

class _Performance extends StatelessWidget {
  const _Performance({required this.m});
  final PerformanceMetrics m;

  @override
  Widget build(BuildContext context) {
    return MonitoringMetricGrid(
      items: [
        ('Average API response', '${m.avgApiResponseMs}ms', 'Probe'),
        ('Firestore response', '${m.firestoreResponseMs}ms', null),
        (
          'Cloud Function duration',
          '${m.cloudFunctionDurationMs}ms',
          'Future',
        ),
        ('App startup', '—', 'Future'),
        ('Realtime latency', '${m.realtimeLatencyMs}ms', null),
        ('Average query time', '${m.avgQueryMs}ms', null),
      ],
    );
  }
}

class _Errors extends StatelessWidget {
  const _Errors({required this.items});
  final List<MonitoringErrorItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const CfEmptyState(
        title: 'No matching errors',
        message: 'Adjust filters or wait for new audit-derived incidents.',
        icon: Icons.bug_report_outlined,
      );
    }
    return MonitoringSectionCard(
      title: 'Error monitoring',
      subtitle: 'Severity · Timestamp · Module · Status',
      child: Column(
        children: [
          for (final e in items)
            Material(
              child: ListTile(
                leading: Icon(
                  Icons.error_outline,
                  color: monitoringSeverityColor(context, e.severity),
                ),
                title: Text(e.title),
                subtitle: Text(
                  '${e.module} · ${e.severity.label} · ${e.status}\n'
                  '${e.timestamp}'
                  '${e.detail.isEmpty ? '' : '\n${e.detail}'}',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _Scheduled extends StatelessWidget {
  const _Scheduled({required this.items, required this.query});
  final List<ScheduledJobItem> items;
  final String query;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final list = q.isEmpty
        ? items
        : items
            .where((j) => j.kind.label.toLowerCase().contains(q))
            .toList();
    return MonitoringSectionCard(
      title: 'Scheduled tasks',
      subtitle: 'Architecture only — jobs are not implemented',
      child: Column(
        children: [
          for (final j in list)
            Material(
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(j.kind.label),
                subtitle: Text(j.note),
                trailing: Text(j.status.name),
              ),
            ),
        ],
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.items});
  final List<BackgroundTaskItem> items;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final s in BackgroundTaskStatus.values)
        s: items.where((t) => t.status == s).length,
    };
    return Column(
      children: [
        MonitoringMetricGrid(
          items: [
            for (final e in counts.entries)
              (e.key.name, '${e.value}', 'Queue monitoring future'),
          ],
        ),
        const SizedBox(height: 12),
        MonitoringSectionCard(
          title: 'Background tasks',
          child: items.isEmpty
              ? const Text('No queue workers registered yet')
              : Column(
                  children: [
                    for (final t in items)
                      Material(
                        child: ListTile(
                          title: Text(t.name),
                          trailing: Text(t.status.name),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.items});
  final List<HealthTimelineEvent> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const CfEmptyState(
        title: 'No health timeline events',
        message:
            'Deployments, maintenance, and critical warnings appear here when logged.',
        icon: Icons.timeline,
      );
    }
    return MonitoringSectionCard(
      title: 'Platform health timeline',
      subtitle: 'Newest first',
      child: Column(
        children: [
          for (final e in items) _TimelineTile(event: e),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});
  final HealthTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ListTile(
        leading: Icon(
          Icons.circle,
          size: 12,
          color: monitoringSeverityColor(context, event.severity),
        ),
        title: Text(event.title),
        subtitle: Text(
          '${event.timestamp}'
          '${event.detail.isEmpty ? '' : ' · ${event.detail}'}',
        ),
        trailing: Text(
          event.severity.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: monitoringSeverityColor(context, event.severity),
          ),
        ),
      ),
    );
  }
}
