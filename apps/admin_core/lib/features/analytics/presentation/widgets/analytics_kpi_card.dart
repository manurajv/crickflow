import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../models/analytics_models.dart';

class AnalyticsKpiCard extends StatelessWidget {
  const AnalyticsKpiCard({super.key, required this.kpi});

  final AnalyticsKpi kpi;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final up = kpi.isUp;
    final trendColor = up ? colors.success : colors.error;
    final change = kpi.changePercent.abs().toStringAsFixed(1);

    return CfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kpi.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  kpi.unit.isEmpty
                      ? kpi.formattedValue
                      : '${kpi.formattedValue} ${kpi.unit}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                up ? Icons.trending_up : Icons.trending_down,
                size: 16,
                color: trendColor,
              ),
              const SizedBox(width: 4),
              Text(
                '$change%',
                style: TextStyle(
                  color: trendColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'vs prior period',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ),
            ],
          ),
          if (kpi.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              kpi.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class AnalyticsKpiGrid extends StatelessWidget {
  const AnalyticsKpiGrid({super.key, required this.kpis});

  final List<AnalyticsKpi> kpis;

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
              SizedBox(width: itemWidth, child: AnalyticsKpiCard(kpi: k)),
          ],
        );
      },
    );
  }
}

class AnalyticsRealtimeStrip extends StatelessWidget {
  const AnalyticsRealtimeStrip({super.key, required this.realtime});

  final AnalyticsRealtimeSnapshot realtime;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final items = [
      ('Users online*', realtime.usersOnline, Icons.circle),
      ('Matches live', realtime.matchesLive, Icons.sports_cricket),
      ('Streams', realtime.streamsRunning, Icons.live_tv_outlined),
      ('Notifs', realtime.notificationsSentToday, Icons.notifications_outlined),
      ('Posts today', realtime.postsCreatedToday, Icons.forum_outlined),
      ('Reports', realtime.reportsReceivedToday, Icons.flag_outlined),
    ];

    return CfCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Realtime snapshot',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              if (realtime.updatedAt != null)
                Text(
                  'Updated ${TimeOfDay.fromDateTime(realtime.updatedAt!).format(context)}',
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in items)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.$3, size: 16, color: AdminColors.primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        '${item.$2}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.$1,
                        style: TextStyle(fontSize: 12, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '* Online users approximated until presence warehouse is wired.',
            style: TextStyle(fontSize: 10, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
