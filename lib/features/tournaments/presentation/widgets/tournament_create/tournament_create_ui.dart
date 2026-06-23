import 'package:flutter/material.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';

/// Pill chip used across tournament create steps (matches start-match style).
class TournamentChoiceChip extends StatelessWidget {
  const TournamentChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? cf.accent.withValues(alpha: 0.25)
              : cf.sectionBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cf.accent : cf.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? cf.accent : cf.textSecondary,
          ),
        ),
      ),
    );
  }
}

class TournamentCreateSectionLabel extends StatelessWidget {
  const TournamentCreateSectionLabel({
    super.key,
    required this.label,
    this.required = false,
  });

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          children: [
            TextSpan(text: label),
            if (required)
              TextSpan(
                text: ' *',
                style: TextStyle(color: context.cf.error),
              ),
          ],
        ),
      ),
    );
  }
}

class TournamentCreateFooter extends StatelessWidget {
  const TournamentCreateFooter({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.onSkip,
    this.isLoading = false,
    this.showSkip = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSkip;
  final bool isLoading;
  final bool showSkip;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cf.card,
          border: Border(top: BorderSide(color: cf.border)),
        ),
        child: Row(
          children: [
            if (showSkip)
              Expanded(
                child: TextButton(
                  onPressed: isLoading ? null : onSkip,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: cf.textPrimary,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: const Text('Skip'),
                ),
              ),
            Expanded(
              flex: showSkip ? 2 : 1,
              child: Material(
                color: cf.accent,
                child: InkWell(
                  onTap: isLoading ? null : onPrimary,
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cf.onAccent,
                              ),
                            )
                          : Text(
                              primaryLabel,
                              style: TextStyle(
                                color: cf.onAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TournamentCreateNote extends StatelessWidget {
  const TournamentCreateNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spaceMd),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: context.cf.textMuted,
            ),
      ),
    );
  }
}
