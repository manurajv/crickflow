import 'package:flutter/material.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';

class CfButton extends StatelessWidget {
  const CfButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isGold = false,
    this.isOutlined = false,
    this.isDanger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  /// Uses accent color — gold in dark, brand blue in light.
  final bool isGold;
  final bool isOutlined;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: _icon(cf),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppDimens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        ),
      );
    }

    final bg = isDanger
        ? cf.error
        : isGold
            ? cf.fabBackground
            : CfColors.primaryBlue;
    final fg = isDanger
        ? cf.onPrimary
        : isGold
            ? cf.fabForeground
            : cf.onPrimary;

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(double.infinity, AppDimens.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        elevation: cf.isLight ? 0 : 1,
      ),
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fg,
              ),
            )
          : _icon(cf) ?? const SizedBox.shrink(),
      label: Text(label),
    );
  }

  Widget? _icon(CfColors cf) {
    if (icon == null || isLoading) return null;
    return Icon(icon, size: AppDimens.iconSm);
  }
}
