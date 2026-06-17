import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/cricket_math.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_rules_model.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import '../utils/scoring_display_utils.dart';
import 'over_timeline.dart';

class OverCompleteDialog extends StatelessWidget {
  const OverCompleteDialog({
    super.key,
    required this.overNumber,
    required this.bowlerName,
    required this.overEvents,
    required this.innings,
    required this.rules,
    required this.onStartNextOver,
  });

  final int overNumber;
  final String bowlerName;
  final List<BallEventModel> overEvents;
  final InningsModel innings;
  final MatchRulesModel rules;
  final VoidCallback onStartNextOver;

  static Future<void> show(
    BuildContext context, {
    required int overNumber,
    required String bowlerName,
    required List<BallEventModel> overEvents,
    required InningsModel innings,
    required MatchRulesModel rules,
    required VoidCallback onStartNextOver,
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
        child: OverCompleteDialog(
          overNumber: overNumber,
          bowlerName: bowlerName,
          overEvents: overEvents,
          innings: innings,
          rules: rules,
          onStartNextOver: onStartNextOver,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runs = ScoringDisplayUtils.overRuns(overEvents);
    final wickets = ScoringDisplayUtils.overWickets(overEvents);
    final extras = ScoringDisplayUtils.overExtras(overEvents);
    final striker = ScoringDisplayUtils.batsman(innings, innings.strikerId);
    final nonStriker =
        ScoringDisplayUtils.batsman(innings, innings.nonStrikerId);
    final finishedBowlerId =
        overEvents.isNotEmpty ? overEvents.last.bowlerId : innings.currentBowlerId;
    final bowler = ScoringDisplayUtils.bowler(innings, finishedBowlerId);
    final bowlerOvers = CricketMath.formatOvers(
      bowler?.oversBowledBalls ?? 0,
      rules.ballsPerOver,
    );

    return Material(
      color: AppColors.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScoringSheetHeader(title: 'Over $overNumber complete'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'Runs',
                    value: '$runs',
                    highlight: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(label: 'Wkts', value: '$wickets'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(label: 'Overs', value: bowlerOvers),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(label: 'Extras', value: '$extras'),
                ),
              ],
            ),
          ),
          if (overEvents.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OverTimeline(
                events: overEvents,
                title: 'End of over by $bowlerName',
                showExtrasLabel: false,
              ),
            ),
          ],
          const SizedBox(height: AppDimens.spaceMd),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Text(
                            'Batter',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        Text(
                          'This over',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PlayerRow(
                    name: striker?.playerName ?? '—',
                    stat: ScoringDisplayUtils.batsmanOverScoreLine(
                      innings.strikerId,
                      overEvents,
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _PlayerRow(
                    name: nonStriker?.playerName ?? '—',
                    stat: ScoringDisplayUtils.batsmanOverScoreLine(
                      innings.nonStrikerId,
                      overEvents,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onStartNextOver();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Select bowler for next over',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? AppColors.gold.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.gold : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.name,
    required this.stat,
  });

  final String name;
  final String stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            stat,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
