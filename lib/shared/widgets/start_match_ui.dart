import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';

/// Step indices for the create-match wizard.
abstract final class StartMatchFlowStep {
  static const labels = [
    'Teams',
    'Setup',
    'Squads',
    'Roles',
    'Officials',
    'Toss',
  ];

  static const teams = 0;
  static const setup = 1;
  static const squads = 2;
  static const roles = 3;
  static const officials = 4;
  static const toss = 5;
}

/// Step chip row pinned below the app bar in start-match screens.
class StartMatchFlowProgress extends StatelessWidget {
  const StartMatchFlowProgress({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimens.spaceSm,
        bottom: AppDimens.spaceMd,
      ),
      child: StartMatchStepBar(
        steps: StartMatchFlowStep.labels,
        currentIndex: currentIndex,
      ),
    );
  }
}

/// White setup card used across the start-match wizard.
class StartMatchCard extends StatelessWidget {
  const StartMatchCard({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cf.border),
        boxShadow: [
          BoxShadow(
            color: cf.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(AppDimens.spaceMd),
      child: child,
    );
  }
}

/// Horizontal step chips for the start-match flow.
class StartMatchStepBar extends StatelessWidget {
  const StartMatchStepBar({
    super.key,
    required this.steps,
    required this.currentIndex,
  });

  final List<String> steps;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _StepChip(
              label: steps[i],
              index: i + 1,
              isActive: i == currentIndex,
              isComplete: i < currentIndex,
            ),
            if (i < steps.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: cf.textMuted,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.index,
    required this.isActive,
    required this.isComplete,
  });

  final String label;
  final int index;
  final bool isActive;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final bg = isActive
        ? cf.accent
        : isComplete
            ? cf.accent.withValues(alpha: 0.12)
            : cf.sectionBackground;
    final fg = isActive
        ? cf.onAccent
        : isComplete
            ? cf.accent
            : cf.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive || isComplete
              ? cf.accent.withValues(alpha: isActive ? 1 : 0.4)
              : cf.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$index',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Info callout strip (e.g. “Scoring is free”).
class StartMatchInfoBanner extends StatelessWidget {
  const StartMatchInfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: cf.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: cf.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cf.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title for squad / officials lists.
class StartMatchSectionHeader extends StatelessWidget {
  const StartMatchSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: cf.textPrimary,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textMuted,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
