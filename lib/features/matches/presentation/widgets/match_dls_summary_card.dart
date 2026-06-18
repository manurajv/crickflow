import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_model.dart';

/// Match summary block when scorer-assisted DLS has been applied.
class MatchDlsSummaryCard extends StatelessWidget {
  const MatchDlsSummaryCard({super.key, required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final state = match.targetState;
    if (!state.dlsApplied) return const SizedBox.shrink();

    final originalTarget = state.originalTarget;
    final finalTarget = state.effectiveRevisedTarget;
    final originalOvers = state.originalOvers;
    final revisedOvers = state.effectiveRevisedOvers;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: const Text(
                    'DLS Applied',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (originalOvers != null && revisedOvers != null) ...[
              const SizedBox(height: 10),
              Text(
                'Overs: $originalOvers → $revisedOvers',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (originalTarget != null || finalTarget != null) ...[
              const SizedBox(height: 8),
              if (originalTarget != null)
                Text(
                  'Original Target: $originalTarget',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              if (finalTarget != null)
                Text(
                  'Final Target: $finalTarget',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
