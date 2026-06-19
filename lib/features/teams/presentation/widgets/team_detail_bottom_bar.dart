import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';

class TeamDetailBottomBar extends StatelessWidget {
  const TeamDetailBottomBar({
    super.key,
    required this.onProfile,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryEnabled = true,
    this.secondaryIsPrimary = false,
    this.secondaryIsDestructive = false,
  });

  final VoidCallback onProfile;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool secondaryEnabled;
  /// Primary CTA (e.g. Join team) — accent fill in light & dark.
  final bool secondaryIsPrimary;
  /// Destructive action (e.g. Leave team) — outlined danger style.
  final bool secondaryIsDestructive;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final showSecondary =
        secondaryLabel != null && secondaryLabel!.isNotEmpty;

    return Material(
      color: cf.card,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cf.card,
          border: Border(top: BorderSide(color: cf.border)),
          boxShadow: cf.isLight
              ? [
                  BoxShadow(
                    color: cf.cardShadow,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ]
              : null,
        ),
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
                    style: _BarButtonStyle.outlined,
                    onPressed: onProfile,
                  ),
                ),
                if (showSecondary) ...[
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: _BarButton(
                      label: secondaryLabel!,
                      style: !secondaryEnabled
                          ? _BarButtonStyle.disabled
                          : secondaryIsDestructive
                              ? _BarButtonStyle.destructive
                              : secondaryIsPrimary
                                  ? _BarButtonStyle.primary
                                  : _BarButtonStyle.primary,
                      onPressed: secondaryEnabled ? onSecondary : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _BarButtonStyle { outlined, primary, destructive, disabled }

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.style,
    required this.onPressed,
  });

  final String label;
  final _BarButtonStyle style;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final radius = BorderRadius.circular(AppDimens.radiusMd);

    switch (style) {
      case _BarButtonStyle.outlined:
        return SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: cf.textPrimary,
              backgroundColor: cf.card,
              side: BorderSide(color: cf.border),
              shape: RoundedRectangleBorder(borderRadius: radius),
              elevation: 0,
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      case _BarButtonStyle.destructive:
        return SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: cf.error,
              backgroundColor: cf.card,
              side: BorderSide(color: cf.error.withValues(alpha: 0.55)),
              shape: RoundedRectangleBorder(borderRadius: radius),
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      case _BarButtonStyle.disabled:
        return SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: cf.sectionBackground,
              foregroundColor: cf.textMuted,
              disabledBackgroundColor: cf.sectionBackground,
              disabledForegroundColor: cf.textMuted,
              shape: RoundedRectangleBorder(borderRadius: radius),
              elevation: 0,
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      case _BarButtonStyle.primary:
        return SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: cf.accent,
              foregroundColor: cf.onAccent,
              disabledBackgroundColor: cf.sectionBackground,
              disabledForegroundColor: cf.textMuted,
              shape: RoundedRectangleBorder(borderRadius: radius),
              elevation: cf.isLight ? 0 : 1,
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
    }
  }
}
