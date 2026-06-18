import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/match_model.dart';
import '../../../../domain/display/match_revision_display.dart';
import '../../../../shared/widgets/match_revision_badge.dart';

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

    final badges = <MatchRevisionBadge>[
      ...MatchRevisionDisplay.badgesForMatch(match),
    ];
    if (message.toLowerCase().contains('penalty') &&
        !badges.any((b) => b.kind == 'penalty')) {
      badges.add(const MatchRevisionBadge(label: 'PENALTY', kind: 'penalty'));
    }

    return Material(
      color: AppColors.primaryBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badges.isNotEmpty) ...[
                MatchRevisionBadgeRow(badges: badges, compact: true),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
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
            ],
          ),
        ),
      ),
    );
  }
}
