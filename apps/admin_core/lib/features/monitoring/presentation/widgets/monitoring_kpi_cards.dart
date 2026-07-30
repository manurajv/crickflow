import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../models/monitoring_models.dart';
import 'monitoring_health.dart';

class MonitoringLiveStatusBar extends StatelessWidget {
  const MonitoringLiveStatusBar({super.key, required this.bar});

  final LiveStatusBarSnapshot bar;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final items = <(String, String, IconData)>[
      (
        'Platform ${bar.platformHealth.label}',
        '',
        Icons.monitor_heart_outlined,
      ),
      ('Live matches', '${bar.liveMatches}', Icons.sports_cricket),
      ('Streams', '${bar.liveStreams}', Icons.live_tv_outlined),
      ('Online (est.)', '${bar.onlineUsers}', Icons.people_outline),
      ('Errors', '${bar.errors}', Icons.error_outline),
    ];

    return CfCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HealthDot(health: bar.platformHealth),
              const SizedBox(width: 8),
              Text(
                'Live status',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Text(
                'Cached probe · not a permanent listener',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < items.length; i++)
                Material(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          items[i].$3,
                          size: 16,
                          color: i == 0
                              ? platformHealthColor(context, bar.platformHealth)
                              : AdminColors.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        if (items[i].$2.isNotEmpty) ...[
                          Text(
                            items[i].$2,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          items[i].$1,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                            fontWeight: i == 0 ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MonitoringKpiCard extends StatelessWidget {
  const MonitoringKpiCard({super.key, required this.kpi});

  final MonitoringKpi kpi;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return CfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kpi.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
              if (kpi.health != null) HealthBadge(health: kpi.health!),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            kpi.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (kpi.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              kpi.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class MonitoringKpiGrid extends StatelessWidget {
  const MonitoringKpiGrid({super.key, required this.kpis});

  final List<MonitoringKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 1400
            ? 4
            : width >= 1000
                ? 3
                : width >= 640
                    ? 2
                    : 1;
        const spacing = 12.0;
        final itemWidth = (width - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final k in kpis)
              SizedBox(width: itemWidth, child: MonitoringKpiCard(kpi: k)),
          ],
        );
      },
    );
  }
}

class MonitoringMetricTile extends StatelessWidget {
  const MonitoringMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return CfCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class MonitoringMetricGrid extends StatelessWidget {
  const MonitoringMetricGrid({super.key, required this.items});

  final List<(String, String, String?)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1000
            ? 4
            : c.maxWidth >= 640
                ? 2
                : 1;
        const spacing = 12.0;
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final i in items)
              SizedBox(
                width: w,
                child: MonitoringMetricTile(
                  label: i.$1,
                  value: i.$2,
                  subtitle: i.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class MonitoringGrowthChart extends StatelessWidget {
  const MonitoringGrowthChart({
    super.key,
    required this.title,
    required this.points,
  });

  final String title;
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return CfCard(
      child: SizedBox(
        height: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: points.isEmpty
                  ? Center(
                      child: Text(
                        'No growth series yet',
                        style: TextStyle(color: colors.textMuted),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: colors.border,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < points.length; i++)
                                FlSpot(i.toDouble(), points[i]),
                            ],
                            isCurved: true,
                            color: AdminColors.primaryBlue,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AdminColors.primaryBlue
                                  .withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Text(
              'Placeholder series — ready for Cloud Monitoring / BigQuery',
              style: TextStyle(fontSize: 10, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class MonitoringSectionCard extends StatelessWidget {
  const MonitoringSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return CfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
