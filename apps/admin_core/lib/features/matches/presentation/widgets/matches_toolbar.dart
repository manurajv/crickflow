import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/managed_match.dart';

class MatchesSummaryCards extends StatelessWidget {
  const MatchesSummaryCards({super.key, required this.summary});

  final MatchSummaryStats summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _card(
        Icons.sports_cricket_outlined,
        'Total Matches',
        '${summary.total}',
        AdminColors.primaryBlue,
      ),
      _card(
        Icons.live_tv_outlined,
        'Live Matches',
        '${summary.live}',
        context.adminColors.success,
      ),
      _card(
        Icons.schedule_outlined,
        'Upcoming Matches',
        '${summary.upcoming}',
        context.adminColors.info,
      ),
      _card(
        Icons.check_circle_outline,
        'Completed Matches',
        '${summary.completed}',
        const Color(0xFF7E57C2),
      ),
      _card(
        Icons.report_gmailerrorred,
        'Abandoned Matches',
        '${summary.abandoned}',
        context.adminColors.error,
      ),
      _card(
        Icons.cancel_outlined,
        'Cancelled Matches',
        '${summary.cancelled}',
        const Color(0xFFFF7043),
      ),
      _card(
        Icons.stream_outlined,
        'Streams Running',
        '${summary.streamsRunning}',
        const Color(0xFF26A69A),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 1400
            ? 7
            : width >= 1100
                ? 4
                : width >= 700
                    ? 2
                    : 1;
        const spacing = 12.0;
        final itemWidth = (width - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in cards) SizedBox(width: itemWidth, child: c),
          ],
        );
      },
    );
  }

  Widget _card(IconData icon, String title, String value, Color accent) {
    return CfStatTile(
      icon: icon,
      title: title,
      value: value,
      accentColor: accent,
      compact: true,
    );
  }
}

class MatchesToolbar extends StatelessWidget {
  const MatchesToolbar({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.onSearchSubmitted,
    required this.onFilter,
    required this.onRefresh,
    required this.onExport,
    this.filterActive = false,
    this.refreshing = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final bool filterActive;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onQueryChanged,
                onSubmitted: (_) => onSearchSubmitted(),
                decoration: InputDecoration(
                  hintText: compact
                      ? 'Search matches...'
                      : 'Search title, ID, tournament, teams, scorer, venue...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            controller.clear();
                            onQueryChanged('');
                            onSearchSubmitted();
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  filled: true,
                  fillColor: colors.card,
                  isDense: compact,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (compact) ...[
              IconButton.outlined(
                tooltip: 'Filter',
                onPressed: onFilter,
                icon: Badge(
                  isLabelVisible: filterActive,
                  smallSize: 8,
                  child: const Icon(Icons.filter_list),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Export',
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: onFilter,
                icon: Badge(
                  isLabelVisible: filterActive,
                  smallSize: 8,
                  child: const Icon(Icons.filter_list),
                ),
                label: const Text('Filter'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export'),
              ),
            ],
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: refreshing ? null : onRefresh,
              icon: refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        );
      },
    );
  }
}
