import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';

enum CfBadgeTone { neutral, success, warning, danger, info, primary }

/// Shared status / label pill used across modules.
class CfStatusBadge extends StatelessWidget {
  const CfStatusBadge({
    super.key,
    required this.label,
    this.tone = CfBadgeTone.neutral,
    this.icon,
    this.compact = false,
  });

  final String label;
  final CfBadgeTone tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final (fg, bg) = switch (tone) {
      CfBadgeTone.success => (colors.success, colors.success.withValues(alpha: 0.12)),
      CfBadgeTone.warning => (colors.warning, colors.warning.withValues(alpha: 0.14)),
      CfBadgeTone.danger => (colors.error, colors.error.withValues(alpha: 0.12)),
      CfBadgeTone.info => (colors.info, colors.info.withValues(alpha: 0.12)),
      CfBadgeTone.primary => (
          colors.isLight ? colors.info : colors.sidebarSelected,
          colors.info.withValues(alpha: 0.12),
        ),
      CfBadgeTone.neutral => (colors.textSecondary, colors.background),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? dimens.spaceSm : 10,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(dimens.radiusPill),
          border: Border.all(color: fg.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: fg),
              SizedBox(width: dimens.spaceXs),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
