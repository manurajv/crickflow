import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../../../../shared/widgets/stat_grid.dart';

class CaptainStatsSection extends StatelessWidget {
  const CaptainStatsSection({super.key, required this.stats});

  final CaptainStatsSnapshot stats;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    if (stats.matchesAsCaptain == 0) {
      return Card(
        child: Padding(
          padding: AppDimens.listPadding,
          child: Text(
            'No captaincy record yet. Lead a team as captain to unlock these stats.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Captain', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppDimens.spaceSm),
        StatGrid(
          cells: [
            StatCellData(
              value: '${stats.matchesAsCaptain}',
              label: 'Matches',
            ),
            StatCellData(value: '${stats.wins}', label: 'Wins'),
            StatCellData(value: '${stats.losses}', label: 'Losses'),
            StatCellData(
              value: '${stats.winPct.toStringAsFixed(1)}%',
              label: 'Win %',
            ),
            StatCellData(
              value: '${stats.tossesWon}/${stats.tossesTotal}',
              label: 'Toss Won',
            ),
            StatCellData(
              value: '${stats.tossPct.toStringAsFixed(1)}%',
              label: 'Toss %',
            ),
            StatCellData(
              value: stats.highestTeamScore > 0
                  ? '${stats.highestTeamScore}'
                  : '—',
              label: 'Highest Score',
            ),
            StatCellData(
              value: stats.lowestDefendedScore > 0
                  ? '${stats.lowestDefendedScore}'
                  : '—',
              label: 'Lowest Defended',
            ),
            StatCellData(
              value: '${stats.successfulChases}',
              label: 'Chases Won',
            ),
            StatCellData(
              value: stats.avgTeamScore.toStringAsFixed(1),
              label: 'Avg Team Score',
            ),
            StatCellData(
              value: stats.avgConcededScore.toStringAsFixed(1),
              label: 'Avg Conceded',
            ),
          ],
        ),
        if (stats.timeline.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceLg),
          Text(
            'Captaincy Timeline',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _TimelineChart(timeline: stats.timeline, cf: cf),
        ],
        if (stats.byYear.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceLg),
          Text(
            'Performance by Year',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ...stats.byYear.map(
            (y) => _BarRow(
              label: '${y.year}',
              value: y.winPct,
              subtitle: '${y.wins}W / ${y.losses}L (${y.matches} mat)',
              cf: cf,
            ),
          ),
        ],
        if (stats.byFormat.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceLg),
          Text(
            'Performance by Format',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ...stats.byFormat.map(
            (f) => _BarRow(
              label: f.label,
              value: f.winPct,
              subtitle: '${f.wins}W / ${f.losses}L',
              cf: cf,
            ),
          ),
        ],
      ],
    );
  }
}

class _TimelineChart extends StatelessWidget {
  const _TimelineChart({required this.timeline, required this.cf});

  final List<CaptainTimelinePoint> timeline;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final recent = timeline.length > 20
        ? timeline.sublist(timeline.length - 20)
        : timeline;

    return Container(
      height: 80,
      padding: const EdgeInsets.all(AppDimens.spaceSm),
      decoration: cfCardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: recent.map((p) {
          final color = switch (p.result) {
            'W' => cf.statusCompleted,
            'L' => cf.statusLive,
            _ => cf.textMuted,
          };
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Tooltip(
                message: '${p.matchTitle} — ${p.result}',
                child: Container(
                  height: p.result == 'W' ? 48 : 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.cf,
  });

  final String label;
  final double value;
  final String subtitle;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (value / 100).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: cf.sectionBackground,
                    color: cf.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
