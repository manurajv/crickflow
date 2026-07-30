import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/dashboard_models.dart';
import 'dashboard_section_header.dart';
import 'dashboard_stat_card.dart';

class DashboardQuickActionsSection extends StatelessWidget {
  const DashboardQuickActionsSection({super.key, required this.actions});

  final List<QuickActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'Quick actions',
          subtitle: 'Jump to common workflows',
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final action in actions) ...[
                DashboardQuickActionCard(
                  item: action,
                  onTap: () => context.go(action.route),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class DashboardOverviewSection extends StatelessWidget {
  const DashboardOverviewSection({
    super.key,
    required this.metrics,
    required this.crossAxisCount,
  });

  final List<OverviewMetric> metrics;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'Overview',
          subtitle: 'Key metrics · placeholders until aggregates are wired',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 14.0;
            final cols = crossAxisCount.clamp(1, 6);
            final itemWidth =
                (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: itemWidth,
                    child: DashboardOverviewStatCard(metric: metric),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
