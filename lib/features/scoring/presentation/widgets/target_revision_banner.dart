import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/match_model.dart';

/// Dismissible live banner for target revisions, DLS, and penalties.
class TargetRevisionBanner extends StatelessWidget {
  const TargetRevisionBanner({
    super.key,
    required this.match,
    required this.onDismiss,
  });

  final MatchModel match;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final state = match.targetState;
    if (state.liveBannerDismissed) return const SizedBox.shrink();
    final message = state.liveBannerMessage;
    if (message == null || message.isEmpty) return const SizedBox.shrink();

    return Material(
      color: AppColors.primaryBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (state.dlsApplied) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: const Text(
                    'DLS Applied',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.textSecondary,
                onPressed: onDismiss,
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
