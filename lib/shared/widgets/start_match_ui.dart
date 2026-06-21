import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';
import '../../core/utils/match_setup_navigation.dart';
import '../providers/start_match_draft_provider.dart';

export '../../core/utils/match_setup_navigation.dart' show StartMatchFlowStep;

/// Step chip row pinned below the app bar in start-match screens.
class StartMatchFlowProgress extends ConsumerWidget {
  const StartMatchFlowProgress({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(startMatchDraftProvider);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimens.spaceSm,
        bottom: AppDimens.spaceMd,
      ),
      child: StartMatchStepBar(
        steps: StartMatchFlowStep.labels,
        currentIndex: currentIndex,
        isStepTappable: (index) =>
            index != currentIndex && isStartMatchStepComplete(index, draft),
        onStepTap: (index) => navigateToStartMatchStep(context, index, draft),
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
    this.isStepTappable,
    this.onStepTap,
  });

  final List<String> steps;
  final int currentIndex;
  final bool Function(int index)? isStepTappable;
  final ValueChanged<int>? onStepTap;

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
              isComplete: isStartMatchStepCompleteFromBar(
                stepIndex: i,
                currentIndex: currentIndex,
                isStepTappable: isStepTappable,
              ),
              onTap: isStepTappable?.call(i) == true && onStepTap != null
                  ? () => onStepTap!(i)
                  : null,
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

bool isStartMatchStepCompleteFromBar({
  required int stepIndex,
  required int currentIndex,
  required bool Function(int index)? isStepTappable,
}) {
  if (stepIndex == currentIndex) return false;
  if (isStepTappable != null) return isStepTappable(stepIndex);
  return stepIndex < currentIndex;
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.index,
    required this.isActive,
    required this.isComplete,
    this.onTap,
  });

  final String label;
  final int index;
  final bool isActive;
  final bool isComplete;
  final VoidCallback? onTap;

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

    final chip = Container(
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

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: chip,
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
