import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';

/// Consistent page chrome: title, subtitle, actions, standard padding.
class CfPageHeader extends StatelessWidget {
  const CfPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    return Padding(
      padding: EdgeInsets.only(bottom: dimens.spaceLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: dimens.spaceXs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty)
            Wrap(
              spacing: dimens.spaceSm,
              runSpacing: dimens.spaceSm,
              children: actions,
            ),
        ],
      ),
    );
  }
}

/// Standard scrollable page body with design-system padding.
class CfPageBody extends StatelessWidget {
  const CfPageBody({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? context.adminDimens.pagePadding,
      child: child,
    );
  }
}
