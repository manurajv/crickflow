import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Shared bottom-sheet chrome for live scoring flows (CrickFlow theme).
class ScoringUiKit {
  ScoringUiKit._();

  static const sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  );

  static Future<T?> showSheet<T>(
    BuildContext context, {
    required Widget Function(BuildContext ctx) builder,
    bool isScrollControlled = false,
    bool useRootNavigator = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: sheetShape,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: builder,
    );
  }

  /// Draggable list sheet with shared CrickFlow chrome (live scoring + setup).
  static Future<T?> showDraggableSheet<T>(
    BuildContext context, {
    required Widget Function(BuildContext ctx, ScrollController scrollController)
        builder,
    double initialChildSize = 0.55,
    double minChildSize = 0.35,
    double maxChildSize = 0.92,
    bool useRootNavigator = true,
    bool isDismissible = true,
  }) {
    return showSheet<T>(
      context,
      isScrollControlled: true,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (_, controller) => builder(ctx, controller),
      ),
    );
  }

  static Widget sheetCloseButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.close, size: 22),
      color: AppColors.textSecondary,
      tooltip: 'Close',
      onPressed: () => Navigator.pop(context),
    );
  }

  static Future<bool?> confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Yes, I\'m sure',
    String cancelLabel = 'Cancel',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: sheetShape,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0B2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFF9800), width: 2),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Color(0xFFE65100),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drag handle + centered title with divider lines.
class ScoringSheetHeader extends StatelessWidget {
  const ScoringSheetHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Row(
            children: [
              const Expanded(child: _HeaderLine()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Flexible(child: _HeaderLine()),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
      ],
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.border,
    );
  }
}

/// Outlined grid cell for WD/NB/bye shortcuts.
class ScoringGridButton extends StatelessWidget {
  const ScoringGridButton({
    super.key,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: AppColors.gold,
          width: selected ? 2 : 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.black : AppColors.gold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected ? Colors.black54 : AppColors.textMuted,
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

/// Icon + label shortcut tile (quick options / wicket types).
class ScoringShortcutTile extends StatelessWidget {
  const ScoringShortcutTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: iconColor ?? AppColors.textPrimary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
