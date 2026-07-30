import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';

class AdsToolbar extends StatelessWidget {
  const AdsToolbar({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.onSearchSubmitted,
    required this.onFilter,
    required this.onRefresh,
    required this.onExport,
    required this.onCreate,
    this.filterActive = false,
    this.refreshing = false,
    this.hintText,
    this.showCreate = true,
    this.showFilter = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final VoidCallback onCreate;
  final bool filterActive;
  final bool refreshing;
  final String? hintText;
  final bool showCreate;
  final bool showFilter;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Row(
          children: [
            if (showCreate) ...[
              CfButton(
                label: compact ? 'Create' : 'Create Advertisement',
                icon: Icons.add,
                onPressed: onCreate,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onQueryChanged,
                onSubmitted: (_) => onSearchSubmitted(),
                decoration: InputDecoration(
                  hintText: hintText ??
                      (compact
                          ? 'Search ads…'
                          : 'Search title, campaign, advertiser, placement…'),
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
            if (showFilter) ...[
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
            ],
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
