import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';

/// Light-theme-friendly CTA strip used at the top of My Cricket tabs.
class MyCricketActionBanner extends StatelessWidget {
  const MyCricketActionBanner({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.subtitle,
    this.inset = true,
  });

  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final banner = Container(
      decoration: cfCardDecoration(context),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cf.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cf.textSecondary,
                    ),
              ),
        trailing: FilledButton(
          onPressed: onAction,
          style: FilledButton.styleFrom(
            backgroundColor: cf.accent,
            foregroundColor: cf.onAccent,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            elevation: cf.isLight ? 0 : 1,
          ),
          child: Text(actionLabel),
        ),
      ),
    );

    if (!inset) return banner;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      child: banner,
    );
  }
}
