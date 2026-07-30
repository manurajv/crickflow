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
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? growthLabel;
  final bool? growthPositive;
  final Color? accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final accent = accentColor ?? AdminColors.primaryBlue;
    final growthColor = growthPositive == null
        ? colors.textMuted
        : (growthPositive! ? colors.success : colors.error);
    final iconSize = compact ? 34.0 : 40.0;

    return CfCard(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
          : const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: compact ? 18 : 22),
              ),
              const Spacer(),
              if (growthLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          SizedBox(height: compact ? 10 : 16),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? Theme.of(context).textTheme.titleLarge
                    : Theme.of(context).textTheme.headlineMedium)
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
