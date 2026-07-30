import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/managed_user.dart';

class UsersSummaryCards extends StatelessWidget {
  const UsersSummaryCards({super.key, required this.summary});

  final UserSummaryStats summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _card(
        Icons.people_outline,
        'Total Users',
        '${summary.total}',
        AdminColors.primaryBlue,
      ),
      _card(
        Icons.verified_outlined,
        'Verified Users',
        '${summary.verified}',
        const Color(0xFF43A047),
      ),
      _card(
        Icons.circle,
        'Online Users',
        '${summary.online}',
        const Color(0xFF26A69A),
      ),
      _card(
        Icons.person_add_alt_1_outlined,
        'New Users Today',
        '${summary.newToday}',
        AdminColors.goldDark,
      ),
      _card(
        Icons.pause_circle_outline,
        'Suspended Users',
        '${summary.suspended}',
        const Color(0xFFFF7043),
      ),
      _card(
        Icons.admin_panel_settings_outlined,
        'Admins',
        '${summary.admins}',
        const Color(0xFF7E57C2),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 1200
            ? 6
            : width >= 900
                ? 3
                : width >= 560
                    ? 2
                    : 1;
        const spacing = 12.0;
        final itemWidth =
            (width - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(width: itemWidth, child: card),
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

class UsersToolbar extends StatelessWidget {
  const UsersToolbar({
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
                      ? 'Search users…'
                      : 'Search name, username, email, player ID, phone…',
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
