import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/managed_ground.dart';

class GroundsSummaryCards extends StatelessWidget {
  const GroundsSummaryCards({super.key, required this.summary});

  final GroundSummaryStats summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _card(Icons.stadium_outlined, 'Total Grounds', '${summary.total}',
          AdminColors.primaryBlue),
      _card(Icons.verified_outlined, 'Verified Grounds', '${summary.verified}',
          context.adminColors.success),
      _card(Icons.check_circle_outline, 'Active Grounds', '${summary.active}',
          context.adminColors.info),
      _card(Icons.hourglass_empty, 'Pending Verification',
          '${summary.pendingVerification}', context.adminColors.warning),
      _card(Icons.home_work_outlined, 'Indoor Grounds', '${summary.indoor}',
          const Color(0xFF7E57C2)),
      _card(Icons.wb_sunny_outlined, 'Outdoor Grounds', '${summary.outdoor}',
          const Color(0xFF26A69A)),
      _card(Icons.grass, 'Turf Grounds', '${summary.turf}', AdminColors.goldDark),
      _card(Icons.layers_outlined, 'Matting Grounds', '${summary.matting}',
          const Color(0xFFFF7043)),
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

class GroundsToolbar extends StatelessWidget {
  const GroundsToolbar({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.onSearchSubmitted,
    required this.onFilter,
    required this.onRefresh,
    required this.onExport,
    required this.onToggleMap,
    required this.onAdd,
    this.mapView = false,
    this.filterActive = false,
    this.refreshing = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final VoidCallback onToggleMap;
  final VoidCallback onAdd;
  final bool mapView;
  final bool filterActive;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onQueryChanged,
                onSubmitted: (_) => onSearchSubmitted(),
                decoration: InputDecoration(
                  hintText: compact
                      ? 'Search grounds…'
                      : 'Search name, ID, owner, contact, city, PIN…',
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
                tooltip: mapView ? 'List view' : 'Map view',
                onPressed: onToggleMap,
                icon: Icon(mapView ? Icons.view_list : Icons.map_outlined),
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
              IconButton.filled(
                tooltip: 'Add ground',
                onPressed: onAdd,
                icon: const Icon(Icons.add),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: onToggleMap,
                icon: Icon(mapView ? Icons.view_list : Icons.map_outlined),
                label: Text(mapView ? 'List' : 'Map'),
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
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
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
