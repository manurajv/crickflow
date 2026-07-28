import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import 'cf_card.dart';
import 'cf_empty_state.dart';

class CfTableColumn {
  const CfTableColumn({
    required this.id,
    required this.label,
    this.flex = 1,
  });

  final String id;
  final String label;
  final int flex;
}

/// Lightweight placeholder data table for future modules.
class CfDataTable extends StatelessWidget {
  const CfDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyTitle = 'No data',
    this.emptyMessage = 'Nothing to show yet.',
  });

  final List<CfTableColumn> columns;
  final List<Map<String, String>> rows;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    if (rows.isEmpty) {
      return CfEmptyState(icon: Icons.table_rows_outlined, title: emptyTitle, message: emptyMessage);
    }

    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                for (final col in columns)
                  Expanded(
                    flex: col.flex,
                    child: Text(
                      col.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  for (final col in columns)
                    Expanded(
                      flex: col.flex,
                      child: Text(
                        rows[i][col.id] ?? '—',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
