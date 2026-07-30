import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import 'cf_button.dart';

/// Placeholder filter sheet — modules can use for compact filter surfaces.
Future<void> showCfFilterSheet({
  required BuildContext context,
  required String title,
  required Widget child,
  VoidCallback? onApply,
  VoidCallback? onReset,
}) {
  final dimens = context.adminDimens;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(dimens.radiusXl)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: dimens.spaceXxl,
          right: dimens.spaceXxl,
          top: dimens.spaceXl,
          bottom: MediaQuery.paddingOf(context).bottom + dimens.spaceXxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: dimens.spaceLg),
            child,
            SizedBox(height: dimens.spaceXxl),
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
                SizedBox(width: dimens.spaceMd),
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

/// Shared chrome for end-drawer filters used across modules.
class CfFilterDrawerChrome extends StatelessWidget {
  const CfFilterDrawerChrome({
    super.key,
    required this.title,
    required this.child,
    required this.onApply,
    required this.onReset,
    this.onClose,
  });

  final String title;
  final Widget child;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              dimens.spaceXl,
              dimens.spaceLg,
              dimens.spaceSm,
              dimens.spaceSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close filters',
                  onPressed: onClose ?? () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(dimens.spaceXl),
              child: child,
            ),
          ),
          Divider(height: 1, color: colors.border),
          Padding(
            padding: EdgeInsets.all(dimens.spaceLg),
            child: Row(
              children: [
                Expanded(
                  child: CfButton(
                    label: 'Reset',
                    variant: CfButtonVariant.secondary,
                    onPressed: onReset,
                  ),
                ),
                SizedBox(width: dimens.spaceMd),
                Expanded(
                  child: CfButton(
                    label: 'Apply',
                    onPressed: onApply,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Labeled section inside a filter drawer.
class CfFilterSection extends StatelessWidget {
  const CfFilterSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dimens = context.adminDimens;
    final colors = context.adminColors;
    return Padding(
      padding: EdgeInsets.only(bottom: dimens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          SizedBox(height: dimens.spaceSm),
          child,
        ],
      ),
    );
  }
}
