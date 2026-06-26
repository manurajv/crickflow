import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/tournament/tournament_analytics_models.dart';
import '../../../../domain/services/tournament/tournament_hero_ranking_engine.dart';
import 'widgets/stats_dashboard_widgets.dart';

class TournamentPlayerStatsScreen extends StatelessWidget {
  const TournamentPlayerStatsScreen({
    super.key,
    required this.tournamentId,
    required this.detail,
  });

  final String tournamentId;
  final TournamentPlayerStatsDetail detail;

  bool _hasMetrics(List<StatsMetric> metrics) =>
      metrics.any((m) => m.value != '0' && m.value != '—' && m.value.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final showBatting = _hasMetrics(detail.battingMetrics);
    final showBowling = _hasMetrics(detail.bowlingMetrics);
    final showFielding = _hasMetrics(detail.fieldingMetrics);

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.playerName),
        actions: [
          IconButton(
            tooltip: 'Cricket profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/player/${detail.playerId}/cricket'),
          ),
        ],
      ),
      body: ListView(
        padding: AppDimens.screenPadding,
        children: [
          if (detail.teamName.isNotEmpty)
            Text(
              detail.teamName,
              style: TextStyle(color: cf.textSecondary),
            ),
          if (detail.teamName.isNotEmpty)
            const SizedBox(height: AppDimens.spaceMd),
          if (showBatting) ...[
            const _SectionTitle(title: 'Batting'),
            StatsMetricGrid(metrics: detail.battingMetrics),
            const SizedBox(height: AppDimens.spaceLg),
          ],
          if (showBowling) ...[
            const _SectionTitle(title: 'Bowling'),
            StatsMetricGrid(metrics: detail.bowlingMetrics),
            const SizedBox(height: AppDimens.spaceLg),
          ],
          if (showFielding) ...[
            const _SectionTitle(title: 'Fielding'),
            StatsMetricGrid(metrics: detail.fieldingMetrics),
            const SizedBox(height: AppDimens.spaceLg),
          ],
          if (detail.runsChart.isNotEmpty &&
              detail.runsChart.any((p) => p.value > 0)) ...[
            const _SectionTitle(title: 'Runs by match'),
            StatsMiniChart(
              series: StatsChartSeries(
                title: 'Innings runs',
                points: detail.runsChart,
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
          ],
          if (detail.wicketsChart.any((p) => p.value > 0)) ...[
            const _SectionTitle(title: 'Wickets by match'),
            StatsMiniChart(
              series: StatsChartSeries(
                title: 'Bowling wickets',
                points: detail.wicketsChart,
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
          ],
          if (detail.awards.isNotEmpty) ...[
            const _SectionTitle(title: 'Awards'),
            ...detail.awards.map(
              (a) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.emoji_events, color: cf.accent),
                title: Text(a.award.title),
                trailing: Text(
                  a.valueLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cf.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
          ],
          const _SectionTitle(title: 'Match-by-match'),
          if (detail.matchLogs.isEmpty)
            Text(
              'No scored appearances in this tournament yet.',
              style: TextStyle(color: cf.textMuted),
            )
          else
            ...detail.matchLogs.map(
              (log) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cf.border),
                ),
                child: ListTile(
                  title: Text(log.opponentLabel),
                  subtitle: Text(
                    '${log.runs}${log.balls > 0 ? ' (${log.balls}b)' : ''}'
                    '${log.wickets > 0 ? ' · ${log.wickets} wkts' : ''}'
                    '${log.isNotOut ? ' · not out' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/match/${log.matchId}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
