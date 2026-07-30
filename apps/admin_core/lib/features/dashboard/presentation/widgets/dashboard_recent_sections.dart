import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/admin_route_paths.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_chart_placeholder.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_network_image.dart';
import '../../models/dashboard_models.dart';
import 'dashboard_section_header.dart';

class DashboardRecentMatchesSection extends StatelessWidget {
  const DashboardRecentMatchesSection({super.key, required this.items});

  final List<RecentMatchItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          title: 'Recent matches',
          subtitle: 'Latest match activity',
          trailing: TextButton(
            onPressed: () => context.go(AdminRoutePaths.matches),
            child: const Text('View all'),
          ),
        ),
        CfCard(
          padding: EdgeInsets.zero,
          child: items.isEmpty
              ? const SizedBox(
                  height: 160,
                  child: CfEmptyState(
                    icon: Icons.sports_cricket_outlined,
                    title: 'No matches',
                    message: 'Recent matches will show here.',
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: colors.border),
                      _MatchRow(item: items[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.item});

  final RecentMatchItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isLive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'LIVE',
                          style: TextStyle(
                            color: colors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.teamA} vs ${item.teamB}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.status} · ${item.score}',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => context.go(AdminRoutePaths.matches),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class DashboardRecentReportsSection extends StatelessWidget {
  const DashboardRecentReportsSection({super.key, required this.items});

  final List<RecentReportItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          title: 'Recent reports',
          trailing: TextButton(
            onPressed: () => context.go(AdminRoutePaths.reports),
            child: const Text('View all'),
          ),
        ),
        CfCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.border),
                ListTile(
                  title: Text(
                    items[i].userName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(items[i].reason),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusPill(label: items[i].status),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => context.go(AdminRoutePaths.reports),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class DashboardRecentUsersSection extends StatelessWidget {
  const DashboardRecentUsersSection({super.key, required this.items});

  final List<RecentUserItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          title: 'Recent users',
          subtitle: 'Newest registrations',
          trailing: TextButton(
            onPressed: () => context.go(AdminRoutePaths.users),
            child: const Text('View all'),
          ),
        ),
        CfCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.border),
                ListTile(
                  leading: CfAvatar(
                    url: items[i].photoUrl,
                    radius: 20,
                    label: items[i].name,
                  ),
                  title: Text(
                    items[i].name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${items[i].country} · ${items[i].joinedLabel}'),
                  trailing: _StatusPill(label: items[i].status),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class DashboardRecentTournamentsSection extends StatelessWidget {
  const DashboardRecentTournamentsSection({super.key, required this.items});

  final List<RecentTournamentItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          title: 'Recent tournaments',
          trailing: TextButton(
            onPressed: () => context.go(AdminRoutePaths.tournaments),
            child: const Text('View all'),
          ),
        ),
        CfCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.border),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: items[i].posterUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              items[i].posterUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.emoji_events_outlined,
                            color: colors.textMuted,
                          ),
                  ),
                  title: Text(
                    items[i].title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(items[i].organizer),
                  trailing: _StatusPill(label: items[i].status),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class DashboardAnalyticsPlaceholdersSection extends StatelessWidget {
  const DashboardAnalyticsPlaceholdersSection({super.key, required this.items});

  final List<AnalyticsPlaceholderItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'Analytics',
          subtitle: 'Chart placeholders — wire real series later',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            if (!wide) {
              return Column(
                children: [
                  for (final item in items) ...[
                    CfChartPlaceholder(
                      title: item.title,
                      height: 200,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final item in items)
                  SizedBox(
                    width: (constraints.maxWidth - 14) / 2,
                    child: CfChartPlaceholder(
                      title: item.title,
                      height: 210,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final lower = label.toLowerCase();
    final color = lower.contains('live') || lower.contains('open')
        ? colors.error
        : lower.contains('resolv') || lower.contains('active')
            ? colors.success
            : lower.contains('review') || lower.contains('ongoing')
                ? colors.warning
                : colors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
