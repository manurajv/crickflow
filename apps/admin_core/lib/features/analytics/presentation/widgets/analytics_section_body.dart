import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../models/analytics_enums.dart';
import '../../models/analytics_models.dart';
import 'analytics_charts.dart';
import 'analytics_kpi_card.dart';

class AnalyticsSectionBody extends StatelessWidget {
  const AnalyticsSectionBody({
    super.key,
    required this.section,
    required this.snapshot,
    required this.reportKind,
    required this.onReportKindChanged,
    required this.onExportCsv,
    required this.onExportStub,
  });

  final AnalyticsHubSection section;
  final AnalyticsSnapshot snapshot;
  final AnalyticsReportKind reportKind;
  final ValueChanged<AnalyticsReportKind> onReportKindChanged;
  final VoidCallback onExportCsv;
  final ValueChanged<AnalyticsExportFormat> onExportStub;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      AnalyticsHubSection.overview => _Overview(snapshot: snapshot),
      AnalyticsHubSection.users => _Users(snapshot: snapshot),
      AnalyticsHubSection.matches => _Matches(snapshot: snapshot),
      AnalyticsHubSection.tournaments => _Tournaments(snapshot: snapshot),
      AnalyticsHubSection.teams => _Teams(snapshot: snapshot),
      AnalyticsHubSection.players => _Players(snapshot: snapshot),
      AnalyticsHubSection.streaming => _Streaming(snapshot: snapshot),
      AnalyticsHubSection.community => _Community(snapshot: snapshot),
      AnalyticsHubSection.advertisements => _Ads(snapshot: snapshot),
      AnalyticsHubSection.revenue => _Revenue(snapshot: snapshot),
      AnalyticsHubSection.reports => _Reports(
          snapshot: snapshot,
          kind: reportKind,
          onKindChanged: onReportKindChanged,
        ),
      AnalyticsHubSection.exportCenter => _Export(
          onExportCsv: onExportCsv,
          onExportStub: onExportStub,
        ),
    };
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.snapshot});
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnalyticsRealtimeStrip(realtime: snapshot.realtime),
        const SizedBox(height: 16),
        AnalyticsKpiGrid(kpis: snapshot.overviewKpis),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 1000;
            final charts = [
              AnalyticsLineChartCard(
                title: 'Daily active users (sample)',
                points: snapshot.dauSeries,
              ),
              AnalyticsLineChartCard(
                title: 'Matches per day',
                points: snapshot.matchesPerDaySeries,
                color: const Color(0xFF26A69A),
              ),
              AnalyticsLineChartCard(
                title: 'Live streams per day',
                points: snapshot.streamsPerDaySeries,
                color: const Color(0xFFFF7043),
              ),
              AnalyticsLineChartCard(
                title: 'Community activity',
                points: snapshot.communityActivitySeries,
                color: const Color(0xFF7E57C2),
              ),
            ];
            if (wide) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: charts[0]),
                      const SizedBox(width: 12),
                      Expanded(child: charts[1]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: charts[2]),
                      const SizedBox(width: 12),
                      Expanded(child: charts[3]),
                    ],
                  ),
                ],
              );
            }
            return Column(
              children: [
                for (final ch in charts) ...[
                  ch,
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
        if (snapshot.dataQualityNote != null) ...[
          const SizedBox(height: 8),
          Text(
            snapshot.dataQualityNote!,
            style: TextStyle(
              fontSize: 12,
              color: context.adminColors.textMuted,
            ),
          ),
        ],
        if (snapshot.fromCache)
          Text(
            'Served from short-lived cache',
            style: TextStyle(
              fontSize: 11,
              color: context.adminColors.textMuted,
            ),
          ),
      ],
    );
  }
}

class _Users extends StatelessWidget {
  const _Users({required this.snapshot});
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final u = snapshot.userAnalytics;
    return Column(
      children: [
        AnalyticsKpiGrid(kpis: u.kpis),
        const SizedBox(height: 16),
        AnalyticsLineChartCard(title: 'User growth', points: u.growthSeries),
        const SizedBox(height: 12),
        AnalyticsLineChartCard(
          title: 'Monthly active (bucketed sample)',
          points: snapshot.mauSeries,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final left = Column(
              children: [
                AnalyticsBarChartCard(title: 'Countries', values: u.byCountry),
                const SizedBox(height: 12),
                AnalyticsBarChartCard(title: 'Cities', values: u.byCity),
              ],
            );
            final right = Column(
              children: [
                AnalyticsNamedListCard(
                  title: 'Login methods',
                  values: u.loginMethods,
                ),
                const SizedBox(height: 12),
                AnalyticsNamedListCard(
                  title: 'Platforms / devices',
                  values: u.platforms,
                ),
                const SizedBox(height: 12),
                AnalyticsNamedListCard(
                  title: 'Most followed players',
                  values: u.mostFollowedPlayers,
                ),
                const SizedBox(height: 12),
                AnalyticsNamedListCard(
                  title: 'Most followed teams',
                  values: u.mostFollowedTeams,
                ),
              ],
            );
            if (!wide) {
              return Column(children: [left, const SizedBox(height: 12), right]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 12),
                Expanded(child: right),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Matches extends StatelessWidget {
  const _Matches({required this.snapshot});
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final m = snapshot.matchAnalytics;
    return Column(
      children: [
        AnalyticsKpiGrid(kpis: m.kpis),
        const SizedBox(height: 16),
        AnalyticsLineChartCard(title: 'Matches created', points: m.series),
        const SizedBox(height: 12),
        AnalyticsBarChartCard(title: 'By status (sample)', values: m.byStatus),
      ],
    );
  }
}

class _Tournaments extends StatelessWidget {
  const _Tournaments({required this.snapshot});
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = snapshot.tournamentAnalytics;
    return Column(
      children: [
        AnalyticsKpiGrid(kpis: t.kpis),
        const SizedBox(height: 16),
        AnalyticsLineChartCard(
          title: 'Tournament growth',
          points: t.growthSeries,
        ),
        const SizedBox(height: 12),
        AnalyticsNamedListCard(
          title: 'Most popular / largest (by team count)',
          values: t.topTournaments,
        ),
      ],
    );
  }
}

class _Teams extends StatelessWidget {
  const _Teams({required this.snapshot});
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = snapshot.teamAnalytics;
    return Column(
      children: [
        AnalyticsKpiGrid(kpis: t.kpis),
        const SizedBox(height: 16),
        AnalyticsNamedListCard(
          title: 'Most active (matches played)',
          values: t.mostActive,
        ),
        const SizedBox(height: 12),
        AnalyticsNamedListCard(
          title: 'Most followed',
          values: t.mostFollowed,
        ),
        const SizedBox(height: 12),
        AnalyticsNamedListCard(
          title: 'Highest winning',
          values: t.highestWinning,
        ),
      ],
    );
  }
}

class _Players extends StatelessWidget {
  const _Players({required this.snapshot});
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final p = snapshot.playerAnalytics;
    return Column(
      children: [
        AnalyticsKpiGrid(kpis: p.kpis),
        const SizedBox(height: 8),
        CfCard(
          child: Text(
            p.note,
            style: TextStyle(
              fontSize: 12,
              color: context.adminColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnalyticsNamedListCard(
          title: 'Top run scorers (profile fields)',
          values: p.topRunScorers,
        ),
        const SizedBox(height: 12),
        AnalyticsNamedListCard(
          title: 'Top wicket takers',
          values: p.topWicketTakers,
        ),
        const SizedBox(height: 12),
        AnalyticsNamedListCard(
          title: 'Most followed players',
          values: p.mostFollowed,
        ),
      ],
    );
  }
}

class _Streaming extends StatelessWidget {
  const _Streaming({required this.snapshot});
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot.streamingAnalytics;
    return Column(
      children: [
        AnalyticsKpiGrid(kpis: s.kpis),
        const SizedBox(height: 16),
        AnalyticsLineChartCard(
          title: 'Streaming activity',
          points: s.series,
        ),
        const SizedBox(height: 12),
        AnalyticsBarChartCard(
          title: 'Platforms (YouTube / Facebook / RTMP)',
          values: s.byPlatform,
        ),
      ],
    );
  }
}

class _Community extends StatelessWidget {
  const _Community({required this.snapshot});
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final c = snapshot.communityAnalytics;
    return Column(
      children: [
        AnalyticsKpiGrid(kpis: c.kpis),
        const SizedBox(height: 16),
        AnalyticsLineChartCard(
          title: 'Community activity',
          points: c.series,
        ),
        const SizedBox(height: 12),
        AnalyticsNamedListCard(
          title: 'Most popular posts (likes)',
          values: c.topPosts,
        ),
      ],
    );
  }
}

class _Ads extends StatelessWidget {
  const _Ads({required this.snapshot});
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final a = snapshot.adAnalytics;
    return Column(
      children: [
        AnalyticsKpiGrid(kpis: a.kpis),
        const SizedBox(height: 8),
        CfCard(
          child: Text(
            a.note,
            style: TextStyle(
              fontSize: 12,
              color: context.adminColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnalyticsLineChartCard(
          title: 'Advertisement performance (campaign volume)',
          points: a.series,
        ),
        const SizedBox(height: 12),
        AnalyticsNamedListCard(
          title: 'Top placements',
          values: a.topPlacements,
        ),
        const SizedBox(height: 12),
        AnalyticsNamedListCard(
          title: 'Top advertisers',
          values: a.topAdvertisers,
        ),
      ],
    );
  }
}

class _Revenue extends StatelessWidget {
  const _Revenue({required this.snapshot});
  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final r = snapshot.revenueAnalytics;
    return Column(
      children: [
        AnalyticsKpiGrid(kpis: r.kpis),
        const SizedBox(height: 8),
        CfCard(
          child: Text(
            r.note,
            style: TextStyle(
              fontSize: 12,
              color: context.adminColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnalyticsBarChartCard(
          title: 'Revenue breakdown (estimated)',
          values: r.breakdown,
        ),
        const SizedBox(height: 12),
        AnalyticsLineChartCard(
          title: 'Estimated trend',
          points: r.series,
        ),
      ],
    );
  }
}

class _Reports extends StatelessWidget {
  const _Reports({
    required this.snapshot,
    required this.kind,
    required this.onKindChanged,
  });

  final AnalyticsSnapshot snapshot;
  final AnalyticsReportKind kind;
  final ValueChanged<AnalyticsReportKind> onKindChanged;

  @override
  Widget build(BuildContext context) {
    final lines = [
      'Scope: ${snapshot.scoped ? 'Organization ${snapshot.organizationId}' : 'Platform-wide'}',
      'Users: ${_kpiValue(snapshot.overviewKpis, 'total_users')}',
      'Live matches: ${snapshot.realtime.matchesLive}',
      'Streams: ${snapshot.realtime.streamsRunning}',
      'Community posts: ${_kpiValue(snapshot.overviewKpis, 'community_posts')}',
      'Generated: ${snapshot.generatedAt.toIso8601String()}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final k in AnalyticsReportKind.values)
              ChoiceChip(
                label: Text(k.label),
                selected: kind == k,
                onSelected: (_) => onKindChanged(k),
              ),
          ],
        ),
        const SizedBox(height: 16),
        CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kind.label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line),
                ),
              const SizedBox(height: 8),
              Text(
                'Use Export Center to download CSV. PDF / Excel / email '
                'scheduling are prepared for later.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.adminColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnalyticsKpiGrid(kpis: snapshot.overviewKpis.take(6).toList()),
      ],
    );
  }
}

class _Export extends StatelessWidget {
  const _Export({
    required this.onExportCsv,
    required this.onExportStub,
  });

  final VoidCallback onExportCsv;
  final ValueChanged<AnalyticsExportFormat> onExportStub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export Center',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Download analytics snapshots. Scheduled email reports are '
                'future-ready (no mailer wired yet).',
                style: TextStyle(color: context.adminColors.textMuted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onExportCsv,
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Export CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onExportStub(AnalyticsExportFormat.excel),
                    icon: const Icon(Icons.grid_on_outlined),
                    label: const Text('Excel (soon)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onExportStub(AnalyticsExportFormat.pdf),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF (soon)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Scheduled / email reports — architecture ready',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.schedule_send_outlined),
                    label: const Text('Schedule (soon)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _kpiValue(List<AnalyticsKpi> kpis, String id) {
  for (final k in kpis) {
    if (k.id == id) return k.formattedValue;
  }
  return '—';
}
