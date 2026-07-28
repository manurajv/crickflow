import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import 'cf_button.dart';

class CfPagination extends StatelessWidget {
  const CfPagination({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Page $page of $pageCount',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
        ),
        const SizedBox(width: 12),
        CfButton(
          label: 'Prev',
          variant: CfButtonVariant.secondary,
          onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
        ),
        const SizedBox(width: 8),
        CfButton(
          label: 'Next',
          variant: CfButtonVariant.secondary,
          onPressed: page < pageCount ? () => onPageChanged(page + 1) : null,
        ),
      ],
    );
  }
}
