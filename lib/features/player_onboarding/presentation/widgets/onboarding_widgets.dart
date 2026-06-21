import 'package:flutter/material.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';

/// Material 3 card wrapper for onboarding step content.
class OnboardingStepCard extends StatelessWidget {
  const OnboardingStepCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return ListView(
      padding: AppDimens.listPadding,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cf.textPrimary,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
        ],
        const SizedBox(height: AppDimens.spaceLg),
        Card(
          elevation: 0,
          color: cf.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cf.border.withValues(alpha: 0.8)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Animated step progress bar for onboarding.
class OnboardingProgressHeader extends StatelessWidget {
  const OnboardingProgressHeader({
    super.key,
    required this.step,
    required this.stepCount,
    required this.progress,
  });

  final int step;
  final int stepCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                backgroundColor: cf.border,
                color: cf.accent,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${step + 1} of $stepCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cf.textSecondary,
                    ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cf.accent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Styled choice chip for onboarding selections.
class OnboardingChoiceChip extends StatelessWidget {
  const OnboardingChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: true,
      selectedColor: cf.accent.withValues(alpha: 0.18),
      checkmarkColor: cf.accent,
      side: BorderSide(
        color: selected ? cf.accent : cf.border,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

/// Styled radio tile inside onboarding cards.
class OnboardingRadioTile<T> extends StatelessWidget {
  const OnboardingRadioTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.title,
    required this.onChanged,
  });

  final T value;
  final T? groupValue;
  final String title;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return RadioListTile<T>(
      value: value,
      groupValue: groupValue,
      title: Text(title),
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: cf.accent,
      onChanged: onChanged,
    );
  }
}
