import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/admin_colors.dart';
import 'cf_card.dart';

class CfStatTile extends StatelessWidget {
  const CfStatTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.growthLabel,
    this.growthPositive,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? growthLabel;
  final bool? growthPositive;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final accent = accentColor ?? AdminColors.primaryBlue;
    final growthColor = growthPositive == null
        ? colors.textMuted
        : (growthPositive! ? colors.success : colors.error);

    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const Spacer(),
              if (growthLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: growthColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (growthPositive != null)
                        Icon(
                          growthPositive!
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 14,
                          color: growthColor,
                        ),
                      if (growthPositive != null) const SizedBox(width: 4),
                      Text(
                        growthLabel!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: growthColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
