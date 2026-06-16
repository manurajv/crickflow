import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

class TeamSquadEmptyState extends StatelessWidget {
  const TeamSquadEmptyState({
    super.key,
    required this.onAddPlayers,
    this.showAddButton = true,
  });

  final VoidCallback onAddPlayers;
  final bool showAddButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceXl,
        48,
        AppDimens.spaceXl,
        AppDimens.spaceXl,
      ),
      child: Column(
        children: [
          Icon(
            Icons.groups_outlined,
            size: 72,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'No players added yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showAddButton) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Invite players to build your squad',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton(
              onPressed: onAddPlayers,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Add players'),
            ),
          ],
        ],
      ),
    );
  }
}
