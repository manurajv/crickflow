import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/managed_broadcast.dart';

class BroadcastsSummaryCards extends StatelessWidget {
  const BroadcastsSummaryCards({super.key, required this.summary});

  final BroadcastSummaryStats summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _card(Icons.live_tv_outlined, 'Total Broadcasts', '${summary.total}',
          AdminColors.primaryBlue),
      _card(Icons.fiber_manual_record, 'Live Now', '${summary.live}',
          context.adminColors.error),
      _card(Icons.schedule_outlined, 'Scheduled', '${summary.scheduled}',
          context.adminColors.info),
      _card(Icons.check_circle_outline, 'Completed', '${summary.completed}',
          context.adminColors.success),
      _card(Icons.error_outline, 'Failed', '${summary.failed}',
          context.adminColors.warning),
      _card(Icons.ondemand_video_outlined, 'YouTube', '${summary.youtube}',
          const Color(0xFFFF0000)),
      _card(Icons.facebook_outlined, 'Facebook', '${summary.facebook}',
          const Color(0xFF1877F2)),
      _card(Icons.settings_input_antenna, 'External RTMP',
          '${summary.externalRtmp}', const Color(0xFF7E57C2)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 1400
            ? 4
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

class BroadcastsToolbar extends StatelessWidget {
  const BroadcastsToolbar({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.onSearchSubmitted,
    required this.onFilter,
    required this.onRefresh,
    required this.onExport,
    required this.onToggleLiveMonitor,
    this.filterActive = false,
    this.refreshing = false,
    this.liveMonitor = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final VoidCallback onToggleLiveMonitor;
  final bool filterActive;
  final bool refreshing;
  final bool liveMonitor;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onQueryChanged,
                onSubmitted: (_) => onSearchSubmitted(),
                decoration: InputDecoration(
                  hintText: compact
                      ? 'Search broadcasts…'
                      : 'Search match, ID, organizer, tournament, location…',
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
                tooltip: liveMonitor ? 'All broadcasts' : 'Live monitor',
                onPressed: onToggleLiveMonitor,
                icon: Icon(
                  liveMonitor
                      ? Icons.sensors
                      : Icons.sensors_outlined,
                  color: liveMonitor ? colors.error : null,
                ),
              ),
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
                onPressed: onToggleLiveMonitor,
                icon: Icon(
                  liveMonitor ? Icons.sensors : Icons.sensors_outlined,
                  size: 18,
                  color: liveMonitor ? colors.error : null,
                ),
                label: Text(liveMonitor ? 'Live monitor' : 'All'),
              ),
              const SizedBox(width: 8),
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
