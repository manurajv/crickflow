import 'package:flutter/material.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';

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
    final cf = context.cf;
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: cf.card,
      shape: sheetShape,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: builder,
    );
  }

  static ButtonStyle primaryButtonStyle(BuildContext context) {
    final cf = context.cf;
    return FilledButton.styleFrom(
      backgroundColor: cf.accent,
      foregroundColor: cf.onAccent,
      minimumSize: const Size(0, 48),
      elevation: cf.isLight ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
    );
  }

  static ButtonStyle outlinedButtonStyle(BuildContext context) {
    final cf = context.cf;
    return OutlinedButton.styleFrom(
      foregroundColor: cf.textPrimary,
      backgroundColor: cf.card,
      side: BorderSide(color: cf.border),
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
    );
  }

  static Future<T?> showThemedDialog<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    final cf = context.cf;
    return showDialog<T>(
      context: context,
      builder: (ctx) => Theme(
        data: Theme.of(ctx).copyWith(
          dialogTheme: DialogThemeData(
            backgroundColor: cf.card,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        child: builder(ctx),
      ),
    );
  }

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
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DraggableScrollableSheet(
            initialChildSize: initialChildSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
            expand: false,
            builder: (_, controller) => builder(ctx, controller),
          ),
        );
      },
    );
  }

  static Widget sheetCloseButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.close, size: 22),
      color: context.cf.textSecondary,
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
    final cf = context.cf;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: cf.card,
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
                  color: cf.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: cf.error.withValues(alpha: 0.4), width: 2),
                ),
                child: Icon(Icons.error_outline, color: cf.error, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cf.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: cf.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: outlinedButtonStyle(context),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: primaryButtonStyle(context),
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

class ScoringSheetHeader extends StatelessWidget {
  const ScoringSheetHeader({
    super.key,
    required this.title,
    this.trailing,
    this.mutedTitle = false,
  });

  final String title;
  final Widget? trailing;
  final bool mutedTitle;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: cf.border,
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
                  style: TextStyle(
                    fontSize: mutedTitle ? 14 : 16,
                    fontWeight: mutedTitle ? FontWeight.w500 : FontWeight.w700,
                    color: mutedTitle ? cf.textMuted : cf.textPrimary,
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
    return Container(height: 1, color: context.cf.border);
  }
}

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
    final cf = context.cf;
    return Material(
      color: selected ? cf.accent.withValues(alpha: 0.12) : cf.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? cf.accent : cf.border,
          width: selected ? 2 : 1,
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
                  color: selected ? cf.accent : cf.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: cf.textMuted,
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
    final cf = context.cf;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: iconColor ?? cf.textPrimary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cf.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
