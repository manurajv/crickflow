import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../models/dashboard_models.dart';
import 'dashboard_section_header.dart';
import 'dashboard_stat_card.dart';

class DashboardLiveActivitySection extends StatelessWidget {
  const DashboardLiveActivitySection({super.key, required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'Live activity',
          subtitle: 'Newest first · ready for realtime listeners',
        ),
        CfCard(
          padding: EdgeInsets.zero,
          child: items.isEmpty
              ? const SizedBox(
                  height: 180,
                  child: CfEmptyState(
                    icon: Icons.bolt_outlined,
                    title: 'No activity yet',
                    message: 'Platform events will appear here.',
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: colors.border),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: _color(item.kind).withValues(alpha: 0.12),
                        child: Icon(_icon(item.kind), color: _color(item.kind), size: 18),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(item.subtitle),
                      trailing: Text(
                        _relative(item.occurredAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.textMuted,
                            ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _icon(ActivityKind kind) => switch (kind) {
        ActivityKind.userRegistered => Icons.person_add_alt_1_outlined,
        ActivityKind.tournamentCreated => Icons.emoji_events_outlined,
        ActivityKind.matchStarted => Icons.play_circle_outline,
        ActivityKind.matchCompleted => Icons.check_circle_outline,
        ActivityKind.streamStarted => Icons.live_tv_outlined,
        ActivityKind.streamEnded => Icons.stop_circle_outlined,
        ActivityKind.communityPost => Icons.forum_outlined,
        ActivityKind.reportSubmitted => Icons.flag_outlined,
      };

  Color _color(ActivityKind kind) => switch (kind) {
        ActivityKind.userRegistered => const Color(0xFF1E88E5),
        ActivityKind.tournamentCreated => const Color(0xFFFB8C00),
        ActivityKind.matchStarted => const Color(0xFFE53935),
        ActivityKind.matchCompleted => const Color(0xFF43A047),
        ActivityKind.streamStarted => const Color(0xFFEF5350),
        ActivityKind.streamEnded => const Color(0xFF78909C),
        ActivityKind.communityPost => const Color(0xFF00897B),
        ActivityKind.reportSubmitted => const Color(0xFFFF7043),
      };

  String _relative(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('MMM d').format(at);
  }
}

class DashboardSystemStatusSection extends StatelessWidget {
  const DashboardSystemStatusSection({super.key, required this.items});

  final List<SystemStatusItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'System status',
          subtitle: 'Service health indicators (placeholder probes)',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 700
                    ? 2
                    : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final color = serviceHealthColor(context, item.status);
                return CfCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: context.adminColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        serviceHealthLabel(item.status),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class DashboardPlatformHealthSection extends StatelessWidget {
  const DashboardPlatformHealthSection({super.key, required this.items});

  final List<HealthMetric> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'Platform health',
          subtitle: 'Operational snapshot · unavailable metrics show —',
        ),
        CfCard(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 650
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: 78,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          child: Icon(item.icon, size: 18, color: colors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.value,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
