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
        const SizedBox(height: 12),
        MonitoringGrowthChart(
          title: 'Users over time',
          points: [
            for (final row in snapshot.growth) row.users.toDouble(),
          ],
        ),
        const SizedBox(height: 12),
        MonitoringGrowthChart(
          title: 'Matches over time',
          points: [
            for (final row in snapshot.growth) row.matches.toDouble(),
          ],
        ),
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
            ('Reads', '—', 'Usage API not connected'),
            ('Writes', '—', 'Usage API not connected'),
            ('Deletes', '—', 'Usage API not connected'),
            ('Collections sampled', '${m.queries}', null),
            ('Active connections', '—', 'Not available'),
            ('Avg response', '${m.avgResponseMs}ms', 'Probe latency'),
            ('Slow queries', '—', 'Not available'),
            ('Realtime', m.avgResponseMs < 5000 ? 'Reachable' : 'Slow', 'Probe only'),
          ],
        ),
        const SizedBox(height: 12),
        MonitoringSectionCard(
          title: 'Top collections',
          subtitle: 'Live document counts from Firestore count() — not storage bytes',
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
        ('Logged-in users', '—', 'Auth user sessions are not counted here'),
        ('Admin logins today', '${m.loginsToday}', 'adminLoginSuccess audit rows'),
        ('Failed admin logins', '${m.failedLogins}', 'Audit logs'),
        ('Password reset requests', '${m.passwordResets}', 'Audit logs'),
        ('Google sign-ins', '—', 'Identity Toolkit is not connected'),
        ('Email sign-ins', '—', 'Identity Toolkit is not connected'),
        ('Blocked logins', '—', 'Not available'),
        ('Suspicious logins', '${m.suspiciousLogins}', 'Audit logs'),
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
        message: 'Cloud Function execution metrics are not connected. This panel does not invent statuses.',
        icon: Icons.functions,
      );
    }
    return MonitoringSectionCard(
      title: 'Cloud Functions',
      subtitle: 'Cloud Monitoring is not connected — no execution numbers are shown',
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
            ('Total storage', m.totalLabel, 'Firebase Usage API is not connected'),
            ('Images', '—', 'Not counted in this panel'),
            ('Videos', '—', 'Not counted in this panel'),
            ('Documents', '—', 'Not counted in this panel'),
            ('Broadcast assets', '—', 'Not counted in this panel'),
            ('Profile pictures', '—', 'Not counted in this panel'),
            ('Tournament posters', '—', 'Not counted in this panel'),
            ('Ground images', '—', 'Not counted in this panel'),
            ('Available space', m.availableLabel, null),
          ],
        ),
        const SizedBox(height: 12),
        MonitoringGrowthChart(
          title: 'Storage growth',
          points: const [],
          subtitle:
              'Storage byte growth is not available. Firebase Usage API is not connected.',
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
            ('Hosting status', 'Not polled', 'This panel does not probe Hosting'),
            ('Current deployment', m.currentDeployment, 'Read-only'),
            ('Environment', m.environment.name, 'This production project'),
            (
              'Last deployment',
              m.lastDeployment?.toIso8601String() ?? '—',
              'Never modified by this module',
            ),
            ('Firebase Hosting', 'Not polled', null),
            ('SSL', 'Not polled', null),
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
        ('Campaign documents', '${m.sentToday}', 'Not FCM delivery receipts'),
        ('Delivery rate', '—', 'FCM delivery stats are not connected'),
        ('Failures', '—', 'FCM delivery stats are not connected'),
        ('Pending', '—', 'FCM delivery stats are not connected'),
        ('Avg delivery time', '—', 'FCM delivery stats are not connected'),
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
            ('Current live streams', '${m.liveStreams}', 'matches.stream.status == live'),
            ('YouTube streams', '—', 'Provider breakdown is not stored'),
            ('Facebook streams', '—', 'Provider breakdown is not stored'),
            ('External RTMP', '—', 'Provider breakdown is not stored'),
            ('Broadcast sessions', '${m.broadcastSessions}', 'Same as live stream count'),
            ('Reconnect events', '—', 'Not recorded in this panel'),
            ('Avg stream duration', '—', 'Not recorded in this panel'),
            ('Connection failures', '—', 'Not recorded in this panel'),
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
            ('Collections sampled', '${m.collections}', null),
            ('Documents (sum of samples)', '${m.documentsEstimate}', 'count() totals, not usage'),
            ('Estimated size', '—', 'Storage size is not available'),
            ('Read usage', '—', 'Usage API is not connected'),
            ('Write usage', '—', 'Usage API is not connected'),
            ('Delete usage', '—', 'Usage API is not connected'),
          ],
        ),
        const SizedBox(height: 12),
        MonitoringGrowthChart(
          title: 'Tracked collection document counts',
          points: m.growthPoints,
          subtitle:
              'Sum of users, teams, matches, players, tournaments, grounds, and series. Not storage bytes.',
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
      subtitle: 'Documented job types — run state is not instrumented from this panel',
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
              (e.key.name, '${e.value}', 'No background task queue is connected'),
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
