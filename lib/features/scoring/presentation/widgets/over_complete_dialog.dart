import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_rules_model.dart';
import '../utils/scoring_display_utils.dart';

class OverCompleteDialog extends StatelessWidget {
  const OverCompleteDialog({
    super.key,
    required this.overNumber,
    required this.bowlerName,
    required this.overEvents,
    required this.innings,
    required this.rules,
    required this.onStartNextOver,
    required this.onContinueOver,
  });

  final int overNumber;
  final String bowlerName;
  final List<BallEventModel> overEvents;
  final InningsModel innings;
  final MatchRulesModel rules;
  final VoidCallback onStartNextOver;
  final VoidCallback onContinueOver;

  @override
  Widget build(BuildContext context) {
    final runs = ScoringDisplayUtils.overRuns(overEvents);
    final wickets = ScoringDisplayUtils.overWickets(overEvents);
    final extras = ScoringDisplayUtils.overExtras(overEvents);
    final striker = ScoringDisplayUtils.batsman(innings, innings.strikerId);
    final nonStriker =
        ScoringDisplayUtils.batsman(innings, innings.nonStrikerId);
    final bowler = ScoringDisplayUtils.bowler(innings, innings.currentBowlerId);

    return AlertDialog(
      backgroundColor: AppColors.card,
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Over complete',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'End of over $overNumber by $bowlerName',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Table(
              border: TableBorder.all(color: AppColors.border),
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: AppColors.surfaceElevated),
                  children: [
                    _Th('Runs'),
                    _Th('Wkts'),
                    _Th('Extras'),
                    _Th('Score'),
                  ],
                ),
                TableRow(
                  children: [
                    _Td('$runs'),
                    _Td('$wickets'),
                    _Td('$extras'),
                    _Td('${innings.totalRuns}/${innings.totalWickets}'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _PlayerRow(
              icon: Icons.sports_cricket,
              iconColor: AppColors.gold,
              name: striker?.playerName ?? '—',
              stat: ScoringDisplayUtils.batsmanScoreLine(striker),
            ),
            _PlayerRow(
              icon: Icons.sports_cricket,
              iconColor: AppColors.textMuted,
              name: nonStriker?.playerName ?? '—',
              stat: ScoringDisplayUtils.batsmanScoreLine(nonStriker),
            ),
            _PlayerRow(
              icon: Icons.circle,
              iconColor: AppColors.accentRed,
              name: bowler?.playerName ?? bowlerName,
              stat: ScoringDisplayUtils.bowlerFigures(bowler, rules.ballsPerOver),
            ),
          ],
        ),
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onStartNextOver();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Start next over'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onContinueOver();
              },
              child: const Text('Continue this over'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );
}

class _Td extends StatelessWidget {
  const _Td(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.stat,
  });

  final IconData icon;
  final Color iconColor;
  final String name;
  final String stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
          Text(stat, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
