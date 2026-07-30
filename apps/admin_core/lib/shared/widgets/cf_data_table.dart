import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/admin_typography.dart';
import 'cf_card.dart';
import 'cf_empty_state.dart';

class CfTableColumn {
  const CfTableColumn({
    required this.id,
    required this.label,
    this.flex = 1,
    this.sortable = false,
  });

  final String id;
  final String label;
  final int flex;
  final bool sortable;
}

enum CfTableDensity { comfortable, compact }

/// Lightweight shared data table with sticky-style header, hover, and density.
class CfDataTable extends StatelessWidget {
  const CfDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyTitle = 'No data',
    this.emptyMessage = 'Nothing to show yet.',
    this.emptyAction,
    this.onRowTap,
    this.sortColumnId,
    this.sortAscending = true,
    this.onSort,
    this.density = CfTableDensity.comfortable,
    this.alternatingRows = false,
    this.selectedRowIds = const {},
    this.onToggleRow,
  });

  final List<CfTableColumn> columns;
  final List<Map<String, String>> rows;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? emptyAction;
  final ValueChanged<int>? onRowTap;
  final String? sortColumnId;
  final bool sortAscending;
  final void Function(String columnId)? onSort;
  final CfTableDensity density;
  final bool alternatingRows;
  final Set<String> selectedRowIds;
  final void Function(String rowId, bool selected)? onToggleRow;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    if (rows.isEmpty) {
      return CfEmptyState(
        icon: Icons.table_rows_outlined,
        title: emptyTitle,
        message: emptyMessage,
        action: emptyAction,
      );
    }

    final cellPad = density == CfTableDensity.compact
        ? EdgeInsets.symmetric(
            horizontal: dimens.spaceLg,
            vertical: dimens.spaceSm,
          )
        : dimens.tableCellPadding;

    return CfCard(
      padding: EdgeInsets.zero,
      variant: CfCardVariant.list,
      child: Column(
        children: [
          Container(
            padding: cellPad,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(dimens.radiusLg),
              ),
            ),
            child: Row(
              children: [
                if (onToggleRow != null)
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: selectedRowIds.length == rows.length &&
                          rows.isNotEmpty,
                      tristate: selectedRowIds.isNotEmpty &&
                          selectedRowIds.length < rows.length,
                      onChanged: (v) {
                        for (var i = 0; i < rows.length; i++) {
                          final id = rows[i]['_id'] ?? '$i';
                          onToggleRow!(id, v ?? false);
                        }
                      },
                    ),
                  ),
                for (final col in columns)
                  Expanded(
                    flex: col.flex,
                    child: InkWell(
                      onTap: col.sortable && onSort != null
                          ? () => onSort!(col.id)
                          : null,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              col.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (col.sortable && sortColumnId == col.id)
                            Icon(
                              sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 14,
                              color: colors.textMuted,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.border),
            _CfTableRow(
              columns: columns,
              row: rows[i],
              index: i,
              padding: cellPad,
              alternating: alternatingRows,
              selected: selectedRowIds.contains(rows[i]['_id'] ?? '$i'),
              onTap: onRowTap == null ? null : () => onRowTap!(i),
              onToggle: onToggleRow == null
                  ? null
                  : (v) => onToggleRow!(rows[i]['_id'] ?? '$i', v),
            ),
          ],
        ],
      ),
    );
  }
}

class _CfTableRow extends StatefulWidget {
  const _CfTableRow({
    required this.columns,
    required this.row,
    required this.index,
    required this.padding,
    required this.alternating,
    required this.selected,
    this.onTap,
    this.onToggle,
  });

  final List<CfTableColumn> columns;
  final Map<String, String> row;
  final int index;
  final EdgeInsetsGeometry padding;
  final bool alternating;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;

  @override
  State<_CfTableRow> createState() => _CfTableRowState();
}

class _CfTableRowState extends State<_CfTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    Color? bg;
    if (widget.selected) {
      bg = colors.info.withValues(alpha: 0.08);
    } else if (_hovered) {
      bg = colors.rowHover;
    } else if (widget.alternating && widget.index.isOdd) {
      bg = colors.rowAlt;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: bg ?? Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: widget.padding,
            child: Row(
              children: [
                if (widget.onToggle != null)
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: widget.selected,
                      onChanged: (v) => widget.onToggle!(v ?? false),
                    ),
                  ),
                for (final col in widget.columns)
                  Expanded(
                    flex: col.flex,
                    child: Text(
                      widget.row[col.id] ?? '—',
                      style: AdminTypography.table(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
