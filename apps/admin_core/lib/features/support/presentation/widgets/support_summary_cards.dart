import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../models/managed_support.dart';

class SupportSummaryCards extends StatelessWidget {
  const SupportSummaryCards({super.key, required this.summary});

  final SupportSummaryStats summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Open', '${summary.open}', Icons.inbox_outlined, null),
      ('Pending', '${summary.pending}', Icons.hourglass_empty, null),
      ('Waiting for User', '${summary.waitingForUser}', Icons.person_outline, null),
      ('Resolved Today', '${summary.resolvedToday}', Icons.check_circle_outline, null),
      ('Closed', '${summary.closed}', Icons.lock_outline, null),
      ('High Priority', '${summary.highPriority}', Icons.priority_high, null),
      (
        'Avg Response',
        '${summary.avgResponseMins.toStringAsFixed(0)}m',
        Icons.timer_outlined,
        null,
      ),
      (
        'CSAT',
        summary.csatAverage == 0
            ? '—'
            : summary.csatAverage.toStringAsFixed(1),
        Icons.sentiment_satisfied_alt_outlined,
        null,
      ),
      if (summary.overdue > 0)
        ('Overdue SLA', '${summary.overdue}', Icons.warning_amber, true),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1200
            ? 4
            : c.maxWidth >= 800
                ? 3
                : c.maxWidth >= 520
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
                child: _Card(
                  label: i.$1,
                  value: i.$2,
                  icon: i.$3,
                  warn: i.$4 == true,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.value,
    required this.icon,
    this.warn = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return CfCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            icon,
            color: warn ? colors.warning : AdminColors.primaryBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
