import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';

class CfEmptyState extends StatelessWidget {
  const CfEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final resolvedAction = action ??
        (actionLabel != null && onAction != null
            ? FilledButton(onPressed: onAction, child: Text(actionLabel!))
            : null);

    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Padding(
        padding: EdgeInsets.all(dimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.background,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: Icon(icon, size: dimens.iconLg + 2, color: colors.textMuted),
            ),
            SizedBox(height: dimens.spaceMd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: dimens.spaceXs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
            if (resolvedAction != null) ...[
              SizedBox(height: dimens.spaceMd),
              resolvedAction,
            ],
          ],
        ),
      ),
    );

    return Semantics(
      label: '$title. $message',
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Give the scroll/fit surface an explicit bound when the parent
          // has a max height — avoids Center+ScrollView shrink-wrap overflow.
          final hasHeight = constraints.hasBoundedHeight;
          final hasWidth = constraints.hasBoundedWidth;
          final child = hasHeight
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: content,
                )
              : SingleChildScrollView(child: content);

          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: hasWidth ? constraints.maxWidth : null,
              height: hasHeight ? constraints.maxHeight : null,
              child: child,
            ),
          );
        },
      ),
    );
  }
}
