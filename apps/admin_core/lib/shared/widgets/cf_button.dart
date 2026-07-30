import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/admin_colors.dart';

enum CfButtonVariant {
  primary,
  secondary,
  outlined,
  text,
  ghost,
  danger,
  success,
}

class CfButton extends StatelessWidget {
  const CfButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = CfButtonVariant.primary,
    this.isLoading = false,
    this.expanded = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final CfButtonVariant variant;
  final bool isLoading;
  final bool expanded;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final enabled = onPressed != null && !isLoading;

    final child = isLoading
        ? SizedBox(
            width: dimens.iconMd,
            height: dimens.iconMd,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == CfButtonVariant.ghost ||
                      variant == CfButtonVariant.text ||
                      variant == CfButtonVariant.outlined ||
                      variant == CfButtonVariant.secondary
                  ? AdminColors.primaryBlue
                  : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dimens.iconMd),
                SizedBox(width: dimens.spaceSm),
              ],
              Text(label),
            ],
          );

    final button = switch (variant) {
      CfButtonVariant.primary => ElevatedButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        ),
      CfButtonVariant.secondary ||
      CfButtonVariant.outlined =>
        OutlinedButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        ),
      CfButtonVariant.ghost || CfButtonVariant.text => TextButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        ),
      CfButtonVariant.danger => ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: Colors.white,
            disabledBackgroundColor: colors.error.withValues(alpha: 0.4),
          ),
          child: child,
        ),
      CfButtonVariant.success => ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.success,
            foregroundColor: Colors.white,
            disabledBackgroundColor: colors.success.withValues(alpha: 0.4),
          ),
          child: child,
        ),
    };

    final sized = expanded ? SizedBox(width: double.infinity, child: button) : button;
    if (tooltip == null || tooltip!.isEmpty) return sized;
    return Tooltip(message: tooltip!, child: sized);
  }
}
