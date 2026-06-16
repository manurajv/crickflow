import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

class TeamDetailBottomBar extends StatelessWidget {
  const TeamDetailBottomBar({
    super.key,
    required this.onProfile,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryEnabled = true,
    this.secondaryIsGold = false,
  });

  final VoidCallback onProfile;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool secondaryEnabled;
  final bool secondaryIsGold;

  @override
  Widget build(BuildContext context) {
    final showSecondary =
        secondaryLabel != null && secondaryLabel!.isNotEmpty;

    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: _BarButton(
                  label: 'Profile',
                  filled: false,
                  onPressed: onProfile,
                ),
              ),
              if (showSecondary) ...[
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: _BarButton(
                    label: secondaryLabel!,
                    filled: true,
                    isGold: secondaryIsGold,
                    onPressed: secondaryEnabled ? onSecondary : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.filled,
    required this.onPressed,
    this.isGold = false,
  });

  final String label;
  final bool filled;
  final VoidCallback? onPressed;
  final bool isGold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: isGold
                    ? AppColors.gold
                    : onPressed == null
                        ? AppColors.primaryBlue.withValues(alpha: 0.45)
                        : AppColors.primaryBlue,
                foregroundColor: isGold ? Colors.black : Colors.white,
                disabledBackgroundColor:
                    AppColors.surfaceElevated.withValues(alpha: 0.8),
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                elevation: 0,
              ),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                backgroundColor: AppColors.surfaceElevated,
                side: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.8),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
    );
  }
}
