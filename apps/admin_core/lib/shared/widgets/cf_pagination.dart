import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import 'cf_button.dart';

class CfPagination extends StatelessWidget {
  const CfPagination({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
    this.totalItems,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;
  final int? totalItems;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final label = totalItems == null
        ? 'Page $page of $pageCount'
        : 'Page $page of $pageCount · $totalItems items';

    return Semantics(
      label: label,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          SizedBox(width: dimens.spaceMd),
          CfButton(
            label: 'Prev',
            variant: CfButtonVariant.secondary,
            icon: Icons.chevron_left,
            tooltip: 'Previous page',
            onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
          ),
          SizedBox(width: dimens.spaceSm),
          CfButton(
            label: 'Next',
            variant: CfButtonVariant.secondary,
            icon: Icons.chevron_right,
            tooltip: 'Next page',
            onPressed: page < pageCount ? () => onPageChanged(page + 1) : null,
          ),
        ],
      ),
    );
  }
}
