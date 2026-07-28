import 'package:flutter/material.dart';

import 'cf_button.dart';

/// Placeholder filter sheet — modules will plug real filters later.
Future<void> showCfFilterSheet({
  required BuildContext context,
  required String title,
  required Widget child,
  VoidCallback? onApply,
  VoidCallback? onReset,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: CfButton(
                    label: 'Reset',
                    variant: CfButtonVariant.secondary,
                    onPressed: () {
                      onReset?.call();
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CfButton(
                    label: 'Apply',
                    onPressed: () {
                      onApply?.call();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
