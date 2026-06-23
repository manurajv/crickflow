import 'package:flutter/material.dart';
import '../../../../../core/constants/enums.dart';
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

/// Match type row — same options as start-match flow.
class TournamentCricketMatchTypePicker extends StatelessWidget {
  const TournamentCricketMatchTypePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CricketMatchType selected;
  final ValueChanged<CricketMatchType> onSelected;

  static String _label(CricketMatchType type) => switch (type) {
        CricketMatchType.limitedOvers => 'Limited Overs',
        CricketMatchType.indoor => 'Indoor',
        CricketMatchType.testMatch => 'Test Match',
      };

  static IconData _icon(CricketMatchType type) => switch (type) {
        CricketMatchType.limitedOvers => Icons.sports_cricket,
        CricketMatchType.indoor => Icons.roofing_outlined,
        CricketMatchType.testMatch => Icons.calendar_view_day,
      };

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Row(
      children: CricketMatchType.values.map((type) {
        final isSelected = type == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? cf.accent : cf.sectionBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? cf.accent : cf.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _icon(type),
                      size: 22,
                      color: isSelected ? cf.onAccent : cf.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _label(type),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? cf.onAccent : cf.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
