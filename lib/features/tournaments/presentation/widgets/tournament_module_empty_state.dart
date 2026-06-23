import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../shared/widgets/cf_button.dart';

class TournamentModuleEmptyState extends StatelessWidget {
  const TournamentModuleEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.primaryAction,
    this.secondaryAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final ({String label, VoidCallback onPressed})? primaryAction;
  final ({String label, VoidCallback onPressed})? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppDimens.screenPadding,
      children: [
        const SizedBox(height: 48),
        Icon(
          icon,
          size: 72,
          color: cf.textMuted.withValues(alpha: 0.45),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cf.textSecondary,
              ),
        ),
        if (primaryAction != null) ...[
          const SizedBox(height: AppDimens.spaceXl),
          CfButton(
            label: primaryAction!.label,
            isGold: true,
            onPressed: primaryAction!.onPressed,
          ),
        ],
        if (secondaryAction != null) ...[
          const SizedBox(height: AppDimens.spaceSm),
          CfButton(
            label: secondaryAction!.label,
            isOutlined: true,
            onPressed: secondaryAction!.onPressed,
          ),
        ],
      ],
    );
  }
}
