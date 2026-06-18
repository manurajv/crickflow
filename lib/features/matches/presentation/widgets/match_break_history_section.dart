import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_model.dart';

/// Break history for match summary tab.
class MatchBreakHistorySection extends StatelessWidget {
  const MatchBreakHistorySection({super.key, required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final history = match.matchBreakHistory;
    if (history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Breaks',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              ...history.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${e.breakType} – ${(e.durationSeconds / 60).round()} mins',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
