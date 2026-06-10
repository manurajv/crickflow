import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_rules_model.dart';
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
    final bowlerOvers =
        '${(bowler?.oversBowledBalls ?? 0) ~/ rules.ballsPerOver}';

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Text(
                'Over $overNumber complete',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                    _PlayerRow(
                      name: striker?.playerName ?? '—',
                      stat: ScoringDisplayUtils.batsmanScoreLine(striker),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _PlayerRow(
                      name: nonStriker?.playerName ?? '—',
                      stat: ScoringDisplayUtils.batsmanScoreLine(nonStriker),
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
