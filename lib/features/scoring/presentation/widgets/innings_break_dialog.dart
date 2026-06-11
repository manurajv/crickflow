import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/cricket_math.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/widgets/cf_slide_to_confirm.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import '../../../../domain/scoring/match_completion_policy.dart';
import '../utils/scoring_display_utils.dart';

/// Shown when an innings ends (overs or all out) or during an innings break.
class InningsBreakDialog extends StatelessWidget {
  const InningsBreakDialog({
    super.key,
    required this.match,
    required this.innings,
    required this.allowUndo,
    required this.onUndo,
    required this.onConfirm,
    this.confirmLabel,
  });

  final MatchModel match;
  final InningsModel innings;
  final bool allowUndo;
  final VoidCallback onUndo;
  final VoidCallback onConfirm;
  final String? confirmLabel;

  static Future<void> show(
    BuildContext context, {
    required MatchModel match,
    required InningsModel innings,
    required bool allowUndo,
    required VoidCallback onUndo,
    required VoidCallback onConfirm,
    String? confirmLabel,
  }) {
    return ScoringUiKit.showSheet<void>(
      context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(ctx).bottom,
        ),
        child: InningsBreakDialog(
          match: match,
          innings: innings,
          allowUndo: allowUndo,
          onUndo: onUndo,
          onConfirm: onConfirm,
          confirmLabel: confirmLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = match.rules;
    final reason = ScoringDisplayUtils.inningsCompleteReason(match, innings);
    final team = ScoringDisplayUtils.battingTeamName(match, innings);
    final overs = CricketMath.formatOvers(innings.legalBalls, rules.ballsPerOver);
    final tiedSuperOver = MatchCompletionPolicy.isTiedChaseComplete(match, innings);
    final hasNext = tiedSuperOver ||
        innings.inningsNumber < rules.maxInnings ||
        (innings.isSuperOver &&
            match.innings.where((i) => i.isSuperOver).length < 2);
    final target = hasNext && !tiedSuperOver
        ? (innings.targetRuns ?? innings.totalRuns + 1)
        : null;

    final slideLabel = confirmLabel ??
        (tiedSuperOver
            ? 'Slide to start super over'
            : hasNext
                ? 'Slide to start ${innings.inningsNumber + 1}${_ordinal(innings.inningsNumber + 1)} innings'
                : 'Slide to complete match');

    return PopScope(
      canPop: false,
      child: Material(
        color: AppColors.card,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScoringSheetHeader(
                title: allowUndo ? 'Innings complete' : 'Innings break',
              ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            ],
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              team,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${innings.totalRuns}/${innings.totalWickets} ($overs ov)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (target != null) ...[
              const SizedBox(height: 8),
              Text(
                'Target for next innings: $target',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppDimens.spaceLg),
            if (allowUndo) ...[
              OutlinedButton.icon(
                onPressed: onUndo,
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Undo last ball'),
              ),
              const SizedBox(height: AppDimens.spaceMd),
            ],
            CfSlideToConfirm(
              label: slideLabel,
              onConfirmed: onConfirm,
            ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
