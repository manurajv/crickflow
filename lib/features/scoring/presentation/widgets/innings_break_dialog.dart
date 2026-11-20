import 'package:flutter/material.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/widgets/cf_slide_to_confirm.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import '../../../../domain/scoring/match_completion_policy.dart';
import '../utils/scoring_display_utils.dart';
import '../../../../core/theme/cf_colors.dart';

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
    this.onCancel,
  });

  final MatchModel match;
  final InningsModel innings;
  final bool allowUndo;
  final VoidCallback onUndo;
  final Future<void> Function() onConfirm;
  final String? confirmLabel;

  /// When set, a Cancel button is shown and back / tap-outside / swipe-down
  /// dismiss the sheet without changing match state.
  final VoidCallback? onCancel;

  static const cancelKey = Key('innings_break_cancel');

  /// Returns true when the sheet closed without confirming (cancelled).
  static Future<bool> show(
    BuildContext context, {
    required MatchModel match,
    required InningsModel innings,
    required bool allowUndo,
    required VoidCallback onUndo,
    required Future<void> Function() onConfirm,
    String? confirmLabel,
    bool cancellable = true,
  }) async {
    final result = await ScoringUiKit.showSheet<bool>(
      context,
      isScrollControlled: true,
      isDismissible: cancellable,
      enableDrag: cancellable,
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
          onCancel: cancellable ? () => Navigator.of(ctx).pop(true) : null,
        ),
      ),
    );
    // null = dismissed by back / tap outside / swipe; true = Cancel button.
    return cancellable && result != false;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final rules = match.rules;
    final reason = ScoringDisplayUtils.inningsCompleteReason(match, innings);
    final team = ScoringDisplayUtils.battingTeamName(match, innings);
    final overs = ScoringDisplayUtils.inningsOversDisplay(innings, rules);
    final tiedSuperOver = MatchCompletionPolicy.isTiedChaseComplete(match, innings);
    final hasNext =
        MatchCompletionPolicy.shouldContinueAfterInnings(match, innings);
    final target = hasNext && !tiedSuperOver
        ? (innings.targetRuns ??
            match.targetState.pendingChaseTarget ??
            innings.totalRuns + 1)
        : null;
    final dlsApplied = match.targetState.dlsApplied;

    final slideLabel = confirmLabel ??
        (tiedSuperOver
            ? 'Slide to start super over'
            : hasNext
                ? 'Slide to start ${innings.inningsNumber + 1}${_ordinal(innings.inningsNumber + 1)} innings'
                : 'Slide to complete match');

    return PopScope(
      canPop: onCancel != null,
      child: Material(
        color: cf.card,
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cf.accent,
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
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: cf.textPrimary,
              ),
            ),
            if (target != null) ...[
              const SizedBox(height: 8),
              if (dlsApplied)
                Text(
                  'DLS Applied',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cf.accent,
                  ),
                ),
              Text(
                'Target for next innings: $target',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: cf.textSecondary,
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
            if (onCancel != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              TextButton.icon(
                key: cancelKey,
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancel'),
              ),
            ],
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
