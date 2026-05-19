import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

class CfButton extends StatelessWidget {
  const CfButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isGold = false,
    this.isOutlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isGold;
  final bool isOutlined;

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: _icon(),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppDimens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isGold ? AppColors.gold : AppColors.primaryBlue,
        foregroundColor: isGold ? Colors.black : Colors.white,
        minimumSize: const Size(double.infinity, AppDimens.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      ),
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _icon() ?? const SizedBox.shrink(),
      label: Text(label),
    );
  }

  Widget? _icon() {
    if (icon == null || isLoading) return null;
    return Icon(icon, size: AppDimens.iconSm);
  }
}
