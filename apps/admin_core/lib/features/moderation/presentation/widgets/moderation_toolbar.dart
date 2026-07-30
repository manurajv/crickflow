import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';

class ModerationToolbar extends StatelessWidget {
  const ModerationToolbar({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.onSearchSubmitted,
    required this.onFilter,
    required this.onRefresh,
    required this.onExport,
    this.filterActive = false,
    this.refreshing = false,
    this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final bool filterActive;
  final bool refreshing;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final hint = hintText ??
            (compact
                ? 'Search posts…'
                : 'Post ID, user, hashtags, tournament, team, ground, match…');
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onQueryChanged,
                onSubmitted: (_) => onSearchSubmitted(),
                decoration: InputDecoration(
                  hintText: compact && (hintText?.isNotEmpty ?? false)
                      ? 'Search…'
                      : hint,
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
