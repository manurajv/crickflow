import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../models/ai_ops_enums.dart';
import '../../models/managed_ai_ops.dart';

class AiOpsSummaryCards extends StatelessWidget {
  const AiOpsSummaryCards({super.key, required this.summary});

  final AiOpsSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('AI Suggestions', '${summary.suggestions}', Icons.auto_awesome),
      ('Pending Reviews', '${summary.pendingReviews}', Icons.rate_review_outlined),
      ('Spam Detected', '${summary.spamDetected}', Icons.report_gmailerrorred_outlined),
      ('Duplicate Accounts', '${summary.duplicateAccounts}', Icons.people_outline),
      ('Duplicate Teams', '${summary.duplicateTeams}', Icons.groups_outlined),
      ('Duplicate Grounds', '${summary.duplicateGrounds}', Icons.stadium_outlined),
      ('Fraud Alerts', '${summary.fraudAlerts}', Icons.shield_outlined),
      ('Automation Rules', '${summary.automationRules}', Icons.rule_folder_outlined),
      ('Resolved', '${summary.resolvedRecommendations}', Icons.task_alt),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1200
            ? 3
            : c.maxWidth >= 720
                ? 2
                : 1;
        const spacing = 12.0;
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final i in items)
              SizedBox(
                width: w,
                child: CfCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(i.$3, color: AdminColors.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i.$1,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.adminColors.textMuted,
                              ),
                            ),
                            Text(
                              i.$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AiConfidenceBadge extends StatelessWidget {
  const AiConfidenceBadge({super.key, required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final band = AiConfidenceBand.fromScore(score);
    final colors = context.adminColors;
    final color = switch (band) {
      AiConfidenceBand.low => colors.textMuted,
      AiConfidenceBand.medium => AdminColors.primaryBlue,
      AiConfidenceBand.high => colors.warning,
      AiConfidenceBand.critical => colors.error,
    };
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          '${band.label} ${(score * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class AiStatusBadge extends StatelessWidget {
  const AiStatusBadge({super.key, required this.status});

  final AiRecommendationStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      AiRecommendationStatus.pending => colors.warning,
      AiRecommendationStatus.accepted => colors.success,
      AiRecommendationStatus.executed => colors.success,
      AiRecommendationStatus.rejected => colors.error,
      AiRecommendationStatus.archived => colors.textMuted,
    };
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          status.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
