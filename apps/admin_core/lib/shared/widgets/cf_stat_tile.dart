import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/admin_colors.dart';
import '../../core/theme/admin_typography.dart';
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? growthLabel;
  final bool? growthPositive;
  final Color? accentColor;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final accent = accentColor ?? AdminColors.primaryBlue;
    final growthColor = growthPositive == null
        ? colors.textMuted
        : (growthPositive! ? colors.success : colors.error);
    final iconSize = compact ? 34.0 : 40.0;

    return CfCard(
      variant: CfCardVariant.stat,
      onTap: onTap,
      semanticLabel: '$title $value',
      padding: compact
          ? EdgeInsets.symmetric(
              horizontal: dimens.spaceMd + 2,
              vertical: dimens.spaceMd,
            )
          : dimens.cardPadding,
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
                  borderRadius: dimens.borderRadiusMd,
                ),
                child: Icon(icon, color: accent, size: compact ? 18 : 22),
              ),
              const Spacer(),
              if (growthLabel != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: dimens.spaceSm,
                    vertical: dimens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: growthColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(dimens.radiusPill),
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
                      if (growthPositive != null)
                        SizedBox(width: dimens.spaceXs),
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
          SizedBox(height: compact ? dimens.spaceMd - 2 : dimens.spaceLg),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminTypography.statistic(context, compact: compact),
          ),
          SizedBox(height: dimens.spaceXs / 2),
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
