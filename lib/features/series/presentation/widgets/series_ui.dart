import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';

class SeriesEmptyState extends StatelessWidget {
  const SeriesEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: cf.accent),
          const SizedBox(height: AppDimens.spaceMd),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cf.textSecondary),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppDimens.spaceLg),
            action!,
          ],
        ],
      ),
    );
  }
}

class SeriesStat extends StatelessWidget {
  const SeriesStat(this.value, this.label, {super.key});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: cf.surface,
          border: Border.all(color: cf.border),
          borderRadius: BorderRadius.circular(12),
          boxShadow: cf.isLight
              ? [BoxShadow(color: cf.cardShadow, blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: cf.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: TextStyle(color: cf.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Shared search field styling for Orgs screens.
InputDecoration orgSearchDecoration(BuildContext context, {String hint = 'Quick search'}) {
  final cf = context.cf;
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(Icons.search, color: cf.textMuted),
    filled: true,
    fillColor: cf.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cf.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cf.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cf.accent, width: 1.5),
    ),
  );
}

/// Filter chip colors aligned with light/dark theme.
FilterChip orgFilterChip(
  BuildContext context, {
  required String label,
  required bool selected,
  required ValueChanged<bool> onSelected,
}) {
  final cf = context.cf;
  return FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: onSelected,
    selectedColor: cf.accent.withValues(alpha: cf.isLight ? 0.12 : 0.25),
    checkmarkColor: cf.accent,
    side: BorderSide(color: selected ? cf.accent : cf.border),
    labelStyle: TextStyle(
      color: selected ? cf.accent : cf.textSecondary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
    ),
  );
}
