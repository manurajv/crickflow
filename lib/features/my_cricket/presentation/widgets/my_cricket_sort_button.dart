import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../my_cricket_filters.dart';

class MyCricketSortButton extends StatelessWidget {
  const MyCricketSortButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MyCricketSort value;
  final ValueChanged<MyCricketSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceXs,
          AppDimens.spaceSm,
          0,
        ),
        child: PopupMenuButton<MyCricketSort>(
          initialValue: value,
          tooltip: 'Sort',
          onSelected: onChanged,
          itemBuilder: (_) => [
            for (final option in MyCricketSort.values)
              PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    if (option == value) ...[
                      const Icon(Icons.check, size: 18),
                      const SizedBox(width: AppDimens.spaceSm),
                    ] else
                      const SizedBox(width: 26),
                    Text(myCricketSortLabel(option)),
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: AppDimens.spaceXs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 18),
                const SizedBox(width: AppDimens.spaceXs),
                Text(myCricketSortLabel(value)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
