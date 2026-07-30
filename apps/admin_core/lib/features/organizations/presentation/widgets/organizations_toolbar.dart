import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/managed_organization.dart';

class OrganizationsSummaryCards extends StatelessWidget {
  const OrganizationsSummaryCards({super.key, required this.summary});

  final OrganizationSummaryStats summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _card(Icons.apartment_outlined, 'Total', '${summary.total}',
          AdminColors.primaryBlue),
      _card(Icons.check_circle_outline, 'Active', '${summary.active}',
          context.adminColors.success),
      _card(Icons.hourglass_empty_outlined, 'Pending', '${summary.pending}',
          context.adminColors.warning),
      _card(Icons.verified_outlined, 'Verified', '${summary.verified}',
          AdminColors.primaryBlue),
      _card(Icons.block_outlined, 'Suspended', '${summary.suspended}',
          context.adminColors.error),
      _card(Icons.account_balance_outlined, 'Boards', '${summary.boards}',
          const Color(0xFF5C6BC0)),
      _card(Icons.sports_outlined, 'Clubs', '${summary.clubs}',
          AdminColors.goldDark),
      _card(Icons.admin_panel_settings_outlined, 'With Org Admin',
          '${summary.withAdmin}', const Color(0xFF7E57C2)),
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

class OrganizationsToolbar extends StatelessWidget {
  const OrganizationsToolbar({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.onSearchSubmitted,
    required this.onFilter,
    required this.onRefresh,
    required this.onCreate,
    this.filterActive = false,
    this.refreshing = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
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
                      ? 'Search organizations…'
                      : 'Search name, slug, ID, email, location, admin…',
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
              IconButton.filled(
                tooltip: 'Create',
                onPressed: onCreate,
                icon: const Icon(Icons.add),
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
              CfButton(
                label: 'Create organization',
                icon: Icons.add,
                onPressed: onCreate,
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
